# Agents library (`lib/agents`)

This directory provides tools to manage AI agent configurations, skills, memory prompts, and Model
Context Protocol (MCP) servers across desktop workstations and container sandboxes.

## Motivation

This library unifies AI developer tooling across both developer workstations running Home-Manager and
containerized sandboxes:

- Configure multiple agent CLIs (Claude Code, OpenCode, Gemini CLI, GitHub Copilot, Codex, Pi, VS Code) from one place.
- Share common skill packages and memory instruction prompts across all tools without duplicating files.
- Translate generic MCP server definitions into agent-specific formats automatically.
- Isolate multiple instances of the same tool (such as default Claude and a local-model Claude) using dedicated home
  directories and wrapper executables in `~/.bikeshed/bin`.
- Retain write access for tools that persist tokens and session state at runtime by updating configuration files
  in-place during activation rather than symlinking read-only files from `/nix/store`.
- Apply unmanaged runtime overrides (such as local model endpoints or secret API tokens) using YAML files placed in
  user directories or mounted into containers via volume mounts.

## Module options and examples

The `homeModules.agents` module exposes declarative options under the `bikeshed.agents` namespace.

### Top-level options

| Option (`bikeshed.agents.*`) | Type | Default | Description |
| --- | --- | --- | --- |
| `enable` | boolean | `false` | Enables agent configuration management. |
| `wrappersDirectory` | path | `".bikeshed/bin"` | Directory for wrapper scripts relative to `$HOME`. |
| `init.enable` | boolean | `true` | Runs activation during Home-Manager switch. |
| `init.overridesDir` | string | `".../init"` | Search paths for unmanaged override files. |
| `skills.enable` | boolean | `true` | Enables skill distribution. |
| `skills.directory` | path | `".../skills"` | Destination path for assembled skills. |
| `skills.entries` | attrs | `{}` | Skill source packages indexed by skill name. |

### Harness options (`bikeshed.agents.harnesses.<name>`)

