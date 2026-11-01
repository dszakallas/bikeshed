---
name: bikeshed
description: How to use the common dotfiles repository, including home-manager and devenv agent module configurations, setting up MCP servers, and linking agent skills.
---

# Bikeshed Dotfiles Common Configuration

Use this skill when configuring or using modules from the `bikeshed` repository, especially AI agent setups in `home-manager` or `devenv`.

## Core Features

- **Home-Manager Agent Module**: Manages user-level agent configs, personal memories, and local MCP server configs.
- **Devenv Agent Module**: Automatically wires project-level MCP servers and symlinks development environment skills when entering a devenv shell.
- **Popular Harnesses (`popularHarnesses`)**: Standard list of supported agent harness identifiers (`[ "antigravity" "claude" "codex" "copilot" "gemini" "opencode" "pi" "vscode" ]`) recommended for dynamically configuring all agents without repetitive boilerplate.
- **Skill Compiler (`mkSkill`)**: A Nix derivation builder that gathers and filters markdown instructions into an agent-readable skills folder.
- **Skill Assembler (`assembleSkills`)**: Aggregates skill paths into a unified directory structure suitable for discovery.
- **Generic MCP Translation (`mcpServersForAgent`)**: Translates a single generic MCP configuration into schema expected by individual agent tools.

---

## Home-Manager Configuration

To use the agents module in your home-manager configuration, import `bikeshed.homeModules.agents`.

### Configuration Options

| Option | Type | Description |
|---|---|---|
| `bikeshed.agents.enable` | Boolean | Enables user-level AI agent configurations. |
| `bikeshed.agents.skills.enable` | Boolean | Enables linking custom skill sets. |
| `bikeshed.agents.skills.entries` | Attribute Set of Paths | Mapping of skill names to paths or derivations. |
| `bikeshed.agents.skills.directory` | String | Directory relative to home where all skills are linked (default `.agents/skills`). |
| `bikeshed.agents.harnesses.<name>.enable` | Boolean | Enables the harness instance. `<name>` selects the harness (any of `agents.homeHarnesses`) unless `harness` is set, so `claude` and `claude-qwen` can both configure Claude. |
| `bikeshed.agents.harnesses.<name>.harness` | Enum | Harness the instance configures. Defaults to `<name>`. |
| `bikeshed.agents.harnesses.<name>.package` | Null or Package | Package installed for the harness. |
| `bikeshed.agents.harnesses.<name>.userDirectory` | String | User directory relative to home. |
| `bikeshed.agents.harnesses.<name>.linkSkills` | Boolean | Whether to link compiled skills into the harness' skills directory. |
| `bikeshed.agents.harnesses.<name>.skillsDirectory` | String | Skills directory relative to home. |
| `bikeshed.agents.harnesses.<name>.memory.enable` | Boolean | Enables user-level memory file management. |
| `bikeshed.agents.harnesses.<name>.memory.source` | Null or Path | Source file for the main memory file (e.g. `GEMINI.md`, `CLAUDE.md`). |
| `bikeshed.agents.harnesses.<name>.mcp.strategy` | `"merge"` or `"replace"` | How servers combine with the existing config file. |
| `bikeshed.agents.harnesses.<name>.settings.entries` | Attribute Set | Settings merged into the harness config file, keyed by dotted path: `<path> = { value; strategy = "merge" \| "replace"; }`. |
| `bikeshed.agents.harnesses.<name>.mcp.servers` | Attribute Set | Generic MCP server definitions (`agents.mcpServersType`), translated to the harness' schema at build time. |
| `bikeshed.agents.harnesses.<name>.wrapper.enable` | Boolean | Generates an executable wrapper setting environment variables for config loading. Defaults to the harness's `defaultWrapper.enable` (`true` for claude, `false` for others). |
| `bikeshed.agents.harnesses.<name>.wrapper.executable` | Null, String, or Path | Path to the underlying executable to wrap when `package` is `null` (e.g. `"/opt/homebrew/bin/claude"`). Required if `package` is null and `wrapper.enable` is true. |
| `bikeshed.agents.harnesses.<name>.wrapper.executableName` | String | Wrapper executable name placed in PATH. Defaults to `<name>`. |
| `bikeshed.agents.harnesses.<name>.wrapper.environment` | Attribute Set | Additional environment variables set in the wrapper executable. |
| `bikeshed.agents.harnesses.<name>.wrapper.initExtra` | Strings (lines) | Bash script segment executed directly in the wrapper before running the executable. |

### Example Home-Manager Configuration

```nix
{
  config,
  pkgs,
  lib,
  bikeshed,
  ...
}:
let
  mcpServers = {
    fetch = {
      type = "stdio";
      command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";
    };
    github = {
      type = "http";
      serverUrl = "https://api.githubcopilot.com/mcp/";
      headers = {
        Authorization = "Bearer secret-token";
      };
    };
  };
in
{
  imports = [ bikeshed.homeModules.agents ];

  bikeshed.agents = {
    enable = true;
    skills = {
      enable = true;
      entries = {
        inherit (bikeshed.packages.${pkgs.system}.agentskills)
          anthropic-skills
          mattpocock-skills
          ;
        local-skills = bikeshed.lib.agents.mkSkill pkgs {
          name = "local-skills";
          version = "0.1.0";
          src = ./skills;
        };
      };
    };
    harnesses = lib.genAttrs bikeshed.lib.agents.homeHarnesses (agent: {
      enable = true;
      linkSkills = true;
      memory = {
        enable = true;
        source = ./memories/${agent}.md;
      };
      mcp.servers = mcpServers;
    });
  };
}
```

---

## Devenv Project-Level Configuration

In a repository with `devenv.nix`, use `bikeshed.devenvModules.agents` to inject MCP configurations and link custom skills.

### Example `devenv.nix` Configuration

```nix
{ pkgs, lib, inputs, ... }:
{
  imports = [ inputs.bikeshed.devenvModules.agents ];

  bikeshed.agents = {
    enable = true;
    skills = [
      ./my-custom-skills
    ];
    mcp.servers = {
      memory = {
        type = "stdio";
        command = "${pkgs.mcp-server-memory}/bin/mcp-server-memory";
      };
    };
  };
}
```
