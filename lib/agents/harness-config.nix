{
  lib,
  harnesses,
  mcpServersType,
  mcpServersForAgent,
  assembleSkills,
}:
let
  inherit (lib) mkEnableOption mkOption types;

  jsonType = (pkgs: (pkgs.formats.json { }).type);

  # Harnesses that have a user-level (home) configuration.
  configurableHarnesses = lib.filterAttrs (
    _: h: h ? homeConfiguration && h.homeConfiguration != null
  ) harnesses;

  configurableNames = builtins.attrNames configurableHarnesses;

  homeConfigurationOf = harness: configurableHarnesses.${harness}.homeConfiguration;

  # Defaults declared relative to a harness' default user directory follow a
  # customised `userDirectory`, so `claude` and `claude-qwen` can live side by
  # side in different directories without redeclaring every path.
  rebase =
    hc: userDirectory: path:
    if path == hc.defaultUserDirectory then
      userDirectory
    else if path != null && lib.hasPrefix "${hc.defaultUserDirectory}/" path then
      userDirectory + lib.removePrefix hc.defaultUserDirectory path
    else
      path;

  # Option declarations for one harness instance. `name` is the instance name
  # (e.g. `claude-qwen`); `harness` selects which known harness it configures.
  harnessType =
    pkgs:
    types.submodule (
      { name, config, ... }:
      let
        hc = homeConfigurationOf config.harness;
        defaultPackage =
          if builtins.isFunction hc.defaultPackage then hc.defaultPackage pkgs else hc.defaultPackage or null;
      in
      {
        options = {
          harness = mkOption {
            type = types.enum configurableNames;
            default = name;
            description = "Which known agent harness this instance configures. Defaults to the instance name.";
          };
          enable = mkEnableOption "this agent harness instance";
          package = mkOption {
            type = types.nullOr types.package;
            default = defaultPackage;
            defaultText = lib.literalMD "the harness' default package";
            description = "The package for the agent.";
          };
          binary = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "The binary name to execute. Defaults to package.meta.mainProgram, or the harness name.";
          };
          env = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = "Additional environment variables to set in the harness wrapper script.";
          };
          wrapper = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to create a wrapper script for this harness instance.";
            };
            name = mkOption {
              type = types.str;
              default = name;
              description = "Name of the wrapper script executable. Defaults to the instance name.";
            };
            args = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional command line arguments to prepend in the wrapper script.";
            };
          };
          userDirectory = mkOption {
            type = types.str;
            default = hc.defaultUserDirectory;
            defaultText = lib.literalMD "the harness' default user directory, relative to home";
            description = "The user directory for local files, relative to home.";
          };
          linkSkills = mkOption {
            type = types.bool;
            default = hc.defaultLinkSkills or false;
            description = "Whether to link agent skills into the skills directory.";
          };
          skillsDirectory = mkOption {
            type = types.str;
            default = rebase hc config.userDirectory (
              hc.defaultSkillsDirectory or "${hc.defaultUserDirectory}/skills"
            );
            defaultText = lib.literalMD "`skills/` under the user directory";
            description = "The directory, relative to home, where agent skills are linked.";
          };
          memory = {
            enable = mkEnableOption "memory management";
            directory = mkOption {
              type = types.str;
              default = rebase hc config.userDirectory (hc.defaultMemoryDirectory or hc.defaultUserDirectory);
              defaultText = lib.literalMD "the user directory";
              description = "The directory, relative to home, for memory files.";
            };
            content = mkOption {
              type = types.nullOr types.lines;
              default = null;
              description = "Content of the main memory file.";
            };
            target = mkOption {
              type = types.str;
              default = hc.defaultMemoryFile;
              description = "File name of the main memory file inside the memory directory.";
            };
            source = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to the source file for the main memory file. Takes precedence over `content`.";
            };
          };
          mcp = {
            strategy = mkOption {
              type = types.enum [
                "replace"
                "merge"
              ];
              default = "merge";
              description = ''
                How MCP servers are combined with the existing config file:
                "replace" overwrites the managed top-level keys (e.g. mcpServers)
                wholesale, keeping sibling keys; "merge" additionally merges one level
                deeper, so individual servers are added or replaced while servers we
                don't manage are left untouched.
              '';
            };
            target = mkOption {
              type = types.nullOr types.str;
              default = rebase hc config.userDirectory (hc.defaultMcpTarget or null);
              defaultText = lib.literalMD "the harness' default MCP config file";
              description = "Config file, relative to home, that MCP servers are merged into.";
            };
            servers = mkOption {
              type = mcpServersType;
              default = { };
              description = ''
                Generic MCP server definitions. They are translated to the harness'
                native schema at build time with `mcpServersForAgent`.
              '';
            };
          };
          settings = {
            target = mkOption {
              type = types.nullOr types.str;
              default = rebase hc config.userDirectory (hc.defaultMcpTarget or null);
              defaultText = lib.literalMD "the harness' default config file";
              description = "Config file (JSON or TOML), relative to home, that `settings.entries` are applied to.";
            };
            entries = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    value = mkOption {
                      type = jsonType pkgs;
                      description = "The value to apply at the path.";
                    };
                    strategy = mkOption {
                      type = types.enum [
                        "replace"
                        "merge"
                      ];
                      default = "merge";
                      description = ''
                        "merge" deep-merges objects into the existing value and replaces
                        anything else; "replace" sets the value at the path.
                      '';
                    };
                  };
                }
              );
              default = { };
              example = lib.literalExpression ''
                {
                  provider.value.acme = { npm = "@ai-sdk/openai-compatible"; options.baseURL = "https://llm.example/v1"; };
                  "model".value = "acme/large";
                }
              '';
              description = ''
                Settings to apply to the config file, keyed by a dotted path expression
                (e.g. `provider` or `provider.acme.options`). Entries are applied in
                path order, so a parent path is applied before its children.
              '';
            };
          };
        };
      }
    );

  # Options shared by the home-manager module and the codebox image builder.
  agentsOptions = pkgs: {
    wrappersDirectory = mkOption {
      type = types.str;
      default = ".bikeshed/bin";
      description = "Directory relative to home where harness wrapper scripts are placed.";
    };
    init = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to run codebox-init on home-manager activation.";
      };
      overridesDir = mkOption {
        type = types.nullOr types.str;
        default = ".config/bikeshed/agents/init";
        description = "Directory (or colon-separated directories) containing unmanaged CodeboxInit overrides, relative to home or absolute.";
      };
    };
    skills = {
      enable = mkEnableOption "agent skills";
      entries = mkOption {
        type = types.attrsOf types.path;
        default = { };
        description = "Agent skills to install. Each attribute name is the skill name and the value is a path or derivation to link.";
      };
      directory = mkOption {
        type = types.str;
        default = ".agents/skills";
        description = "The directory, relative to home, where all skills are linked.";
      };
    };
    harnesses = mkOption {
      type = types.attrsOf (harnessType pkgs);
      default = { };
      description = ''
        Agent harness instances by name. The name selects the harness unless
        `harness` is set, so several instances (e.g. `claude` and `claude-qwen`)
        can configure the same harness.
      '';
    };
  };

  # Config merge operations for native-schema MCP servers: `replace` swaps each
  # top-level key (e.g. mcpServers) wholesale, `merge` replaces individual
  # servers so ones we don't manage stay.
  mcpOps =
    strategy: servers:
    if strategy == "merge" then
      lib.concatLists (
        lib.mapAttrsToList (
          key: byName:
          lib.mapAttrsToList (name: spec: {
            path = [
              key
              name
            ];
            value = spec;
            strategy = "replace";
          }) byName
        ) servers
      )
    else
      lib.mapAttrsToList (key: value: {
        path = [ key ];
        inherit value;
        strategy = "replace";
      }) servers;

  # Evaluated, build-time view of one harness instance. Both consumers derive
  # their output (home.file / activation, or the codebox init spec) from this.
  mkHarnessPlan =
    pkgs: cfg:
    let
      hc = homeConfigurationOf cfg.harness;
      nativeServers = mcpServersForAgent cfg.harness cfg.mcp.servers;
      binaryName =
        if cfg.binary != null then
          cfg.binary
        else if cfg.package != null then
          cfg.package.meta.mainProgram or cfg.harness
        else
          hc.defaultBinary or cfg.harness;
      binaryPath =
        if cfg.package != null && binaryName != null then
          "${cfg.package}/bin/${binaryName}"
        else
          binaryName;
      sessionVariables =
        lib.mapAttrs (
          _: lib.replaceStrings [ "$HOME/${hc.defaultUserDirectory}" ] [ "$HOME/${cfg.userDirectory}" ]
        ) (hc.sessionVariables or { })
        // cfg.env;
    in
    {
      packages = lib.optional (cfg.package != null) cfg.package;
      binary = binaryName;
      inherit binaryPath sessionVariables;
      memory =
        if cfg.memory.enable then
          {
            inherit (cfg.memory) directory target;
            source =
              if cfg.memory.source != null then
                cfg.memory.source
              else
                pkgs.writeText "${cfg.harness}-${baseNameOf cfg.memory.target}" (
                  if cfg.memory.content != null then cfg.memory.content else ""
                );
          }
        else
          null;
      mcp =
        if cfg.mcp.target != null && cfg.mcp.servers != { } then
          {
            inherit (cfg.mcp) target strategy;
            servers = nativeServers;
            ops = mcpOps cfg.mcp.strategy nativeServers;
          }
        else
          null;
      settings =
        if cfg.settings.target != null && cfg.settings.entries != { } then
          {
            inherit (cfg.settings) target;
            ops = lib.mapAttrsToList (path: e: {
              path = lib.splitString "." path;
              inherit (e) value strategy;
            }) cfg.settings.entries;
          }
        else
          null;
    };

  # Only harness settings are known at evaluation time; skill entries are
  # discovered by scanning the assembled skills (see mkBaseYaml).
  mkBaseSpec =
    pkgs: cfg:
    let
      plans = lib.mapAttrs (_: mkHarnessPlan pkgs) cfg.harnesses;
    in
    {
      apiVersion = "bikeshed.szakallas.net/v1alpha1";
      kind = "CodeboxInit";
      metadata.name = "base";
      spec = {
        inherit (cfg) wrappersDirectory;
        skills = { inherit (cfg.skills) enable directory; };
        harnesses = lib.mapAttrs (
          n: h:
          let
            plan = plans.${n};
          in
          {
            inherit (h) harness enable;
            inherit (h) userDirectory linkSkills skillsDirectory;
            wrapper = {
              inherit (h.wrapper) enable name args;
              binary = plan.binaryPath;
              sessionVariables = plan.sessionVariables;
            };
            memory = {
              inherit (h.memory) enable directory target;
            }
            // lib.optionalAttrs (plan.memory != null) { inherit (plan.memory) source; };
            settings = {
              entries = lib.mapAttrs (_: e: { inherit (e) value strategy; }) h.settings.entries;
            }
            // lib.optionalAttrs (h.settings.target != null) { inherit (h.settings) target; };
            mcp = {
              inherit (h.mcp) strategy;
            }
            // lib.optionalAttrs (h.mcp.target != null) { inherit (h.mcp) target; }
            // lib.optionalAttrs (plan.mcp != null) { inherit (plan.mcp) servers; };
          }
          // lib.optionalAttrs (plan.binary != null) { binary = plan.binary; }
        ) cfg.harnesses;
      };
    };

  mkBaseYaml =
    pkgs: cfg:
    let
      baseSpec = mkBaseSpec pkgs cfg;
      assembledSkills = assembleSkills pkgs cfg.skills.entries;
      skillsFragment =
        pkgs.runCommand "codebox-skills-init.yaml"
          {
            nativeBuildInputs = [
              pkgs.jq
              pkgs.yq-go
            ];
          }
          ''
            entries='{}'
            for skill in ${assembledSkills}/*; do
              [ -e "$skill" ] || continue
              entries=$(jq -c --arg n "$(basename "$skill")" --arg s "$(readlink -f "$skill")" \
                '. + {($n): {source: $s}}' <<<"$entries")
            done
            jq -n --argjson e "$entries" '{spec: {skills: {entries: $e}}}' | yq -p json -o yaml -P > $out
          '';
    in
    pkgs.runCommand "codebox-base.yaml"
      {
        nativeBuildInputs = [ pkgs.yq-go ];
        base = pkgs.writeText "codebox-base.json" (builtins.toJSON baseSpec);
      }
      ''
        # shellcheck disable=SC2016
        yq eval-all -p yaml -P '. as $i ireduce ({}; . * $i)' $base ${skillsFragment} > $out
      '';

  # Applies config merge operations to a harness config file (JSON or TOML) at
  # runtime. Usage: bikeshed-config-merge <target> <ops.json>
  mkConfigMerge =
    pkgs:
    pkgs.writeShellApplication {
      name = "bikeshed-config-merge";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.jq
        pkgs.yq-go
      ];
      text = builtins.readFile ./config-merge.sh;
    };

  # Applies the CodeboxInit documents to $HOME.
  mkCodeboxInit =
    pkgs: args:
    let
      actualArgs = if args == null then { } else args;
      baseSpec = actualArgs.baseSpec or null;
      overridesDir = actualArgs.overridesDir or null;
    in
    pkgs.writeShellApplication {
      name = "codebox-init";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.jq
        pkgs.yq-go
        (mkConfigMerge pkgs)
      ];
      runtimeEnv = lib.filterAttrs (_: v: v != null) {
        BIKESHED_AGENTS_BASE_SPEC = if baseSpec != null then toString baseSpec else null;
        BIKESHED_AGENTS_OVERRIDES_DIR = if overridesDir != null then toString overridesDir else null;
      };
      text = builtins.readFile ./codebox-init.sh;
    };
in
{
  inherit
    agentsOptions
    configurableHarnesses
    configurableNames
    harnessType
    homeConfigurationOf
    mkBaseSpec
    mkBaseYaml
    mkCodeboxInit
    mkHarnessPlan
    mkConfigMerge
    ;
}
