const std = @import("std");

const Action = enum {
    build, // zig build       -> build /dist
    clean, // zig build clean -> remove /dist
    clear, // zig build clear -> remove /dist and cached imports
};

const RepoImport = struct {
    name: []const u8,          // any name
    url: []const u8,           // git repo url
    commit: []const u8,        // commit hash
    prefix: []const u8,        // repository prefix, omitted from /dist
    paths: []const []const u8, // relative or prefix-qualified filepaths
};

const dependencies = [_]RepoImport{
    .{
        .name = "pretty-file",
        .url = "https://github.com/urbit/urbit",
        .commit = "0f94550b941dfe046d9dff4a541330bd084e8cd1",
        .prefix = "pkg/arvo",
        .paths = &.{
            "lib/pretty-file.hoon",
        },
    },
    .{
        .name = "test-agent",
        .url = "https://github.com/tloncorp/tlon-apps",
        .commit = "9f0c94771e4773567a2f55a727ffa31b0f6e8e9f",
        .prefix = "desk",
        .paths = &.{
            "lib/test-agent.hoon",
        },
    },
    .{
        .name = "base-dev",
        .url = "https://github.com/urbit/urbit",
        .commit = "0f94550b941dfe046d9dff4a541330bd084e8cd1",
        .prefix = "pkg/base-dev",
        .paths = &.{
            "lib/dbug.hoon",
            "lib/default-agent.hoon",
            "lib/server.hoon",
            "lib/skeleton.hoon",
            "lib/strand.hoon",
            "lib/strandio.hoon",
            "lib/test.hoon",
            "lib/verb.hoon",
            "mar/bill.hoon",
            "mar/hoon.hoon",
            "mar/json.hoon",
            "mar/kelvin.hoon",
            "mar/mime.hoon",
            "mar/noun.hoon",
            "mar/ship.hoon",
            "mar/sole/action.hoon",
            "mar/sole/effect.hoon",
            "mar/txt.hoon",
            "sur/sole.hoon",
            "sur/spider.hoon",
            "sur/verb.hoon",
        },
    },
};

const dependency_cache_dir = ".zig-cache/desk-deps";
const minimum_git_version = GitVersion{ .major = 2, .minor = 25, .patch = 0 };

const GitVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,

    fn order(a: GitVersion, b: GitVersion) std.math.Order {
        if (a.major != b.major) return std.math.order(a.major, b.major);
        if (a.minor != b.minor) return std.math.order(a.minor, b.minor);
        return std.math.order(a.patch, b.patch);
    }
};

const DeskStep = struct {
    step: std.Build.Step,
    action: Action,
    copy_target: ?[]const u8,

    fn create(b: *std.Build, name: []const u8, action: Action, copy_target: ?[]const u8) *DeskStep {
        const self = b.allocator.create(DeskStep) catch @panic("OOM");
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = name,
                .owner = b,
                .makeFn = make,
            }),
            .action = action,
            .copy_target = copy_target,
        };
        return self;
    }

    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
        _ = options;
        const self: *DeskStep = @fieldParentPtr("step", step);
        const allocator = step.owner.allocator;

        switch (self.action) {
            .build => try buildDesk(step, allocator, self.copy_target),
            .clean => try clean(),
            .clear => try clear(),
        }
    }
};

pub fn build(b: *std.Build) void {
    const desk = b.option([]const u8, "desk", "After building, replace the desk at this path with /dist contents");

    const build_step = DeskStep.create(b, "build desk", .build, desk);
    b.default_step.dependOn(&build_step.step);

    const named_build = b.step("build", "Build /dist from /desk and dependencies");
    named_build.dependOn(&build_step.step);

    const clean_step = DeskStep.create(b, "clean", .clean, null);
    const named_clean = b.step("clean", "Remove /dist");
    named_clean.dependOn(&clean_step.step);

    const clear_step = DeskStep.create(b, "clear", .clear, null);
    const named_clear = b.step("clear", "Remove /dist and cached dependencies");
    named_clear.dependOn(&clear_step.step);
}