Each instance under `bikeshed.agents.harnesses` configures a distinct agent tool:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enable` | boolean | `true` | Enables this harness instance. |
| `harness` | string | `<name>` | Base harness type (e.g. `"claude"`, `"gemini"`, `"opencode"`). |
| `package` | package or null | harness default | Package providing the CLI tool. |
| `binary` | string or null | `null` | Binary name to execute. Defaults to package mainProgram or harness name. |
| `env` | attrs of string | `{}` | Additional environment variables set in the harness wrapper script. |
| `userDirectory` | path | harness default | State and configuration directory relative to `$HOME`. |
| `linkSkills` | boolean | harness default | Symlinks shared skills into the harness skill directory. |
| `skillsDirectory` | path | harness default | Destination path for linked skills. |
| `memory.enable` | boolean | `false` | Links memory instruction files into the harness memory directory. |
| `memory.directory` | path | harness default | Destination path for memory files. |
| `memory.target` | string | harness default | File name of the main memory file inside the memory directory. |
| `memory.source` | path or null | `null` | Path to the source file for the main memory file. |
| `memory.content` | string or null | `null` | Raw text content of the main memory file. |
| `wrapper.enable` | boolean | `true` | Generates an executable launcher script in `wrappersDirectory`. |
| `wrapper.name` | string | `<name>` | Executable name of the wrapper script in `wrappersDirectory`. |
| `wrapper.executable` | string or null | `null` | Target executable path or binary name. |
| `wrapper.sessionVariables` | attrs of string | `{}` | Environment variables exported by the wrapper script. |
| `wrapper.initExtra` | string | `""` | Shell commands run before launching the target executable. |
| `wrapper.args` | list of strings | `[]` | Default arguments appended to executable invocations. |
| `mcp.servers` | attrs of mcpServer | `{}` | Generic MCP server definitions. |
| `mcp.strategy` | `"merge"` or `"replace"` | `"merge"` | Merge strategy for top-level MCP keys. |
| `mcp.target` | path or null | harness default | Target configuration file relative to `$HOME`. |
| `settings.target` | path or null | harness default | Target configuration file for settings entries. |
| `settings.entries` | attrs of settingEntry | `{}` | Dotted-path values patched into the configuration file. |

### Supported harnesses

The following agent harnesses are defined in `lib/agents/harnesses`:

| Harness | Definition | Home-Manager | Default user directory | Default MCP target |
| --- | --- | --- | --- | --- |
| `antigravity` | [antigravity.nix](harnesses/antigravity.nix) | Yes | `.gemini/antigravity-cli` | — |
| `claude` | [claude.nix](harnesses/claude.nix) | Yes | `.claude` | `.claude/.claude.json` |
| `codex` | [codex.nix](harnesses/codex.nix) | Yes | `.codex` | `.codex/config.toml` |
| `copilot` | [copilot.nix](harnesses/copilot.nix) | Yes | `.copilot` | `.copilot/mcp-config.json` |
| `gemini` | [gemini.nix](harnesses/gemini.nix) | Yes | `.gemini` | `.gemini/settings.json` |
| `opencode` | [opencode.nix](harnesses/opencode.nix) | Yes | `.config/opencode` | `.config/opencode/opencode.json` |
| `pi` | [pi.nix](harnesses/pi.nix) | Yes | `.pi/agent` | `.pi/agent/mcp.json` |
| `vscode` | [vscode.nix](harnesses/vscode.nix) | No (project-only) | — | `.vscode/mcp.json` |

### Home-Manager configuration example

The following configuration sets up shared skills, a standard Claude harness with an MCP server, a second Claude
instance routed to a local model via wrapper session variables, and provider settings for OpenCode:

```nix
{ pkgs, ... }:
{
  bikeshed.agents = {
    enable = true;

    skills.entries = {
      review-tools = pkgs.my-skills-package;
      repo-helpers = /path/to/local/skills;
    };

    harnesses = {
      claude = {
        mcp.servers = {
          local-linter = {
            type = "stdio";
            command = "${pkgs.ruff}/bin/ruff";
            args = [ "server" ];
          };
        };
      };

      claude-qwen = {
        harness = "claude";
        userDirectory = ".claude-qwen";
        wrapper = {
          enable = true;
          sessionVariables = {
            CLAUDE_CONFIG_DIR = "$HOME/.claude-qwen";
            ANTHROPIC_BASE_URL = "http://localhost:11434";
          };
        };
      };

      opencode = {
        settings.entries = {
          "provider.local".value = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "http://localhost:11434/v1";
          };
          model = {
            value = "local/qwen2.5-coder";
            strategy = "replace";
          };
        };
      };
    };
  };
}
```

## Override mechanism

The override mechanism decouples build-time declarative configuration from runtime adjustments.

### Rationale

Declarative Nix expressions compile a base configuration into `/nix/store`. However, agent CLIs write runtime state,
authentication tokens, and session histories directly into their configuration files. Symlinking configuration files
to the read-only Nix store causes agent commands to fail during normal operation.

Furthermore, developers frequently need local or transient adjustments:

- Adding private API keys or personal access tokens without committing them to git.
- Testing local model endpoints or experimental flags.
- Customizing container sandboxes at launch time without rebuilding container image layers.

To support these requirements, Nix compiles intermediate declarations rather than linking target configuration
files directly. At activation time, `activate-agent-configuration` combines the managed base configuration with
unmanaged local files before updating target paths.

### Specification schema (`AgentConfig`)

Both the managed base configuration and unmanaged overrides use the `AgentConfig` specification document format:

- `apiVersion`: `bikeshed.szakallas.net/v1alpha1`
- `kind`: `AgentConfig`
- Schema validator: `lib/agents/agent-config.schema.json`

The top-level fields match the structure evaluated from the Nix options:

```yaml
apiVersion: bikeshed.szakallas.net/v1alpha1
kind: AgentConfig
metadata:
  name: example-config
