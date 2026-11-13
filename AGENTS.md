# Repository Guidelines

## Project Structure & Module Organization

This repository implements an Urbit Model Context Protocol server. Production Hoon source lives under `desk/`: the Gall agent is `desk/app/mcp-server.hoon`, shared libraries are in `desk/lib/`, structures in `desk/sur/`, marks in `desk/mar/`, and install threads in `desk/ted/`. MCP tools, prompts, resources, and templates are organized under `desk/fil/mcp/`. CI workflows live in `.github/workflows/`. Treat generated `desk-out/`, `desk-deps/` and `.deps-cache/` contents as build artifacts; edit `desk/` or `desk-deps.yaml` instead.

## Build, Test, and Development Commands

- `just build` assembles `desk-deps/` (pinned upstream files listed in `desk-deps.yaml`) plus `desk/` into `desk-out/`. It needs `just`, `git`, `rsync`, `python3` and mikefarah's `yq`. Parallel builds in one checkout are safe: they take turns under a lock in `.deps-cache/`.
- `just install ~/path/to/ship/mcp` rebuilds and replaces a mounted ship desk for local integration testing. Everything else in the mount is deleted.
- `just install-dev ~/path/to/ship/mcp` does the same without deleting: files already in the mount are kept.
- `just commit ~/path/to/ship/mcp` runs `install-dev`, then asks the running ship to commit that desk.
- `just clean` removes `desk-out/`.
- `just distclean` also removes fetched dependencies and the fetch cache.

Agents: during development, deploy with `just install-dev` or `just commit`. Do not run `just install` unless the user explicitly asks for it: it deletes every file in the mounted desk that is not part of the build.

After deploying to a running ship, commit the target desk (`|commit %mcp`) to compile changes. If this is a new ship, also install the desk (`|install our %mcp`).

## Coding Style & Naming Conventions

Follow nearby Hoon formatting: two-space indentation, aligned rune bodies, lowercase kebab-case filenames (for example, `import-mcp-tools.hoon`), and short comments explaining intent rather than syntax. Keep MCP feature implementations in their matching `tools/`, `prompts/`, `resources/`, or `templates/` directory.

Gall agents such as `/app/mcp-server.hoon` MUST have ten arms (e.g. `+on-poke`) or they will fail to compile; put additional arms in a helper core called by those ten arms. Do not mix wide-form and tall-form Hoon.

## Testing Guidelines

Running `just build` tells you nothing about whether the code will compile on an Urbit ship. You must copy the changes to an Urbit ship and commit the desk on there to check.
