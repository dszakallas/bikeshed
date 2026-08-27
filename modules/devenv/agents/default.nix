ctx:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  # Merge the managed JSON object into an existing config file, replacing the
  # top-level keys we own (e.g. mcpServers) while preserving any sibling keys.
  # `jq -s '.[0] + .[1]'` is a shallow merge: managed keys overwrite existing
  # ones, keys present only in the existing file are kept.
  mkMergeTask = description: path: managed: {
    inherit description;
    exec = ''
      target="${path}"
      mkdir -p "$(dirname "$target")"
      [ -f "$target" ] || echo '{}' > "$target"
      ${pkgs.jq}/bin/jq -s '.[0] + .[1]' "$target" - << 'EOF' > "$target.tmp"
      ${builtins.toJSON managed}
      EOF
      mv "$target.tmp" "$target"
      chmod 600 "$target"
    '';
    before = [ "devenv:enterShell" ];
  };

  mkMergeTomlTask = description: path: managed: {
    inherit description;
    exec = ''
      target="${path}"
      mkdir -p "$(dirname "$target")"
      managed_toml=$(mktemp)
      trap 'rm -f "$managed_toml"' EXIT
      ${pkgs.yq-go}/bin/yq -p json -o toml '.' << 'EOF' > "$managed_toml"
      ${builtins.toJSON managed}
      EOF
      if [ -s "$target" ]; then
        ${pkgs.yq-go}/bin/yq eval-all -p toml -o toml \
          'select(fileIndex == 0) as $orig | select(fileIndex == 1) as $managed | $orig * $managed | .mcp_servers = $managed.mcp_servers' \
          "$target" "$managed_toml" > "$target.tmp"
        mv "$target.tmp" "$target"
      else
        cp "$managed_toml" "$target"
      fi
      chmod 600 "$target"
    '';
    before = [ "devenv:enterShell" ];
  };

  mcpServers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum [
              "stdio"
              "http"
              "sse"
            ];
            default = "stdio";
            description = "Transport type of the MCP server.";
          };
          command = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command to execute for stdio MCP servers.";
          };
          args = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = "Arguments to pass to the command for stdio MCP servers.";
          };
          env = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = null;
            description = "Environment variables for stdio MCP servers.";
          };
          serverUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "URL for HTTP or SSE MCP servers.";
          };
          headers = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = null;
            description = "HTTP headers for HTTP or SSE MCP servers (e.g., for authentication).";
          };
        };
      }
    );
    default = {
      devenv = {
        command = "devenv";
        args = [ "mcp" ];
        env = {
          DEVENV_ROOT = config.devenv.root;
        };
      };
    };
    description = ''
      MCP (Model Context Protocol) servers to configure.
      These servers provide additional capabilities and context to AI coding agents.
    '';
    example = lib.literalExpression ''
      {
        awslabs-iam-mcp-server = {
          command = lib.getExe pkgs.awslabs-iam-mcp-server;
          args = [ ];
          env = { };
        };
        github = {
          serverUrl = "https://api.githubcopilot.com/mcp/";
          headers = {
            Authorization = "Bearer GITHUB_PAT";
          };
        };
        linear = {
          httpUrl = "https://mcp.linear.app/mcp";
        };
        devenv = {
          command = "devenv";
          args = [ "mcp" ];
          env = {
            DEVENV_ROOT = config.devenv.root;
          };
        };
      }
    '';
  };

  assembled-skills =
    pkgs.runCommand "assembled-skills"
      {
        entries = lib.mapAttrsToList (name: path: "${name}:${path}") config.agents.skills.entries;
      }
      ''
        mkdir -p $out
        for entry in $entries; do
          name=''${entry%%:*}
          path=''${entry#*:}

          if [ -d "$path/skills" ]; then
            for skill in "$path"/skills/*; do
              if [ -d "$skill" ]; then
                skill_name=$(basename "$skill")
                if [ ! -e "$out/$skill_name" ]; then
                  ln -s "$skill" "$out/$skill_name"
                fi
              fi
            done
          elif [ -f "$path/SKILL.md" ]; then
            if [ ! -e "$out/$name" ]; then
              ln -s "$path" "$out/$name"
            fi
          else
            find "$path" -maxdepth 2 -name SKILL.md | while read -r skill_md; do
              skill_dir=$(dirname "$skill_md")
              skill_name=$(basename "$skill_dir")
              if [ "$skill_dir" != "$path" ]; then
                if [ ! -e "$out/$skill_name" ]; then
                  ln -s "$skill_dir" "$out/$skill_name"
                fi
              fi
            done
          fi
        done
      '';
in
{
  options = {
    agents.mcp.enable = lib.mkEnableOption "Enable generic MCP configuration.";
    agents.mcp.servers = mcpServers;

    agents.skills.enable = lib.mkEnableOption "Enable agent skills configuration.";
    agents.skills.entries = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Agent skills to link. Each attribute name is the skill name and the value is a path or derivation to link.";
    };

    agents.claude.enable = lib.mkEnableOption "Enable Claude coding agent.";
    agents.claude.mcp.enable = lib.mkEnableOption "Enable Claude MCP configuration.";
    agents.claude.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Claude MCP servers configuration.";
    };
    agents.claude.linkSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to link agent skills for Claude.";
    };
    agents.claude.skillsDirectory = lib.mkOption {
      type = lib.types.str;
      default = ".claude/skills";
      description = "The directory where agent skills are linked for Claude.";
    };

    agents.copilot.enable = lib.mkEnableOption "Enable GitHub Copilot coding agent.";
    agents.copilot.mcp.enable = lib.mkEnableOption "Enable GitHub Copilot MCP configuration.";
    agents.copilot.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "GitHub Copilot MCP servers configuration.";
    };
    agents.copilot.linkSkills = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to link agent skills for GitHub Copilot.";
    };
    agents.copilot.skillsDirectory = lib.mkOption {
      type = lib.types.str;
      default = ".copilot/skills";
      description = "The directory where agent skills are linked for GitHub Copilot.";
    };

    agents.gemini.enable = lib.mkEnableOption "Enable gemini coding agent.";
    agents.gemini.mcp.enable = lib.mkEnableOption "Enable gemini MCP configuration.";
    agents.gemini.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Gemini MCP servers configuration.";
    };
    agents.gemini.linkSkills = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to link agent skills for Gemini.";
    };
    agents.gemini.skillsDirectory = lib.mkOption {
      type = lib.types.str;
      default = ".gemini/skills";
      description = "The directory where agent skills are linked for Gemini.";
    };

    agents.vscode.enable = lib.mkEnableOption "Enable VSCode Copilot coding agent.";
    agents.vscode.mcp.enable = lib.mkEnableOption "Enable VSCode Copilot MCP configuration.";
    agents.vscode.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "VSCode Copilot MCP servers configuration.";
    };
    agents.vscode.linkSkills = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to link agent skills for VSCode.";
    };
    agents.vscode.skillsDirectory = lib.mkOption {
      type = lib.types.str;
      default = ".vscode/skills";
      description = "The directory where agent skills are linked for VSCode.";
    };

    agents.opencode.enable = lib.mkEnableOption "Enable opencode coding agent.";
    agents.opencode.mcp.enable = lib.mkEnableOption "Enable opencode MCP configuration.";
    agents.opencode.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "opencode MCP servers configuration.";
    };
    agents.opencode.linkSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to link agent skills for opencode.";
    };
    agents.opencode.skillsDirectory = lib.mkOption {
      type = lib.types.str;
      default = ".opencode/skills";
      description = "The directory where agent skills are linked for opencode.";
    };

    agents.codex.enable = lib.mkEnableOption "Enable OpenAI Codex coding agent.";
    agents.codex.mcp.enable = lib.mkEnableOption "Enable OpenAI Codex MCP configuration.";
    agents.codex.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "OpenAI Codex MCP servers configuration.";
    };
    agents.codex.linkSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to link agent skills for OpenAI Codex.";
    };
    agents.codex.skillsDirectory = lib.mkOption {
      type = lib.types.str;
      default = ".codex/skills";
      description = "The directory where agent skills are linked for OpenAI Codex.";
    };
  };

  config = {
    tasks = {
      "mcp:setup" = lib.mkIf config.agents.mcp.enable (
        mkMergeTask "Setup generic coding agent configuration." "$DEVENV_ROOT/.agents/mcp_config.json" {
          mcpServers = config.agents.mcp.servers;
        }
      );
      "claude:setup" = lib.mkIf (config.agents.claude.enable && config.agents.claude.mcp.enable) (
        mkMergeTask "Setup Claude coding agent." "$DEVENV_ROOT/.mcp.json" config.agents.claude.mcp.servers
      );
      "copilot:setup" = lib.mkIf (config.agents.copilot.enable && config.agents.copilot.mcp.enable) (
        mkMergeTask "Setup GitHub Copilot coding agent." "$DEVENV_ROOT/.copilot/mcp-config.json"
          config.agents.copilot.mcp.servers
      );
      "vscode:setup" = lib.mkIf (config.agents.vscode.enable && config.agents.vscode.mcp.enable) (
        mkMergeTask "Setup VSCode Copilot coding agent." "$DEVENV_ROOT/.vscode/mcp.json"
          config.agents.vscode.mcp.servers
      );
      "gemini:setup" = lib.mkIf (config.agents.gemini.enable && config.agents.gemini.mcp.enable) (
        mkMergeTask "Setup Gemini coding agent." "$DEVENV_ROOT/.gemini/settings.json"
          config.agents.gemini.mcp.servers
      );
      "opencode:setup" = lib.mkIf (config.agents.opencode.enable && config.agents.opencode.mcp.enable) (
        mkMergeTask "Setup opencode coding agent." "$DEVENV_ROOT/opencode.json"
          config.agents.opencode.mcp.servers
      );
      "codex:setup" = lib.mkIf (config.agents.codex.enable && config.agents.codex.mcp.enable) (
        mkMergeTomlTask "Setup OpenAI Codex coding agent." "$DEVENV_ROOT/.codex/config.toml"
          config.agents.codex.mcp.servers
      );
      "skills:setup" = lib.mkIf config.agents.skills.enable {
        description = "Setup agent skills for the project.";
        exec = ''
          link_skills() {
            local target="$1"
            mkdir -p "$target"
            find "$target" -type l -exec rm -f {} +
            if [ -d "${assembled-skills}" ]; then
              for skill in "${assembled-skills}"/*; do
                if [ -e "$skill" ]; then
                  ln -sf "$skill" "$target/$(basename "$skill")"
                fi
              done
            fi
          }

          link_skills "$DEVENV_ROOT/.agents/skills"

          ${lib.optionalString (config.agents.claude.enable && config.agents.claude.linkSkills) ''
            link_skills "$DEVENV_ROOT/${config.agents.claude.skillsDirectory}"
          ''}
          ${lib.optionalString (config.agents.copilot.enable && config.agents.copilot.linkSkills) ''
            link_skills "$DEVENV_ROOT/${config.agents.copilot.skillsDirectory}"
          ''}
          ${lib.optionalString (config.agents.gemini.enable && config.agents.gemini.linkSkills) ''
            link_skills "$DEVENV_ROOT/${config.agents.gemini.skillsDirectory}"
          ''}
          ${lib.optionalString (config.agents.vscode.enable && config.agents.vscode.linkSkills) ''
            link_skills "$DEVENV_ROOT/${config.agents.vscode.skillsDirectory}"
          ''}
          ${lib.optionalString (config.agents.opencode.enable && config.agents.opencode.linkSkills) ''
            link_skills "$DEVENV_ROOT/${config.agents.opencode.skillsDirectory}"
          ''}
          ${lib.optionalString (config.agents.codex.enable && config.agents.codex.linkSkills) ''
            link_skills "$DEVENV_ROOT/${config.agents.codex.skillsDirectory}"
          ''}
        '';
        before = [ "devenv:enterShell" ];
      };
    };
  };
}
