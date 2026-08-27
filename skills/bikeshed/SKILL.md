---
name: bikeshed
description: "How to use the common dotfiles repository, including home-manager and devenv agent module configurations, setting up MCP servers, and linking agent skills."
tags: [nix, home-manager, devenv, agents, dotfiles]
---

# bikeshed - AI Agent and System Configuration Library

Use this skill when configuring or using modules from the `bikeshed` repository, particularly when setting up home-manager or devenv configuration for AI agents (such as Claude, Gemini, Copilot, or VSCode).

## Core Features

- **Home-Manager Agent Module**: Manages user-level agent configs, personal memories, system rules, and local MCP server configs.
- **Devenv Agent Module**: Automatically wires project-level MCP servers and symlinks development environment skills when entering a devenv shell.
- **Skill Compiler (`mkSkill`)**: A Nix derivation builder that gathers and filters markdown instructions into an agent-readable skills folder.
- **MCP Server Formatter (`mcpServersForAgent`)**: Formats generic MCP server declarations into the target schemas expected by different agents (e.g. Gemini, Claude, Copilot, VSCode).

---

## Home-Manager Configuration

To use the agents module in your home-manager configuration, import `bikeshed.homeModules.agents`. This exposes options under the `bikeshed.agents` namespace.

### Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `bikeshed.agents.enable` | Boolean | Enables user-level AI agent configurations. |
| `bikeshed.agents.skills.enable` | Boolean | Enables linking custom skill sets. |
| `bikeshed.agents.skills.entries` | Attribute Set of Paths | Mapping of skill names to paths or derivations. |
| `bikeshed.agents.<agent>.enable` | Boolean | Enables config for `<agent>` (gemini, claude, copilot, antigravity, opencode, codex). |
| `bikeshed.agents.<agent>.linkSkills` | Boolean | Whether to link compiled skills into the agent's directory. |
| `bikeshed.agents.<agent>.memory.enable` | Boolean | Enables user-level memory file management. |
| `bikeshed.agents.<agent>.memory.source` | Null or Path | Source file for the agent's main memory file (e.g. `GEMINI.md`, `CLAUDE.md`). |
| `bikeshed.agents.<agent>.mcp.enable` | Boolean | Enables merging user-level MCP servers. |
| `bikeshed.agents.<agent>.mcp.servers` | Attribute Set | MCP server definitions. |

### Example Home-Manager Configuration

```nix
{ pkgs, lib, config, bikeshed, ... }:

{
  imports = [
    bikeshed.homeModules.agents
  ];

  bikeshed.agents = {
    enable = true;
    skills = {
      enable = true;
      entries = {
        # Local custom workspace skills
        local-skills = bikeshed.lib.agents.mkSkill pkgs {
          name = "local-skills";
          version = "1.0.0";
          src = ./skills;
        };

        # Remote skill set fetched from a GitHub repository
        cc-skills-golang = bikeshed.lib.agents.mkSkill pkgs {
          name = "cc-skills-golang";
          version = "2026-07-02";
          src = pkgs.fetchFromGitHub {
            owner = "samber";
            repo = "cc-skills-golang";
            rev = "8b2d019212d6a5390d472a7660a8489109d7db49";
            hash = "sha256-oSFApXKBndeM1wsl6GyPwiDuIgt5bGXWzDtpnmC6SaM=";
          };
        };
      };
    };

    claude = {
      enable = true;
      linkSkills = true;
      memory = {
        enable = true;
        source = ./memories/CLAUDE.md;
      };
      mcp = {
        enable = true;
        servers = {
          sqlite = {
            command = "${pkgs.nodejs}/bin/node";
            args = [ "${pkgs.sqlite-mcp-server}/lib/index.js" "/path/to/db.sqlite" ];
          };
        };
      };
    };
  };
}
```

---

## Devenv Configuration

To manage project-level development environment configurations for AI agents, use the `devenvModules.agents` module. It automatically manages MCP servers and project-specific skills, ensuring agents have access to local dev processes.

### Option Reference

- `agents.mcp.enable`: Enables general MCP setup for the project.
- `agents.mcp.servers`: Attribute set of MCP servers (writes to `.agents/mcp_config.json`).
- `agents.skills.enable`: Enables linking skills for this devenv.
- `agents.skills.entries`: Attribute set of paths to skill directories to assemble and link under `.agents/skills/`.
- `agents.<agent>.enable`: Configures individual agent integration (claude, gemini, copilot, vscode, opencode, codex).
- `agents.<agent>.mcp.enable`: Configures target-specific MCP setup (e.g. `.mcp.json` for Claude).
- `agents.<agent>.mcp.servers`: MCP servers specific to the agent.
- `agents.<agent>.linkSkills`: Symlinks the compiled skills into the agent's local config folder (e.g., `.claude/skills`).

---

## Setting up Devenv with `bikeshed`

### 1. Define inputs in `devenv.yaml`

Configure `bikeshed` as an input in `devenv.yaml`:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  git-hooks:
    url: github:cachix/git-hooks.nix
    inputs:
      nixpkgs:
        follows: nixpkgs
  bikeshed:
    url: github:dszakallas/bikeshed
    inputs:
      nixpkgs:
        follows: nixpkgs
```

### 2. Configure `devenv.nix` with an `agents` Profile

To prevent resource-heavy tasks (like pulling remote skills or configuring MCP servers) from running in automated environments where they aren't needed (such as CI), declare the agents configuration inside a separate `agents` profile:

```nix
{ pkgs, lib, config, inputs, ... }@args:

