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
| `"codex"` | `mcp_servers` | `url` (HTTP/SSE), `http_headers` (headers); retains `command`, `args`, `env` (stdio) |
| `"pi"` | `mcpServers` | `url` (HTTP/SSE); retains `command`, `args`, `env` (stdio); `type` removed |

---

## Merging Into Config Files (`bikeshed.agents.harnesses.<name>.mcp`)

The `homeModules.agents` module translates the generic `mcp.servers` of each harness instance with
`mcpServersForAgent` at build time and merges the result into the harness' own config file (e.g.
`~/.claude/.claude.json`, `~/.gemini/settings.json`). Because the agent CLI also writes to that file, the
module can't symlink it from the Nix store; instead an activation step runs `bikeshed-config-merge`
(`agents.mkConfigMerge`), which applies path-based operations to JSON and TOML targets.

Pick how the servers combine with whatever is already in the file via `mcp.strategy`:

| Strategy | Behavior |
| --------------- | -------- |
| `"replace"` | Overwrites managed top-level keys (e.g. `mcpServers`) wholesale. Sibling keys remain. |
| `"merge"` (default) | Deep merges one level: individual servers are updated/added; unmanaged ones remain. |

The merge only runs when `mcp.target` is non-null **and** `mcp.servers` is non-empty, so config
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

## Settings (`bikeshed.agents.harnesses.<name>.settings`)

`settings.entries` sets arbitrary values (e.g. provider configuration) in the harness config file, keyed by a
dotted path expression. `settings.target` is the config file relative to home and defaults to the harness' MCP
config file. Values are plain JSON/Nix data in the harness' native schema. Entries are applied in path order,
after the MCP servers.

| Strategy | Behavior |
| --------------- | -------- |
| `"merge"` (default) | Deep-merges objects into the existing value at the path. Anything else is replaced. |
| `"replace"` | Sets the value at the path. |

```nix
harnesses.opencode.settings.entries = {
  "provider.acme".value = {
    npm = "@ai-sdk/openai-compatible";
    options.baseURL = "https://llm.example/v1";
  };
  model = { value = "acme/large"; strategy = "replace"; };
};
```

In an `AgentConfig` file the same entries live under `spec.harnesses.<name>.settings.entries`, so an override file
can configure a model or provider at container startup or during home-manager activation.

---

## Agent Configuration Specification (`AgentConfig`)

Agent configuration across both desktop Home-Manager environments and container sandboxes is unified through the
`AgentConfig` specification (`apiVersion: bikeshed.szakallas.net/v1alpha1`, `kind: AgentConfig`), with a schema
defined in `lib/agents/agent-config.schema.json`.

### Rationale

1. **Shared Declarative Format**: Agent harnesses (such as Claude Code, OpenCode, and Gemini) frequently write
   runtime state, session tokens, and local cache entries into their own configuration files. Symlinking these files
   directly from the immutable `/nix/store` renders them read-only and causes agent runtime errors. By representing
   desired configurations as `AgentConfig` documents, Home-Manager and container sandboxes use the exact same
   underlying declarative pipeline.
2. **Unmanaged Runtime Overrides**: While base configurations are compiled at build time into the Nix store
   (`agents.mkBaseYaml`), users often need local, unmanaged overrides (e.g. secret API tokens, ad-hoc harness flags,
   or testing a different provider). In Docker/Podman containers, mounting a volume over
   `/etc/bikeshed/agents/init` makes customization trivial without rebuilding image layers. On host systems, files
   placed in `~/.config/bikeshed/agents/init` provide the same capability.
3. **Deep-Merge Semantics**: Multiple YAML documents are merged in lexical order using YAML deep-merge: map keys are
   recursively merged, while scalar values and lists from later documents replace earlier declarations.
4. **Isolated Wrapper Scripts**: Distinct harness instances (e.g. `claude` and `claude-qwen`) cannot safely share a
   single global environment variable (like `CLAUDE_CONFIG_DIR`). The activation step emits standalone executable
   wrappers in `wrappersDirectory` (`.bikeshed/bin`), exporting instance-specific session variables and flags when
   the harness is executed.

### Activation Mechanics (`activate-agent-configuration`)

The `activate-agent-configuration` script (also aliased as `codebox-init`):

1. Reads the base `AgentConfig` specification from `/nix/store` and any override documents found in
   `init.overridesDir` (default `.config/bikeshed/agents/init` for home-manager, or
   `/etc/bikeshed/agents/init:.config/bikeshed/agents/init` in codebox containers);
