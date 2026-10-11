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

  agentsLib = ctx.lib.agents;

  mcpServers = lib.mkOption {
    type = agentsLib.mcpServersType;
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
    agentsLib.assembleSkills pkgs config.agents.skills.entries;

  mkProjectAgentModule =
    {
      name,
      description ? "${name} coding agent",
      defaultLinkSkills ? false,
      defaultSkillsDirectory ? ".${name}/skills",
      defaultMcpTarget ? null,
      format ? (if lib.hasSuffix ".toml" (if defaultMcpTarget != null then defaultMcpTarget else "") then "toml" else "json"),
    }:
    let
      cfg = config.agents.${name};
      taskFn = if format == "toml" then mkMergeTomlTask else mkMergeTask;
    in
    {
      options = {
        enable = lib.mkEnableOption "Enable ${description}.";
        mcp = {
          enable = lib.mkEnableOption "Enable ${description} MCP configuration.";
          servers = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "${description} MCP servers configuration.";
          };
        };
        linkSkills = lib.mkOption {
          type = lib.types.bool;
          default = defaultLinkSkills;
          description = "Whether to link agent skills for ${description}.";
        };
        skillsDirectory = lib.mkOption {
          type = lib.types.str;
          default = defaultSkillsDirectory;
          description = "The directory where agent skills are linked for ${description}.";
        };
      };

      task =
        if defaultMcpTarget != null then
          lib.mkIf (cfg.enable && cfg.mcp.enable) (
            taskFn "Setup ${description}." "$DEVENV_ROOT/${defaultMcpTarget}" cfg.mcp.servers
          )
        else
          null;

      skillLink = lib.optionalString (cfg.enable && cfg.linkSkills) ''
        link_skills "$DEVENV_ROOT/${cfg.skillsDirectory}"
      '';
    };

  projectAgents = lib.filterAttrs (
    _: h: h ? projectConfiguration && h.projectConfiguration != null
  ) agentsLib.harnesses;

  agentModules = lib.mapAttrs (
    name: harness:
    mkProjectAgentModule (
      {
        inherit name;
        description = harness.description or "${name} coding agent";
      }
      // harness.projectConfiguration
    )
  ) projectAgents;
in
{
  options = {
    agents = {
      mcp = {
        enable = lib.mkEnableOption "Enable generic MCP configuration.";
        servers = mcpServers;
      };

      skills = {
        enable = lib.mkEnableOption "Enable agent skills configuration.";
        entries = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = "Agent skills to link. Each attribute name is the skill name and the value is a path or derivation to link.";
        };
      };
    } // (lib.mapAttrs (_: m: m.options) agentModules);
  };

  config = {
    tasks = {
      "mcp:setup" = lib.mkIf config.agents.mcp.enable (
        mkMergeTask "Setup generic coding agent configuration." "$DEVENV_ROOT/.agents/mcp_config.json" {
          mcpServers = config.agents.mcp.servers;
        }
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

          ${lib.concatStrings (lib.mapAttrsToList (_: m: m.skillLink) agentModules)}
        '';
        before = [ "devenv:enterShell" ];
      };
    } // (lib.mapAttrs' (name: m: lib.nameValuePair "${name}:setup" m.task) (lib.filterAttrs (_: m: m.task != null) agentModules));
  };
}