fn buildDesk(step: *std.Build.Step, allocator: std.mem.Allocator, copy_target: ?[]const u8) !void {
    try requireGitVersion(step);

    if (!pathExists("desk") and !pathExists("desk-dev")) {
        return step.fail("neither /desk nor /desk-dev directory found", .{});
    }

    std.debug.print("Creating /dist directory...\n", .{});
    try recreateDir("dist");

    if (pathExists("desk")) {
        std.debug.print("Copying /desk to /dist...\n", .{});
        try copyDirContents(allocator, "desk", "dist");
    }

    for (dependencies) |dep| {
        try importDependency(step, allocator, dep, "dist");
    }

    std.debug.print("Built!\n", .{});

    if (copy_target) |target| {
        const target_path = try expandHomePath(allocator, step, target);
        try copyDistToTarget(allocator, step, target_path);
    }
}

fn clean() !void {
    try deleteTreeIfExists("dist");
}

fn clear() !void {
    try clean();
    try deleteTreeIfExists(dependency_cache_dir);
}

fn importDependency(
    step: *std.Build.Step,
    allocator: std.mem.Allocator,
    dep: RepoImport,
    dist_path: []const u8,
) !void {
    const repo_path = try std.fs.path.join(allocator, &.{ dependency_cache_dir, dep.name });

    try ensureRepoImport(step, repo_path, dep);

    for (dep.paths) |path| {
        const import_path = try prefixedPath(allocator, dep.prefix, path);
        const rel = strippedPath(dep.prefix, path);
        const source_path = try std.fs.path.join(allocator, &.{ repo_path, import_path });
        const dest_path = try std.fs.path.join(allocator, &.{ dist_path, rel });
        try copyFilePath(source_path, dest_path);
    }
}

fn ensureRepoImport(step: *std.Build.Step, repo_path: []const u8, dep: RepoImport) !void {
    const git_dir = try std.fs.path.join(step.owner.allocator, &.{ repo_path, ".git" });
    if (!pathExists(git_dir)) {
        if (std.fs.path.dirname(repo_path)) |parent| {
            try std.fs.cwd().makePath(parent);
        }
        try std.fs.cwd().makePath(repo_path);
        std.debug.print("Importing {s}...\n", .{dep.name});
        try run(step, &.{ "git", "-C", repo_path, "init" });
        try run(step, &.{ "git", "-C", repo_path, "remote", "add", "origin", dep.url });
        try run(step, &.{ "git", "-C", repo_path, "sparse-checkout", "init", "--no-cone" });
    }

    try setSparseCheckout(step, dep, repo_path);

    if (!gitHasCommit(step, repo_path, dep.commit)) {
        try run(step, &.{ "git", "-C", repo_path, "fetch", "--depth", "1", "--filter=blob:none", "origin", dep.commit });
    }

    try run(step, &.{ "git", "-C", repo_path, "checkout", "--detach", "--force", dep.commit });
}

fn requireGitVersion(step: *std.Build.Step) !void {
    const result = std.process.Child.run(.{
        .allocator = step.owner.allocator,
        .argv = &.{ "git", "--version" },
        .max_output_bytes = 16 * 1024,
    }) catch |err| {
        return step.fail("failed to run git --version: {s}", .{@errorName(err)});
    };

    switch (result.term) {
        .Exited => |code| {
            if (code != 0) {
                if (result.stderr.len > 0) {
                    std.debug.print("{s}", .{result.stderr});
                }
                return step.fail("git --version exited with code {d}", .{code});
            }
        },
        else => return step.fail("git --version failed", .{}),
    }

    const version = parseGitVersion(result.stdout) orelse {
        return step.fail("could not parse git version from: {s}", .{std.mem.trim(u8, result.stdout, " \t\r\n")});
    };

    if (version.order(minimum_git_version) == .lt) {
        return step.fail(
            "git {d}.{d}.{d} or newer is required; found {s}",
            .{
                minimum_git_version.major,
                minimum_git_version.minor,
                minimum_git_version.patch,
                std.mem.trim(u8, result.stdout, " \t\r\n"),
            },
        );
    }
}

