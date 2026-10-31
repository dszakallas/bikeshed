{ ... }@ctx:
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

  agentsLib = ctx.lib.agents;

  assembled-skills = agentsLib.assembleSkills pkgs config.bikeshed.agents.skills.entries;

  knownHarnessTypes = builtins.attrNames agentsLib.harnesses;

  mkHarnessModule =
    { name, config, ... }:
    let
      rawType = if config.type != null then config.type else name;
      harnessType =
        if agentsLib.harnesses ? ${rawType} then
          rawType
        else
          throw "Unknown harness type '${rawType}' for harness '${name}'. Known harness types: ${lib.concatStringsSep ", " knownHarnessTypes}";

      harnessDef = agentsLib.harnesses.${harnessType};

      homeConf =
        if harnessDef ? homeConfiguration && harnessDef.homeConfiguration != null then
          harnessDef.homeConfiguration
        else
          throw "Harness type '${harnessType}' does not support home configuration.";

      defaultUserDirectory =
        if homeConf ? defaultUserDirectory then
          (
            if name == harnessType then
              homeConf.defaultUserDirectory
            else
              lib.replaceStrings [ harnessType ] [ name ] homeConf.defaultUserDirectory
          )
        else
          ".config/${name}";

      defaultMemoryDirectory =
        if homeConf ? defaultMemoryDirectory then
          (
            if name == harnessType then
              homeConf.defaultMemoryDirectory
            else
              lib.replaceStrings [ harnessType ] [ name ] homeConf.defaultMemoryDirectory
          )
        else
          defaultUserDirectory;

      defaultSkillsDirectory =
        if homeConf ? defaultSkillsDirectory then
          (
            if name == harnessType then
              homeConf.defaultSkillsDirectory
            else
              lib.replaceStrings [ harnessType ] [ name ] homeConf.defaultSkillsDirectory
          )
        else
          "${defaultUserDirectory}/skills";

      defaultWrapper = homeConf.defaultWrapper or { };
    in
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = harnessType != null;
          description = "Whether to enable the ${name} agent harness.";
        };
        type = mkOption {
          type = types.nullOr types.str;
          default = null;
          apply =
            val:
            let
              resolved = if val != null then val else name;
            in
            if agentsLib.harnesses ? ${resolved} then
              val
            else
              throw "Unknown harness type '${resolved}' for harness '${name}'. Known harness types: ${lib.concatStringsSep ", " knownHarnessTypes}";
          description = "The harness type (e.g. opencode, pi, antigravity, claude, codex, copilot, gemini). If null, inferred from the instance name.";
        };
        package = mkOption {
          type = types.nullOr types.package;
          default =
            if homeConf ? defaultPackage then
              (
                if builtins.isFunction homeConf.defaultPackage then
                  homeConf.defaultPackage pkgs
                else
                  homeConf.defaultPackage
              )
            else
              null;
          description = "The package for the ${name} agent harness.";
        };
        userDirectory = mkOption {
          type = types.str;
          default = defaultUserDirectory;
          description = "The user directory for ${name} local files.";
        };
        linkSkills = mkOption {
          type = types.bool;
          default = homeConf.defaultLinkSkills or false;
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
            default = homeConf.defaultMemoryFile or "AGENTS.md";
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
            default = null;
            description = "Config file (relative to home) that ${name} MCP servers are merged into. If null, uses the harness default.";
          };
          servers = mkOption {
            type = types.attrs;
            default = { };
            description = "MCP servers to configure for ${name}.";
          };
        };
        wrapper = {
          enable = mkOption {
            type = types.bool;
            default = defaultWrapper.enable or false;
            description = "Whether to generate an executable wrapper for ${name}.";
          };
          executable = mkOption {
            type = types.nullOr (types.either types.str types.path);
            default = defaultWrapper.executable or null;
            description = "Exact path to the underlying executable to wrap when package is null.";
          };
          executableName = mkOption {
            type = types.str;
            default =
              if defaultWrapper ? executableName then
                (if name == harnessType then defaultWrapper.executableName else name)
              else
                name;
            description = "Name of the wrapper executable installed into PATH for ${name}.";
          };
          environment = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = "Additional environment variables to set in the wrapper executable for ${name}.";
          };
          initExtra = mkOption {
            type = types.lines;
            default = "";
            description = "Bash script segment to execute in the wrapper before running the wrapped executable for ${name}.";
          };
        };
      };
    };

  getWrapperPackage =
    name: cfg:
    let
      rawType = if cfg.type != null then cfg.type else name;
      harnessType =
        if agentsLib.harnesses ? ${rawType} then
          rawType
        else
          throw "Unknown harness type '${rawType}' for harness '${name}'. Known harness types: ${lib.concatStringsSep ", " knownHarnessTypes}";
      harnessDef = agentsLib.harnesses.${harnessType};
      homeConf = harnessDef.homeConfiguration;
      defaultWrapper = homeConf.defaultWrapper or { };
      binaryName = homeConf.binaryName or (defaultWrapper.executableName or harnessType);
      executableName = cfg.wrapper.executableName;

      defaultEnv =
        if defaultWrapper ? environment then
          (
            if builtins.isFunction defaultWrapper.environment then
              defaultWrapper.environment {
                userDirectory = "${config.home.homeDirectory}/${cfg.userDirectory}";
                memoryDirectory = "${config.home.homeDirectory}/${cfg.memory.directory}";
                inherit (config.home) homeDirectory;
              }
            else
              defaultWrapper.environment
          )
        else if homeConf ? environment then
          homeConf.environment {
            userDirectory = "${config.home.homeDirectory}/${cfg.userDirectory}";
            memoryDirectory = "${config.home.homeDirectory}/${cfg.memory.directory}";
            inherit (config.home) homeDirectory;
          }
        else
          { };

      allEnv = defaultEnv // cfg.wrapper.environment;

      defaultInitExtra =
        if defaultWrapper ? initExtra then
          (
            if builtins.isFunction defaultWrapper.initExtra then
              defaultWrapper.initExtra {
                userDirectory = "${config.home.homeDirectory}/${cfg.userDirectory}";
                memoryDirectory = "${config.home.homeDirectory}/${cfg.memory.directory}";
                inherit (config.home) homeDirectory;
              }
            else
              defaultWrapper.initExtra
          )
        else
          "";

      allInitExtra = lib.concatStringsSep "\n" (
        lib.filter (s: s != "") [
          defaultInitExtra
          cfg.wrapper.initExtra
        ]
      );

      exportLines = lib.concatStrings (
        lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}\n") allEnv
      );

      targetExecutable =
        if cfg.wrapper.executable != null then
          cfg.wrapper.executable
        else if cfg.package != null then
          "${cfg.package}/bin/${binaryName}"
        else
          throw "Harness '${name}' has package = null and wrapper.enable = true, but wrapper.executable is null. Please supply the exact path to the executable to wrap (e.g. wrapper.executable = \"/opt/homebrew/bin/${binaryName}\") or set wrapper.enable = false.";

      wrapperScript = pkgs.writeShellScript executableName ''
        set -eo pipefail

        ${exportLines}
        ${allInitExtra}

        exec ${lib.escapeShellArg targetExecutable} "$@"
      '';

      wrappedPackage = pkgs.runCommand "${executableName}-wrapper" { } ''
        mkdir -p $out/bin
        ln -s "${wrapperScript}" "$out/bin/${executableName}"
        ${lib.optionalString (cfg.package != null) ''
          if [ -d "${cfg.package}/share" ]; then
            ln -s "${cfg.package}/share" "$out/share"
          fi
        ''}
      '';
    in
    if !cfg.wrapper.enable then cfg.package else wrappedPackage;