spec:
  wrappersDirectory: .bikeshed/bin
  skills:
    directory: .config/bikeshed/agents/skills
    entries:
      my-skill:
        source: /nix/store/...-my-skill
  harnesses:
    claude:
      userDirectory: .claude
      linkSkills: true
      skillsDirectory: .claude/skills
      mcp:
        target: .claude/.claude.json
        strategy: merge
        servers:
          mcpServers:
            linter:
              command: /nix/store/.../bin/ruff
              args: [server]
```

### Discovery and merge order

During activation, `activate-agent-configuration`:

1. Loads the base specification emitted by Nix into the store (`00-base.yaml`).
2. Scans the directories configured in `init.overridesDir` (defaulting to `.config/bikeshed/agents/init` on host
   systems, or `/etc/bikeshed/agents/init:.config/bikeshed/agents/init` in containers).
3. Gathers all `.yaml` and `.yml` files in those directories and sorts them alphabetically.
4. Sequentially merges the documents in order:
   - Object maps are recursively merged.
   - Scalar values (strings, numbers, booleans) and arrays from later documents replace earlier values.

### Activation steps

Once the configuration tree is computed, `activate-agent-configuration` executes the following steps:

1. Creates wrapper executables in `wrappersDirectory` for each enabled harness. Each wrapper exports configured
   `sessionVariables`, runs `initExtra` commands, and delegates to the target executable.
2. Populates the central skills directory and creates symlinks inside each harness's `skillsDirectory`.
3. Symlinks memory instruction files into each harness's `memory.directory`.
4. Executes `bikeshed-config-merge` to patch JSON and TOML configuration files with managed MCP servers and
   settings entries.
5. Removes dangling symlinks and deletes wrapper scripts left by harnesses that were removed or disabled.

### Override example

To add an unmanaged MCP server and custom model setting, place a YAML file such as
`~/.config/bikeshed/agents/init/99-local.yaml` (or mount it into `/etc/bikeshed/agents/init/99-local.yaml`):

```yaml
apiVersion: bikeshed.szakallas.net/v1alpha1
kind: AgentConfig
metadata:
  name: local-overrides
spec:
  harnesses:
    opencode:
      mcp:
        servers:
          mcp:
            remote-docs:
              type: remote
              url: https://docs.internal.example/mcp
      settings:
        entries:
          model:
            value: custom-provider/code-model
            strategy: replace
    claude-dev:
      enable: true
      harness: claude
      userDirectory: .claude-dev
      wrapper:
        enable: true
        sessionVariables:
          CLAUDE_CONFIG_DIR: $HOME/.claude-dev
```

## Agent sandbox container images

We provide experimental tooling to build container images for agentic development.

### Paseo sandbox image (Experimental)

I am currently using the open source [paseo](https://paseo.sh) tool for agent orchestration as it supports multiple
harnesses such as Claude, Codex, and OpenCode, which fits my workflow.

`agents.mkPaseoSandboxImage` builds a container image containing `paseo-server` for agentic development. It uses
home-manager to configure the sandbox. By default, it just installs the `paseo` package with some configuration, you
will need to add the actual agent harnesses, skills, mcp servers, packages, etc. you want your agents to use in the container.

Just add any home-manager modules you want to the `modules` list, and the resulting image
will contain all the configured packages and tools.

```nix
agents.mkPaseoSandboxImage pkgs {
  name = "paseo-sandbox-example";
  tag = "latest";
  modules = [
    outputs.homeModules.base
    outputs.homeModules.agents
    {
      bikeshed.agents = {
        enable = true;
        skills.enable = true;
        skills.entries = {
          anthropic-skills = outputs.packages.${system}.agentskills.anthropic-skills;
          mattpocock-skills = outputs.packages.${system}.agentskills.mattpocock-skills;
        };
        # install OpenCode
        harnesses.opencode.enable = true;
      };
    }
  ];
}
```

The container entrypoint executes the Home-Manager activation package when the container starts.

The above example imports the agents home module (`outputs.homeModules.agents`), and uses it to set up some skills
and OpenCode, just like you would use it on your local machine.
If you want custom overrides for your agents, you can mount a directory containing override
YAML files into `/etc/bikeshed/agents/init`:

```bash
docker run -d \
  -v /path/to/my-overrides:/etc/bikeshed/agents/init:ro \
  paseo-sandbox-example:latest