fn parseGitVersion(output: []const u8) ?GitVersion {
    const prefix = "git version ";
    const trimmed = std.mem.trim(u8, output, " \t\r\n");
    if (!std.mem.startsWith(u8, trimmed, prefix)) return null;

    const rest = trimmed[prefix.len..];
    const version_text = rest[0 .. std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len];

    var parts = std.mem.splitScalar(u8, version_text, '.');
    const major_text = parts.next() orelse return null;
    const minor_text = parts.next() orelse return null;
    const patch_text = parts.next() orelse return null;

    const patch_end = for (patch_text, 0..) |char, i| {
        if (!std.ascii.isDigit(char)) break i;
    } else patch_text.len;
    if (patch_end == 0) return null;

    return .{
        .major = std.fmt.parseInt(u32, major_text, 10) catch return null,
        .minor = std.fmt.parseInt(u32, minor_text, 10) catch return null,
        .patch = std.fmt.parseInt(u32, patch_text[0..patch_end], 10) catch return null,
    };
}

fn setSparseCheckout(step: *std.Build.Step, dep: RepoImport, repo_path: []const u8) !void {
    var argv = std.ArrayList([]const u8){};
    try argv.append(step.owner.allocator, "git");
    try argv.append(step.owner.allocator, "-C");
    try argv.append(step.owner.allocator, repo_path);
    try argv.append(step.owner.allocator, "sparse-checkout");
    try argv.append(step.owner.allocator, "set");
    try argv.append(step.owner.allocator, "--no-cone");
    for (dep.paths) |path| {
        try argv.append(step.owner.allocator, try prefixedPath(step.owner.allocator, dep.prefix, path));
    }
    try run(step, argv.items);
}

fn gitHasCommit(step: *std.Build.Step, repo_path: []const u8, commit: []const u8) bool {
    const commit_ref = std.fmt.allocPrint(step.owner.allocator, "{s}^{{commit}}", .{commit}) catch return false;
    return runAllowFail(step, &.{ "git", "-C", repo_path, "cat-file", "-e", commit_ref });
}

fn run(step: *std.Build.Step, argv: []const []const u8) !void {
    const result = std.process.Child.run(.{
        .allocator = step.owner.allocator,
        .argv = argv,
        .max_output_bytes = 256 * 1024,
    }) catch |err| {
        return step.fail("failed to run {s}: {s}", .{ argv[0], @errorName(err) });
    };

    switch (result.term) {
        .Exited => |code| {
            if (code == 0) return;
            if (result.stderr.len > 0) {
                std.debug.print("{s}", .{result.stderr});
            }
            return step.fail("command exited with code {d}: {s}", .{ code, argv[0] });
        },
        else => {
            if (result.stderr.len > 0) {
                std.debug.print("{s}", .{result.stderr});
            }
            return step.fail("command failed: {s}", .{argv[0]});
        },
    }
}