in
{
  options.bikeshed.agents = {
    enable = mkEnableOption "AI agent tools";
    skills = {
      enable = mkEnableOption "agent skills";
      entries = mkOption {
        type = types.attrsOf types.path;
        default = { };
        description = "Agent skills to install into ~/.agents/skills/. Each attribute name is the skill name and the value is a path or derivation to link.";
      };
    };
    harnesses = mkOption {
      type = types.attrsOf (types.submodule mkHarnessModule);
      default = { };
      description = "AI agent harness instances.";
    };
  };

  config = mkIf config.bikeshed.agents.enable {
    home.packages = lib.concatLists (
      lib.mapAttrsToList (
        name: cfg:
        let
          pkg = getWrapperPackage name cfg;
        in
        if cfg.enable && pkg != null then [ pkg ] else [ ]
      ) config.bikeshed.agents.harnesses
    );

    home.file = mkMerge (
      (lib.mapAttrsToList (
        name: cfg:
        let
          pkg = getWrapperPackage name cfg;
        in
        if !cfg.enable then
          { }
        else
          mkMerge [
            (mkIf (cfg.wrapper.enable && pkg != null) {
              ".bikeshed/bin/${cfg.wrapper.executableName}".source = "${pkg}/bin/${cfg.wrapper.executableName}";
            })
            (mkIf (cfg.linkSkills && config.bikeshed.agents.skills.enable) {
              "${cfg.skillsDirectory}" = {
                source = assembled-skills;
                recursive = true;
              };
            })
            (mkIf (cfg.rules != { }) (
              lib.mapAttrs' (ruleName: rule: {
                name = "${cfg.userDirectory}/rules/${ruleName}";
                value = if rule.source != null then { source = rule.source; } else { text = rule.content; };
              }) (lib.filterAttrs (_: r: r.enable) cfg.rules)
            ))
            (mkIf cfg.memory.enable {
              "${config.home.homeDirectory}/${cfg.memory.directory}/${cfg.memory.target}" =
                if cfg.memory.source != null then
                  { source = cfg.memory.source; }
                else
                  { text = if cfg.memory.content != null then cfg.memory.content else ""; };
            })
          ]
      ) config.bikeshed.agents.harnesses)
      ++ [
        (mkIf config.bikeshed.agents.skills.enable {
          ".agents/skills" = {
            source = assembled-skills;
            recursive = true;
          };
        })
      ]
    );

    home.activation = mkMerge (
      lib.mapAttrsToList (
        name: cfg:
        let
          rawType = if cfg.type != null then cfg.type else name;
          harnessType =
            if agentsLib.harnesses ? ${rawType} then
              rawType
            else
              throw "Unknown harness type '${rawType}' for harness '${name}'. Known harness types: ${lib.concatStringsSep ", " knownHarnessTypes}";
          harnessDef = agentsLib.harnesses.${harnessType};
        in
        if
          cfg.enable && harnessDef ? mcpServer && harnessDef.mcpServer != null && cfg.mcp.servers != { }
        then
          {
            "${name}Mcp" = lib.hm.dag.entryAfter [ "writeBoundary" ] (
              harnessDef.mcpServer {
                inherit pkgs;
                inherit (cfg.mcp) strategy;
                userDirectory = "${config.home.homeDirectory}/${cfg.userDirectory}";
                target = if cfg.mcp.target != null then "${config.home.homeDirectory}/${cfg.mcp.target}" else null;
                servers = cfg.mcp.servers;
              }
            );
          }
        else
          { }
      ) config.bikeshed.agents.harnesses
    );
  };
}
