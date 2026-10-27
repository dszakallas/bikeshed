{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;

  harnesses = import ./harnesses ctx;

  defaultHarness = {
    description = null;
    mcpKey = "mcpServers";
    wrapMcpServers = servers: { mcpServers = servers; };
    transformMcpServerSpec =
      {
        cleanedServer,
        serverType,
        ...
      }:
      cleanedServer // { type = serverType; };
    homeConfiguration = null;
    projectConfiguration = null;
  };

  mcpServersForAgent =
    agent: value:
    let
      harness = harnesses.${agent} or defaultHarness;

      formattedServers = lib.mapAttrs (
        name: server:
        let
          serverType = server.type;

          # Validate mutually exclusive fields
          stdioFields = [
            "command"
            "args"
            "env"
          ];
          urlFields = [
            "serverUrl"
            "headers"
          ];

          hasStdioField = builtins.any (field: server.${field} or null != null) stdioFields;
          hasUrlField = builtins.any (field: server.${field} or null != null) urlFields;

          validated =
            if serverType == "stdio" && hasUrlField then
              throw "MCP server '${name}': stdio type cannot have 'serverUrl' or 'headers' fields"
            else if (serverType == "http" || serverType == "sse") && hasStdioField then
              throw "MCP server '${name}': ${serverType} type cannot have 'command', 'args', or 'env' fields"
            else if (serverType == "http" || serverType == "sse") && server.serverUrl or null == null then
              throw "MCP server '${name}': ${serverType} type must have 'serverUrl'"
            else if serverType == "stdio" && server.command or null == null then
              throw "MCP server '${name}': stdio type must have 'command'"
            else if serverType == "stdio" && server.args or null == null then
              server // { args = [ ]; }
            else
              server;

          # Filter out null values
          filtered = lib.filterAttrs (_: v: v != null) validated;

          cleanedServer =
            if serverType == "stdio" then
              lib.filterAttrs (k: _: builtins.elem k stdioFields) filtered
            else
              lib.filterAttrs (k: _: builtins.elem k urlFields) filtered;
        in
        harness.transformMcpServerSpec {
          inherit
            name
            server
            serverType
            cleanedServer
            filtered
            ;
        }
      ) value;
    in
    harness.wrapMcpServers formattedServers;

  memory = {
    avoidTropes = builtins.readFile ./memory/avoid-tropes.md;
    codingWorkflow = builtins.readFile ./memory/coding-workflow.md;
    audiences = builtins.readFile ./memory/audiences.md;
    machineUse = builtins.readFile ./memory/machine-use.md;
  };

  mkSkill =
    { stdenvNoCC, yq-go, ... }:
    {
      name,
      version,
      src,
      sourceRoot ? subDir,
      subDir ? null,
      include ? null,
      exclude ? null,
      preserveSourceRoot ? false,
      nativeBuildInputs ? [ ],
      buildPhase ? null,
      dontBuild ? (buildPhase == null),
      dontUnpack ? (buildPhase == null && pnpmDeps == null),
      pnpmDeps ? null,
      ...
    }@args:
    let
      resolvedSourceRoot = if sourceRoot == null then "" else sourceRoot;
      extraAttrs = removeAttrs args [
        "name"
        "version"
        "src"
        "sourceRoot"
        "subDir"
        "include"
        "exclude"
        "preserveSourceRoot"
        "nativeBuildInputs"
        "buildPhase"
        "dontBuild"
        "dontUnpack"
        "pnpmDeps"
      ];
      drv = stdenvNoCC.mkDerivation (
        extraAttrs
        // {
          pname = name;
          inherit version src;

          nativeBuildInputs = [ yq-go ] ++ nativeBuildInputs;

          sourceRoot = resolvedSourceRoot;
          preserveSourceRoot = if preserveSourceRoot then "true" else "false";
          includeAll = if include == null then "true" else "false";
          includeList = if include == null then [ ] else include;
          excludeList = if exclude == null then [ ] else exclude;

          inherit dontUnpack dontBuild;

          installPhase = "bash ${./install-skill.sh}";
        }
        // lib.optionalAttrs (buildPhase != null) { inherit buildPhase; }
        // lib.optionalAttrs (pnpmDeps != null) { inherit pnpmDeps; }
      );
    in
    if subDir != null then
      lib.warn "agents.mkSkill: 'subDir' is deprecated and will be removed in a future release; use 'sourceRoot' instead." drv
    else
      drv;

  assembleSkillsText = ''
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

  assembleSkills =
    { runCommand, ... }:
    entries:
    let
      formattedEntries =
        if builtins.isAttrs entries then
          lib.mapAttrsToList (name: path: "${name}:${path}") entries
        else
          entries;
    in
    runCommand "assembled-skills" {
      entries = formattedEntries;
    } assembleSkillsText;

  assembledSkills = assembleSkills;

  popularHarnesses = builtins.attrNames harnesses;

  allHarnesses = popularHarnesses;

  mcpServerType = lib.types.submodule {
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
  };

  mcpServersType = lib.types.attrsOf mcpServerType;
in
{
  agents = {
    inherit
      allHarnesses
      assembleSkills
      assembledSkills
      assembleSkillsText
      harnesses
      mcpServerType
      mcpServersType
      mcpServersForAgent
      memory
      mkSkill
      popularHarnesses
      ;
  };
}