fn runAllowFail(step: *std.Build.Step, argv: []const []const u8) bool {
    const result = std.process.Child.run(.{
        .allocator = step.owner.allocator,
        .argv = argv,
        .max_output_bytes = 256 * 1024,
    }) catch return false;

    return switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

fn prefixedPath(allocator: std.mem.Allocator, prefix: []const u8, path: []const u8) ![]const u8 {
    if (prefix.len == 0 or hasPathPrefix(prefix, path)) return path;
    return std.fs.path.join(allocator, &.{ prefix, path });
}

fn strippedPath(prefix: []const u8, path: []const u8) []const u8 {
    if (!hasPathPrefix(prefix, path)) return path;
    if (path.len == prefix.len) return path[path.len..];
    return path[prefix.len + 1 ..];
}

fn hasPathPrefix(prefix: []const u8, path: []const u8) bool {
    if (prefix.len == 0 or !std.mem.startsWith(u8, path, prefix)) return false;
    return path.len == prefix.len or path[prefix.len] == '/';
}

test "dependency paths may include or omit their prefix" {
    const added = try prefixedPath(std.testing.allocator, "desk", "mar/example.hoon");
    defer std.testing.allocator.free(added);

    try std.testing.expectEqualStrings("desk/mar/example.hoon", added);
    try std.testing.expectEqualStrings("desk/mar/example.hoon", try prefixedPath(std.testing.allocator, "desk", "desk/mar/example.hoon"));
    try std.testing.expectEqualStrings("mar/example.hoon", strippedPath("desk", "desk/mar/example.hoon"));
    try std.testing.expectEqualStrings("mar/example.hoon", strippedPath("desk", "mar/example.hoon"));
    try std.testing.expectEqualStrings("desk-tools/example.hoon", strippedPath("desk", "desk-tools/example.hoon"));
}

test "git version output is parsed" {
    try std.testing.expectEqual(GitVersion{ .major = 2, .minor = 50, .patch = 1 }, parseGitVersion("git version 2.50.1 (Apple Git-155)\n").?);
    try std.testing.expectEqual(GitVersion{ .major = 2, .minor = 25, .patch = 0 }, parseGitVersion("git version 2.25.0\n").?);
    try std.testing.expectEqual(GitVersion{ .major = 2, .minor = 39, .patch = 5 }, parseGitVersion("git version 2.39.5.windows.1\n").?);
    try std.testing.expect(parseGitVersion("not git 2.50.1") == null);
}

test "git version ordering" {
    try std.testing.expect((GitVersion{ .major = 2, .minor = 24, .patch = 9 }).order(minimum_git_version) == .lt);
    try std.testing.expect((GitVersion{ .major = 2, .minor = 25, .patch = 0 }).order(minimum_git_version) == .eq);
    try std.testing.expect((GitVersion{ .major = 2, .minor = 50, .patch = 1 }).order(minimum_git_version) == .gt);
}

fn expandHomePath(allocator: std.mem.Allocator, step: *std.Build.Step, path: []const u8) ![]const u8 {
    if (std.mem.eql(u8, path, "~")) {
        return std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
            return step.fail("could not expand '~': HOME is unavailable: {s}", .{@errorName(err)});
        };
    }

    if (std.mem.startsWith(u8, path, "~/")) {
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
            return step.fail("could not expand '~': HOME is unavailable: {s}", .{@errorName(err)});
        };
        return std.fs.path.join(allocator, &.{ home, path[2..] });
    }

    return path;
}

fn copyDistToTarget(allocator: std.mem.Allocator, step: *std.Build.Step, target_path: []const u8) !void {
    if (!pathExists("dist")) {
        return step.fail("dist directory not found. Run build first", .{});
    }
    if (!pathExists(target_path)) {
        return step.fail("target path '{s}' does not exist", .{target_path});
    }

    std.debug.print("Clearing destination desk...\n", .{});
    try clearDirContents(allocator, target_path);

    std.debug.print("Copying /dist to destination desk...\n", .{});
    try copyDirContents(allocator, "dist", target_path);

    std.debug.print("Copied!\n", .{});
}

fn copyDirContents(allocator: std.mem.Allocator, source_path: []const u8, dest_path: []const u8) !void {
    var source_dir = try std.fs.cwd().openDir(source_path, .{ .iterate = true });
    defer source_dir.close();

    try std.fs.cwd().makePath(dest_path);
    var it = source_dir.iterate();
    while (try it.next()) |entry| {
        const src = try std.fs.path.join(allocator, &.{ source_path, entry.name });
        const dst = try std.fs.path.join(allocator, &.{ dest_path, entry.name });

        switch (entry.kind) {
            .directory => try copyDirContents(allocator, src, dst),
            .file => try copyFilePath(src, dst),
            else => {},
        }
    }
}

fn copyFilePath(source_path: []const u8, dest_path: []const u8) !void {
    if (std.fs.path.dirname(dest_path)) |parent| {
        try std.fs.cwd().makePath(parent);
    }
    try std.fs.cwd().copyFile(source_path, std.fs.cwd(), dest_path, .{});
}

fn clearDirContents(allocator: std.mem.Allocator, dir_path: []const u8) !void {
    {
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .file or entry.kind == .sym_link) {
                const child_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
                try std.fs.cwd().deleteFile(child_path);
            }
        }
    }

    {
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .directory) {
                const child_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
                try clearDirContents(allocator, child_path);
                try std.fs.cwd().deleteDir(child_path);
            }
        }
    }
}

fn recreateDir(path: []const u8) !void {
    try deleteTreeIfExists(path);
    try std.fs.cwd().makePath(path);
}

fn deleteTreeIfExists(path: []const u8) !void {
    if (pathExists(path)) {
        try std.fs.cwd().deleteTree(path);
    }
}

fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}
