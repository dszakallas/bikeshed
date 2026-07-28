{ ... }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    mkMerge
    ;

  assembled-skills =
    pkgs.runCommand "assembled-skills"
      {
        entries = lib.mapAttrsToList (name: path: "${name}:${path}") config.davids.agents.skills.entries;
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

  mkAgentModule =
    {
      name,
      defaultPackage,
      defaultUserDirectory,
      defaultMemoryDirectory ? defaultUserDirectory,
      defaultMemoryFile,
      defaultLinkSkills ? false,
      defaultSkillsDirectory ? "${defaultUserDirectory}/skills",
      defaultMcpTarget ? null,
      sessionVariables ? { },
    }:
    {
      options = {
        enable = mkEnableOption "${name} agent";
        package = mkOption {
          type = types.nullOr types.package;
          default = defaultPackage;
          description = "The package for the ${name} agent.";
        };
        userDirectory = mkOption {
          type = types.str;
          default = defaultUserDirectory;
          description = "The user directory for ${name} local files.";
        };
        linkSkills = mkOption {
          type = types.bool;
          default = defaultLinkSkills;
          description = "Whether to link agent skills into the ${name} user directory under skills/.";
        };
        skillsDirectory = mkOption {
          type = types.str;
          default = defaultSkillsDirectory;
          description = "The directory where agent skills are linked for ${name}.";
        };
        memory = {
          enable = mkEnableOption "memory management for ${name}";
          directory = mkOption {
            type = types.str;
            default = defaultMemoryDirectory;
            description = "The directory for ${name} memory files.";
          };
          content = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Content of the main memory file.";
          };
          target = mkOption {
            type = types.str;
            default = defaultMemoryFile;
            description = "Path to the target file for the main memory file.";
          };
          source = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the source file for the main memory file.";
          };
        };
        rules = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                enable = mkEnableOption "this rule file";
                content = mkOption {
                  type = types.lines;
                  default = "";
                  description = "Content of the rule file.";
                };
                source = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Source path for the rule file.";
                };
              };
            }
          );
          default = { };
          description = "Modular rule files for ${name}.";
        };
        mcp = {
          strategy = mkOption {
            type = types.enum [
              "replace"
              "merge"
            ];
            default = "merge";
            description = ''
              How ${name} MCP servers are combined with the existing config file:
              "replace" overwrites the managed top-level keys (e.g. mcpServers)
              wholesale, keeping sibling keys; "merge" additionally merges one level
              deeper, so individual servers are added or replaced while servers we
              don't manage are left untouched.
            '';
          };
          target = mkOption {
            type = types.nullOr types.str;
            default = defaultMcpTarget;
            description = "Config file (relative to home) that ${name} MCP servers are merged into.";
          };
          servers = mkOption {
            type = types.attrs;
            default = { };
            description = "Agent-shaped MCP servers object (as produced by mcpServersForAgent) merged into ${name}'s config file.";
          };
        };
      };

      config =
        let
          cfg = config.davids.agents.${name};
          memoryFile = "${config.home.homeDirectory}/${cfg.memory.directory}/${cfg.memory.target}";
        in
        mkIf cfg.enable (mkMerge [
          {
            home.packages = if cfg.package == null then [ ] else [ cfg.package ];
            home.sessionVariables = sessionVariables;
          }
          (mkIf (cfg.linkSkills && config.davids.agents.skills.enable) {
            home.file."${cfg.skillsDirectory}" = {
              source = assembled-skills;
              recursive = true;
            };
          })
          (mkIf (cfg.rules != { }) {
            home.file = lib.mapAttrs' (ruleName: rule: {
              name = "${cfg.userDirectory}/rules/${ruleName}";
              value = if rule.source != null then { source = rule.source; } else { text = rule.content; };
            }) (lib.filterAttrs (_: r: r.enable) cfg.rules);
          })
          (mkIf cfg.memory.enable {
            home.file."${memoryFile}" =
              if cfg.memory.source != null then
                { source = cfg.memory.source; }
              else
                { text = if cfg.memory.content != null then cfg.memory.content else ""; };
          })
          # User-level MCP servers are merged into the agent's own config file
          # (which the agent itself also writes to), so we can't symlink it from
          # the store. The `merge` strategy shallow-merges the top level and then
          # one level deeper, so servers a CLI added at user scope survive;
          # `replace` overwrites the managed top-level keys wholesale, mirroring
          # the devenv `jq -s '.[0] + .[1]'` merge. Gating on a non-empty servers
          # set keeps us from touching config files for agents we don't manage.
          (mkIf (cfg.mcp.target != null && cfg.mcp.servers != { }) (
            let
              managed = pkgs.writeText "${name}-mcp.json" (builtins.toJSON cfg.mcp.servers);
              # `replace`: managed top-level keys win, siblings kept.
              # `merge`: additionally merge object-valued keys one level deeper so
              # individual servers are added/replaced and unmanaged ones remain.
              jqFilter =
                if cfg.mcp.strategy == "merge" then
                  ''.[0] as $e | .[1] as $m | $e + $m + ([$m | keys[] | select(($e[.] | type) == "object" and ($m[.] | type) == "object") | {key: ., value: ($e[.] + $m[.])}] | from_entries)''
                else
                  ".[0] + .[1]";
              mergeScript = pkgs.writeShellScript "${name}-mcp-merge" ''
                set -eu
                target="$1"
                managed="$2"
                mkdir -p "$(dirname "$target")"
                [ -e "$target" ] || echo '{}' > "$target"
                ${pkgs.jq}/bin/jq -s ${lib.escapeShellArg jqFilter} "$target" "$managed" > "$target.tmp"
                mv "$target.tmp" "$target"
                chmod 600 "$target"
              '';
            in
            {
              home.activation."${name}Mcp" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run ${mergeScript} "${config.home.homeDirectory}/${cfg.mcp.target}" ${managed}
              '';
            }
          ))
        ]);
    };

  geminiModule = mkAgentModule {
    name = "gemini";
    defaultPackage = pkgs.gemini-cli;
    defaultUserDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultMcpTarget = ".gemini/settings.json";
  };

  claudeModule = mkAgentModule {
    name = "claude";
    defaultPackage = pkgs.claude-code;
    defaultUserDirectory = ".claude";
    defaultMemoryFile = "CLAUDE.md";
    defaultLinkSkills = true;
    # Config lives under CLAUDE_CONFIG_DIR (set below), not $HOME/.claude.json.
    defaultMcpTarget = ".claude/.claude.json";
    sessionVariables = {
      CLAUDE_CONFIG_DIR = "$HOME/.claude";
    };
  };

  copilotModule = mkAgentModule {
    name = "copilot";
    defaultPackage = pkgs.github-copilot-cli;
    defaultUserDirectory = ".copilot";
    defaultMemoryFile = "copilot-instructions.md";
    defaultMcpTarget = ".copilot/mcp-config.json";
  };

  antigravityModule = mkAgentModule {
    name = "antigravity";
    defaultPackage = null;
    defaultUserDirectory = ".gemini/antigravity-cli";
    defaultMemoryDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultLinkSkills = true;
    defaultMcpTarget = ".gemini/antigravity-cli/mcp_config.json";
  };

  opencodeModule = mkAgentModule {
    name = "opencode";
    defaultPackage = pkgs.opencode;
    defaultUserDirectory = ".config/opencode";
    defaultMemoryFile = "AGENTS.md";
    defaultLinkSkills = true;
    defaultMcpTarget = ".config/opencode/opencode.json";
  };
in
{
  options.davids.agents = {
    enable = mkEnableOption "AI agent tools";
    gemini = geminiModule.options;
    claude = claudeModule.options;
    copilot = copilotModule.options;
    antigravity = antigravityModule.options;
    opencode = opencodeModule.options;
    skills = {
      enable = mkEnableOption "agent skills";
      entries = mkOption {
        type = types.attrsOf types.path;
        default = { };
        description = "Agent skills to install into ~/.agents/skills/. Each attribute name is the skill name and the value is a path or derivation to link.";
      };
    };
  };

  config = mkIf config.davids.agents.enable (mkMerge [
    geminiModule.config
    claudeModule.config
    copilotModule.config
    antigravityModule.config
    opencodeModule.config
    (mkIf config.davids.agents.skills.enable {
      home.file.".agents/skills" = {
        source = assembled-skills;
        recursive = true;
      };
    })
    (mkIf (config.davids.agents.antigravity.enable && config.davids.agents.skills.enable) {
      home.file.".gemini/config/skills" = {
        source = assembled-skills;
        recursive = true;
      };
    })
  ]);
}
