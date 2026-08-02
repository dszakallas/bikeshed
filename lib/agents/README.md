# Agents Library (`lib/agents`)

This directory contains helpers and data structures for managing AI agent configurations, skills, memory, and MCP
(Model Context Protocol) servers.

## MCP Server Configuration Schema

The `agents.mcpServersForAgent` function transforms a generic MCP server attribute set into the agent-specific format
expected by various AI tools (e.g. Gemini, Claude, Copilot, VS Code, OpenCode).

### Generic Input Schema (`mcpServers`)

MCP servers are defined as an attribute set where each attribute name is the server identifier, and its value is a
configuration set with the following structure:

```nix
{
  github = {
    type = "http";
    serverUrl = "https://api.githubcopilot.com/mcp/";
    headers = {
      Authorization = "Bearer token...";
    };
  };
  local-tool = {
    type = "stdio";
    command = "${pkgs.my-mcp-server}/bin/server";
    args = [ "--verbose" ];
    env = {
      LOG_LEVEL = "debug";
    };
  };
}
```

#### Common Fields

- `type` (string, required): Transport protocol. Must be one of `"stdio"`, `"http"`, or `"sse"`.

#### Stdio Transport Fields (`type = "stdio"`)

- `command` (string, required): Path to the executable or command name.
- `args` (list of strings, optional): Command line arguments. Defaults to `[]`.
- `env` (attribute set of strings, optional): Environment variables for the process.

> **Validation**: Stdio servers must not define `serverUrl` or `headers`.

#### HTTP and SSE Transport Fields (`type = "http"` or `"sse"`)

- `serverUrl` (string, required): URL of the MCP server endpoint.
- `headers` (attribute set of strings, optional): Custom HTTP headers.

> **Validation**: HTTP/SSE servers must not define `command`, `args`, or `env`.

---

### Agent Transformations

`mcpServersForAgent agent value` accepts an `agent` string and the generic `mcpServers` set, returning the formatted
configuration wrapped in the target agent's expected top-level key:

| Target Agent (`agent`) | Top-Level Key | Transport Renamings & Behavior |
| ---------------------- | ------------- | ------------------------------ |
| `"gemini"` | `mcpServers` | `httpUrl` (HTTP) / `url` (SSE); `type` removed |
| `"antigravity"` | `mcpServers` | Keeps `type` and standard field names |
| `"claude"` | `mcpServers` | `url` (HTTP/SSE); retains `type` |
| `"copilot"` | `mcpServers` | `url` (HTTP/SSE); adds `tools = [ "*" ]`; warns on SSE |
| `"vscode"` | `servers` | `url` (HTTP/SSE); retains `type` |
| `"opencode"` | `mcp` | `type = "remote"` + `url` (HTTP/SSE); `type = "local"`: `command`, `environment` (stdio) |

---

## Merging Into Config Files (`bikeshed.agents.<agent>.mcp`)

The `homeModules.agents` module writes the agent-shaped output of `mcpServersForAgent` into each
agent's own config file (e.g. `~/.claude/.claude.json`, `~/.gemini/settings.json`). Because the
agent CLI also writes to that file, the module can't symlink it from the Nix store; instead an
activation step merges the managed servers in with `jq`.

Set `bikeshed.agents.<agent>.mcp.servers` to the wrapped output of `mcpServersForAgent`, and pick how
it combines with whatever is already in the file via `bikeshed.agents.<agent>.mcp.strategy`:

| Strategy | Behavior |
| --------------- | -------- |
| `"replace"` | Overwrites managed top-level keys (e.g. `mcpServers`) wholesale. Sibling keys remain. |
| `"merge"` (default) | Deep merges one level: individual servers are updated/added; unmanaged ones remain. |

The activation only runs when `mcp.target` is non-null **and** `mcp.servers` is non-empty, so config

files for agents you don't manage are never created or touched.

### Example

Given an existing `~/.claude/.claude.json` and a managed set that redefines `glean` and adds
`atlassian`:

```jsonc
// existing (on disk, partly written by the CLI)
{ "otherKey": {}, "mcpServers": { "cliAdded": {...}, "glean": { "command": "OLD", "stale": true } } }
// managed (from mcpServersForAgent)
{ "mcpServers": { "glean": { "command": "NEW" }, "atlassian": {...} } }
```

- `"merge"` → `cliAdded` kept, `glean` replaced wholesale (dropping `stale`), `atlassian` added,
  `otherKey` kept.
- `"replace"` → the whole `mcpServers` object becomes `{ glean, atlassian }` (`cliAdded` lost);
  `otherKey` kept.

---

## Other Agents Library Exports

- `agents.memory`: Provides standard agent prompt fragments (`avoidTropes`, `disableAttributions`).
- `agents.mkSkill`: Helper derivation to package skill sets containing `SKILL.md` files.