2. Deep-merges the specifications into a unified configuration tree;
3. Generates wrapper executables in `wrappersDirectory` (`.bikeshed/bin`) for enabled harnesses, injecting
   configured `sessionVariables`, optional `initExtra` bash snippets, and target arguments;
4. Symlinks agent skills and memory files into their respective target directories;
5. Merges MCP servers and settings entries into target JSON and TOML configuration files using `bikeshed-config-merge`;
6. Prunes dangling symlinks and removes wrapper scripts left by harnesses that are no longer enabled.

---

## Codebox Images (`agents.mkCodeboxImage`)

`agents.mkCodeboxImage pkgs { agents = { skills = …; harnesses.<name> = …; }; … }` builds a Docker image that
runs `paseo-server` with the selected harnesses installed. `agents` takes the same options as the home module
(`agents.agentsOptions`: `skills.{enable,entries,directory}`, `harnesses.<name>.*`, `init.*`). Other arguments:
`name`, `tag`, `modules` (Home-Manager modules to evaluate for the container environment), `paseo` (required: the
package providing `paseo-server`; the flake provides `packages.<system>.paseo`), `extraPackages`, `user`, `uid`, `gid`.
The flake exposes a default image as `dockerImages.<linux system>.codebox`.

Packages and skills are baked into the image. Everything touching the home directory happens at container startup
during Home-Manager activation. The entrypoint executes `${homeConfig.activationPackage}/activate` and launches
`paseo-server`.

Mount additional files into `/etc/bikeshed/agents/init` to customize the container:

```yaml
apiVersion: bikeshed.szakallas.net/v1alpha1
kind: AgentConfig
metadata:
  name: local-override
spec:
  skills:
    entries:
      my-skill: { source: /nix/store/…-my-skill }
  harnesses:
    opencode:
      mcp:
        servers:
          mcp:
            my-server: { type: remote, url: "https://example.com/mcp" }
    claude-qwen:
      enable: true
      harness: claude
      userDirectory: .claude-qwen
      wrapper:
        sessionVariables:
          CLAUDE_CONFIG_DIR: $HOME/.claude-qwen
```

---

## Other Agents Library Exports

- `agents.harnesses`: Attribute set of harness specifications, each defining `description`,
  `mcpKey`, `wrapMcpServers`, `transformMcpServerSpec`, optionally `homeConfiguration`
  (`defaultPackage` function taking `pkgs`, `defaultUserDirectory`, `defaultMemoryDirectory`,
  `defaultMemoryFile`, `defaultLinkSkills`, `defaultWrapper`, etc.), and optionally `projectConfiguration`
  (`defaultLinkSkills`, `defaultSkillsDirectory`, `defaultMcpTarget`).
- `agents.mcpServerType`: Submodule option type for an individual generic MCP server
  definition (`type`, `command`, `args`, `env`, `serverUrl`, `headers`).
- `agents.mcpServersType`: Attribute set option type (`attrsOf mcpServerType`) for declaring generic MCP servers.
- `agents.mcpServersForAgent`: Formats generic MCP server declarations for a specific agent harness.
- `agents.popularHarnesses`: List of popular agent harness identifiers configured across bikeshed:
  `[ "antigravity" "claude" "codex" "copilot" "gemini" "opencode" "pi" "vscode" ]`.
- `agents.homeHarnesses`: Harnesses with a home configuration (those usable as `harnesses.<name>`).
- `agents.allHarnesses`: List of all agent harness identifiers bikeshed can configure (currently identical to `popularHarnesses`).
- `agents.memory`: Provides standard agent prompt fragments (`audiences`, `avoidTropes`, `codingWorkflow`, `machineUse`).
- `agents.mkSkill pkgs { name, version, src, sourceRoot ? null, include ? null, ... }`: Creates a derivation
  containing skills found in directories with a `SKILL.md` file.
- `agents.assembleSkills`: Helper derivation to assemble skills from an attribute set or
  list of skill paths into a single derivation containing all discovered skills.
- `agents.assembleSkillsText`: The raw bash script text executed by `agents.assembleSkills`.
- `agents.mkActivateAgentConfiguration`: Creates the `activate-agent-configuration` derivation for an `AgentConfig`.
- `agents.mkCodeboxInit`: Alias to `mkActivateAgentConfiguration`.
- `agents.mkBaseSpec`: Evaluates the Nix specification into the base `AgentConfig` attrset.
- `agents.mkBaseYaml`: Produces the base `00-base.yaml` store derivation.
- `agents.mkConfigMerge`: Utility script for applying path-based JSON/TOML merge operations.
