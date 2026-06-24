# Repository Guidelines

## Project Structure & Module Organization

This repository implements an Urbit Model Context Protocol server. Production Hoon source lives under `desk/`: the Gall agent is `desk/app/mcp-server.hoon`, shared libraries are in `desk/lib/`, structures in `desk/sur/`, marks in `desk/mar/`, and install threads in `desk/ted/`. MCP tools, prompts, resources, and templates are organized under `desk/fil/mcp/`. CI workflows live in `.github/workflows/`. Treat generated `dist/` and `.zig-cache/` contents as build artifacts; edit `desk/` or `build.zig` instead.

## Build, Test, and Development Commands

- `zig build` assembles `desk/` plus pinned upstream dependencies into `dist/`. Zig 0.15 or newer is required; CI currently uses 0.15.2.
- `zig build -Ddesk=~/path/to/ship/mcp` rebuilds and replaces a mounted ship desk for local integration testing.
- `zig build clean` removes `dist/`.
- `zig build clear` also removes cached desk dependencies.
- `zig test build.zig` runs the Zig build-helper unit tests.

After deploying to a running ship, commit the target desk (`|commit %mcp`) to compile changes. If this is a new ship, also install the desk (`|install our %mcp`).

## Coding Style & Naming Conventions

Follow nearby Hoon formatting: two-space indentation, aligned rune bodies, lowercase kebab-case filenames (for example, `import-mcp-tools.hoon`), and short comments explaining intent rather than syntax. Keep MCP feature implementations in their matching `tools/`, `prompts/`, `resources/`, or `templates/` directory.

Gall agents such as `/app/mcp-server.hoon` MUST have ten arms (e.g. `+on-poke`) or they will fail to compile; put additional arms in a helper core called by those ten arms. Do not mix wide-form and tall-form Hoon.

For Zig, use standard `zig fmt` formatting and lower camel case for functions and variables. Run `zig fmt --check build.zig` before submitting build-system changes.

## Testing Guidelines

Running `zig build` tells you nothing about whether the code will compile on an Urbit ship. You must copy the changes to an Urbit ship and commit the desk on there to check.