```

This way you can pass dynamic configuration to your agents without rebuilding the container image.

## MCP server protocol translation

The `agents.mcpServersForAgent` function converts generic MCP server definitions into the format required by each
supported agent CLI.

### Generic input schema

MCP servers are defined as an attribute set where each entry represents a server definition:

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

Field rules:

- `type` (required string): `"stdio"`, `"http"`, or `"sse"`.
- Stdio transport (`type = "stdio"`): requires `command`; accepts optional `args` (list) and `env` (attrset).
  Must not specify `serverUrl` or `headers`.
- Remote transport (`type = "http"` or `"sse"`): requires `serverUrl`; accepts optional `headers` (attrset).
  Must not specify `command`, `args`, or `env`.

### Target agent transformations

`mcpServersForAgent agent servers` returns the configuration formatted for the target agent:

| Target Agent | Top-Level Key | Protocol Translation Rules |
| --- | --- | --- |
| `"gemini"` | `mcpServers` | `httpUrl` (HTTP) / `url` (SSE); `type` removed |
| `"antigravity"` | `mcpServers` | Standard field names; `type` preserved |
| `"claude"` | `mcpServers` | `url` (HTTP/SSE); `type` preserved |
| `"copilot"` | `mcpServers` | `url` (HTTP/SSE); adds `tools = [ "*" ]` |
| `"vscode"` | `servers` | `url` (HTTP/SSE); `type` preserved |
| `"opencode"` | `mcp` | `type = "remote"` + `url` (HTTP/SSE); `type = "local"`: `command`, `environment` (stdio) |
| `"codex"` | `mcp_servers` | `url` (HTTP/SSE), `http_headers` (headers); `command`, `args`, `env` (stdio) |
| `"pi"` | `mcpServers` | `url` (HTTP/SSE); `command`, `args`, `env` (stdio); `type` removed |

### Configuration merge strategies

The `mcp.strategy` option determines how managed servers merge into existing files:

| Strategy | Description |
| --- | --- |
| `"merge"` (default) | Updates or adds individual managed servers. Preserves unmanaged servers in the target file. |
| `"replace"` | Overwrites the entire top-level MCP key. Preserves unrelated sibling keys in the configuration file. |

## Library exports reference

The `ctx.lib.agents` attribute set exports the following functions and values:

| Attribute | Description |
| --- | --- |
| `harnesses` | Attribute set of all known harness definitions and their default settings. |
| `homeHarnesses` | Harnesses supported for Home-Manager user configuration. |
| `popularHarnesses` | Default list of popular agent harnesses configured across bikeshed. |
| `allHarnesses` | List of all supported agent harness identifiers. |
| `memory` | Standard prompt memory fragments (audiences, tropes, coding workflow, machine use). |
| `mcpServerType` | Submodule option type for an individual MCP server. |
| `mcpServersType` | Attribute set option type for multiple MCP server definitions. |
| `mcpServersForAgent` | Converts generic MCP server definitions into a target agent's schema. |
| `mkSkill` | Builds a skill derivation from a source directory containing `SKILL.md`. |
| `assembleSkills` | Derivation combining multiple skill paths into a single unified directory. |
| `mkBaseSpec` | Evaluates module options into an `AgentConfig` attribute set. |
| `mkBaseYaml` | Builds the base `00-base.yaml` store derivation from an `AgentConfig` attribute set. |
| `mkActivateAgentConfiguration` | Derivation providing the `activate-agent-configuration` executable. |
| `mkConfigMerge` | Derivation providing `bikeshed-config-merge` for JSON and TOML path patching. |
| `mkPaseoSandboxImage` | Builds a Docker container image with Paseo server and configured agent tools. |
