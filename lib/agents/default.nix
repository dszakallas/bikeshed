{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;

  mcpServersForAgent =
    agent: value:
    let
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
        if agent == "gemini" then
          if serverType == "http" then
            builtins.removeAttrs (
              cleanedServer
              // {
                httpUrl = filtered.serverUrl;
              }
            ) [ "serverUrl" ]
          else if serverType == "sse" then
            builtins.removeAttrs (
              cleanedServer
              // {
                url = filtered.serverUrl;
              }
            ) [ "serverUrl" ]
          else
            cleanedServer
        else if agent == "antigravity" then
          cleanedServer // { type = serverType; }
        else if agent == "claude" then
          if serverType == "http" || serverType == "sse" then
            builtins.removeAttrs (
              cleanedServer
              // {
                url = filtered.serverUrl;
                type = serverType;
              }
            ) [ "serverUrl" ]
          else
            (cleanedServer // { type = serverType; })
        else if agent == "copilot" then
          if serverType == "sse" then
            lib.warn "MCP server '${name}': sse transport is deprecated for GitHub Copilot." (
              builtins.removeAttrs (
                cleanedServer
                // {
                  url = filtered.serverUrl;
                  type = "sse";
                  tools = [ "*" ];
                }
              ) [ "serverUrl" ]
            )
          else if serverType == "http" then
            builtins.removeAttrs (
              cleanedServer
              // {
                type = serverType;
                tools = [ "*" ];
                url = filtered.serverUrl;
              }
            ) [ "serverUrl" ]
          else
            cleanedServer
            // {
              type = serverType;
              tools = [ "*" ];
            }
        else if agent == "vscode" then
          if serverType == "http" || serverType == "sse" then
            builtins.removeAttrs (
              cleanedServer
              // {
                url = filtered.serverUrl;
                type = serverType;
              }
            ) [ "serverUrl" ]
          else
            (cleanedServer // { type = serverType; })
        else if agent == "opencode" then
          # opencode uses its own schema: servers live under `mcp`, the transport
          # is `local`/`remote`, stdio command+args collapse into a single array,
          # and env vars are named `environment`.
          if serverType == "http" || serverType == "sse" then
            {
              type = "remote";
              url = filtered.serverUrl;
            }
            // lib.optionalAttrs (filtered ? headers) { inherit (filtered) headers; }
          else
            {
              type = "local";
              command = [ filtered.command ] ++ (filtered.args or [ ]);
            }
            // lib.optionalAttrs (filtered ? env) { environment = filtered.env; }
        else if agent == "codex" then
          if serverType == "http" || serverType == "sse" then
            builtins.removeAttrs
              (
                cleanedServer
                // {
                  url = filtered.serverUrl;
                }
                // lib.optionalAttrs (filtered ? headers) {
                  http_headers = filtered.headers;
                }
              )
              [
                "serverUrl"
                "headers"
              ]
          else
            cleanedServer
        else
          cleanedServer // { type = serverType; }
      ) value;
    in
    if agent == "vscode" then
      { servers = formattedServers; }
    else if agent == "opencode" then
      { mcp = formattedServers; }
    else if agent == "codex" then
      { mcp_servers = formattedServers; }
    else
      { mcpServers = formattedServers; };

  memory = {
    avoidTropes = builtins.readFile ./avoid-tropes.md;
    disableAttributions = builtins.readFile ./disable-attributions.md;
  };

  mkSkill =
    { stdenvNoCC, yq-go, ... }:
    {
      name,
      version,
      src,
      subDir ? null,
      include ? null,
      exclude ? null,
    }@args:
    stdenvNoCC.mkDerivation {
      pname = name;
      inherit version src;

      nativeBuildInputs = [ yq-go ];

      subDir = if subDir == null then "" else subDir;
      includeAll = if include == null then "true" else "false";
      includeList = if include == null then [ ] else include;
      excludeList = if exclude == null then [ ] else exclude;

      dontBuild = true;

      installPhase = "bash ${./install-skill.sh}";
    };

in
{
  agents = {
    inherit mcpServersForAgent memory mkSkill;
  };
}