{
  # Other general configuration (e.g. packages, git-hooks) goes here

  # Declare the resource-isolated "agents" profile
  profiles.agents.module = {
    imports = [
      inputs.bikeshed.devenvModules.agents
    ];

    agents = let
      commonLib = inputs.bikeshed.lib;
      
      # Define project-specific MCP servers
      mcpServers = {
        devenv = {
          command = "devenv";
          args = [ "mcp" ];
          env = {
            DEVENV_ROOT = config.devenv.root;
          };
        };
      };
    in {
      mcp = {
        enable = true;
        servers = mcpServers;
      };
      
      skills = {
        enable = true;
        entries = {
          # Package shared skills from bikeshed
          shared = commonLib.agents.mkSkill pkgs {
            name = "shared-skills";
            version = "unstable";
            src = inputs.bikeshed.outPath;
            include = [ "devenv" ];
          };
        };
      };

      # Configure target-specific settings for the active agents
      # This merges our devenv MCP server into their respective configuration files when entering the shell
      claude = {
        enable = true;
        mcp.enable = true;
        mcp.servers = commonLib.agents.mcpServersForAgent "claude" mcpServers;
      };
      
      gemini = {
        enable = true;
        mcp.enable = true;
        mcp.servers = commonLib.agents.mcpServersForAgent "gemini" mcpServers;
      };
    };
  };
}
```

### 3. Entering the shell with the profile

During local development, enter the shell with the `agents` profile enabled:

```bash
devenv shell -p agents
```

This isolates the setup tasks, ensuring that CI/automated builds (which run standard `devenv shell` or test tasks without the profile) will skip running unnecessary agent-setup scripts and hook evaluations.

---

## Packaging Skills with `mkSkill`

The `mkSkill` utility compiles one or more agent skills (either from local directories or remote repositories) into a Nix derivation so they can be symlinked into the agent's workspace or configuration path.

### Function Signature

```nix
bikeshed.lib.agents.mkSkill pkgs {
  name = "skill-name";
  version = "1.0.0";
  src = ./path-to-source;
  include = [ "specific-skill-folder" ]; # Optional, defaults to null (includes all)
  exclude = [ "ignored-skill-folder" ];  # Optional, defaults to []
}
```

### Parameter Details

- **`pkgs`**: The Nixpkgs package set used to run the build derivation.
- **`name`**: The package/derivation name.
- **`version`**: The version identifier of the skill set.
- **`src`**: The source directory or derivation containing the skills.
  - **Local Path**: You can supply a local directory path (e.g. `./skills` or `inputs.bikeshed.outPath`).
  - **Remote Repository**: Since installing remote community skills is common, you can fetch skills directly from Git/GitHub using helpers like `pkgs.fetchFromGitHub` or `pkgs.fetchgit`.
- **`include`**: An optional list of skill folder names to explicitly package. If `null`, all discovered skills are included.
- **`exclude`**: An optional list of skill folder names to filter out of the derivation output.

### Behavioral and Directory Structure Rules

1. **Root Search**: If the provided `src` directory has a subdirectory named `skills`, `mkSkill` will search within `src/skills`. Otherwise, it will search the root of `src`.
2. **Skill Discovery**: The builder looks recursively for files named `SKILL.md`. Each directory containing a `SKILL.md` is considered a single, isolated skill unit named after the parent directory (or the derivation name if `SKILL.md` is in the search root).
3. **Filtering**: If `include` or `exclude` are provided, the builder matches the subdirectory basenames against these list options to decide what gets copied.
4. **Output Structure**: The resulting derivation packages each compiled skill directory, maintaining the layout so they can be automatically symlinked into agent-specific configuration paths (like `.claude/skills` or `.gemini/config/skills`).

### Usage Example: Mixing Local and Remote Skills

```nix
bikeshed.agents.skills.entries = {
  # Local custom workspace skills
  local-project-skills = bikeshed.lib.agents.mkSkill pkgs {
    name = "project-skills";
    version = "1.0.0";
    src = ./my-skills-dir;
  };

  # Remote Go-specific agent skills
  cc-skills-golang = bikeshed.lib.agents.mkSkill pkgs {
    name = "cc-skills-golang";
    version = "2026-07-02";
    src = pkgs.fetchFromGitHub {
      owner = "samber";
      repo = "cc-skills-golang";
      rev = "8b2d019212d6a5390d472a7660a8489109d7db49";
      hash = "sha256-oSFApXKBndeM1wsl6GyPwiDuIgt5bGXWzDtpnmC6SaM=";
    };
  };
};
```

---

## Formatting MCP Server Configuration with `mcpServersForAgent`

Since different AI agents use slightly different schemas for declaring HTTP and SSE MCP servers, the `mcpServersForAgent` helper formats standard server attributes for a specific agent.

### Function Signature

```nix
bikeshed.lib.agents.mcpServersForAgent agentName genericMcpServers
```

### Server Type Conversions
- **Gemini**: Automatically renames HTTP transport targets to `httpUrl` and SSE transport targets to `url`.
- **Claude / Copilot**: Automatically normalizes HTTP and SSE targets to `url` while keeping `type`.
- **Codex**: Formats MCP servers into TOML `mcp_servers` with `url` and `http_headers`.
- **Validation**: Enforces fields like `command`, `args`, and `env` are only defined for `stdio` transports, and that `serverUrl` is defined for `http`/`sse` transports.
