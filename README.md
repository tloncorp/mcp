# Urbit MCP

A general-purpose Model Context Protocol interface for Urbit.

The `%mcp` desk ships as a single integrated control plane with three pieces:

1. **Native MCP server** at `/mcp` — runs Hoon-defined tools, prompts and
   resources directly on your ship.
2. **MCP proxy** at `/apps/mcp/mcp` — aggregates the native server plus any
   number of remote MCP / OpenAPI / Google Discovery upstreams behind a single
   endpoint, with per-server tool filtering and OAuth 2.0 + PKCE token
   management. OpenAPI and Discovery spec docs are dynamically converted
   to MCP tool calls.
3. **Operator console** at `/apps/mcp/` — a web UI for configuring upstreams,
   OAuth providers, the API key, and inspecting tools.

Both `/mcp` and `/apps/mcp/mcp` authenticate with the same `X-Api-Key` header.
A random key is generated on first install and can be regenerated, set, or
cleared from the operator console.

## Quickstart

The fastest way to get a running Urbit with MCP configured is to [install Groundwire](https://groundwire.io/). The onboarding script will automatically configure your ship for Codex, Claude Code, and Opencode.

```bash
curl -fsSL https://groundwire.io/install.sh | bash
```

If you don't need your LLM to have a self-custodied decentralized ID, you can skip the attestation flow.

```bash
curl -fsSL https://groundwire.io/install.sh | bash -s -- --skip-attestation
```

Note that this will configure a hard-coded cookie which will eventually expire. Your ship's local Codex and Opencode config files link to this README, which has instructions for getting a new cookie.

## Build from source

### 1. Build and Install

- *Requires a running [Urbit](https://docs.urbit.org/get-on-urbit) ship, real or fake, running on a machine you have terminal access to.*
- *Requires [Zig](https://ziglang.org/download/) 0.15 or newer. Make sure `zig version` works.*

Create and mount the desk on your Urbit ship:

```dojo
> |new-desk %mcp
> |mount %mcp
```

In the `urbit-mcp` folder, run `zig build`. By default this will install dependencies into `/dist` in this folder. Use the `-Ddesk` option to additionally replace the contents of your ship's desk with your source desk.

```bash
$ cd urbit-mcp
$ zig build -Ddesk=~/path/to/zod/mcp
```

```dojo
> |commit %mcp
> |install our %mcp
```

This installs four agents on your ship:

- `%mcp-server` — native MCP server bound to `/mcp`
- `%mcp-proxy` — aggregator bound to `/apps/mcp/api` and `/apps/mcp/mcp`
- `%mcp-fileserver` — serves the operator UI at `/apps/mcp/`
- `%oauth` — OAuth 2.0 + PKCE provider/grant manager

### 2. Open the operator console

Visit `http://localhost:PORT/apps/mcp/`.

The console has three tabs:

- **Endpoint** — the proxy aggregate URL and your `X-Api-Key`. Buttons to
  generate a random key, set a custom one, copy, or clear it. The page also
  shows a `claude mcp add` snippet pre-filled with your ship name and key.
- **Upstreams** — configured remote servers. The native server is registered
  automatically and tagged `BUILT-IN`. Add your own MCP servers, OpenAPI REST
  APIs, or Google Discovery documents. Each upstream can be linked to an OAuth
  provider for automatic token injection, and you can allow- or block-list
  individual tools.
- **OAuth** — manage OAuth 2.0 + PKCE providers. Connect / disconnect grants,
  edit endpoints, store client secrets (the secret is never returned to
  the browser; leaving the field blank in an edit preserves the saved value).
  OAuth providers can be assigned to upstreams and automatically renew
  expired sessions.

### 3A. Register with Claude Code

In the **Endpoint** tab, click `GEN` to mint an API key (or `SET` to use your
own). Then copy the snippet shown under `CLAUDE CLI`, which will look like:

```bash
claude mcp add --transport http zod \
  http://localhost:8080/apps/mcp/mcp \
  --header "X-Api-Key: <your-key>"
```

### 3B. Register with Codex

Codex needs the `mcp-proxy` python bridge. Install with `uvx mcp-proxy`, then
append to `~/.codex/config.toml`:

```toml
[mcp_servers.zod]
command = "uvx"
args = [
  "mcp-proxy",
  "--transport", "streamablehttp",
  "--headers", "X-Api-Key", "<your-key>",
  "http://localhost:8080/apps/mcp/mcp"
]
```

## Usage

### Tools

Just ask! You can see the default tools [here](./desk/fil/mcp/tools).

You can ask your LLM to add new Tools. Give it a description (and ideally, examples) and it will do its best, or provide a Hoon thread for it to adapt to run in `%mcp-server`. Threads in `%mcp-server` must be of signature `$-((map @t argument:tool:mcp) shed:khan)`.

### Prompts (slash commands)

Depending on your agent harness, MCP prompts for most default tools may be available as slash commands, e.g. `/mcp__zod__<tool name>`.

Running these will append a prompt snippet to the conversation and call out to the LLM provider. You can ask your LLM to add new Prompts.

### Resources (@ mentions)

Depending on your agent harness, MCP resources may be referenced with an `@` mention to pull their contents into the context window.

```
@zod:https://docs.urbit.org/llms.txt
```

You can ask your LLM to add new Resources by providing an `https://` URI to a public webpage or a `beam://` URI to a file in your Urbit's Clay filesystem.

## Contributing

This repo requires commits to be signed with a [Groundwire](https://groundwire.io/) identity. PRs with unsigned commits will be rejected by CI.

### Setup commit signing

You need an Urbit ship running the `%vitriol` agent.

**Quick install:**

```bash
./hooks/install.sh <your-ship-url>/vitriol "<auth-cookie>"
```

**Manual install:**

```bash
git config gpg.program /path/to/hooks/groundwire-sign
git config commit.gpgsign true
git config groundwire.sign-endpoint <your-ship-url>/vitriol
git config groundwire.sign-token "<auth-cookie>"
```

Once configured, all commits will be automatically signed with your ship's Ed25519 networking key. The CI verifies signatures against on-chain keys via [vitriol.bot](https://vitriol.bot).

### Re-signing existing commits

If you have unsigned commits on a branch:

```bash
git rebase --exec "true" HEAD~N
```

(where N is the number of commits to re-sign)

## Development

### Build Commands

- `zig build` - Build `/desk` and dependencies into `/dist`
- `zig build clean` - Remove `/dist`
- `zig build clear` - Remove `/dist` and cached dependencies from `.zig-cache/desk-deps`
- `zig build -Ddesk=~/path/to/desk` - Build, clean the target desk directory, and copy `dist` into it; supports absolute and relative paths
