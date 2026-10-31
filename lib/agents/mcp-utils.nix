{ lib }:
rec {
  cleanMcpServers =
    servers:
    let
      # If servers is already wrapped in e.g. { mcpServers = { ... }; } or { mcp = { ... }; }
      unwrapped =
        if servers ? mcpServers then
          servers.mcpServers
        else if servers ? mcp_servers then
          servers.mcp_servers
        else if servers ? mcp then
          servers.mcp
        else if servers ? servers then
          servers.servers
        else
          servers;

      stdioFields = [
        "command"
        "args"
        "env"
      ];
      urlFields = [
        "serverUrl"
        "headers"
      ];
    in
    lib.mapAttrs (
      name: server:
      let
        serverType = server.type or (if server ? command then "stdio" else "http");

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

        filtered = lib.filterAttrs (_: v: v != null) validated;

        cleanedFields =
          if serverType == "stdio" then
            lib.filterAttrs (k: _: builtins.elem k stdioFields) filtered
          else
            lib.filterAttrs (k: _: builtins.elem k urlFields) filtered;
      in
      cleanedFields
      // {
        type = serverType;
      }
      // lib.optionalAttrs (filtered ? serverUrl) {
        inherit (filtered) serverUrl;
      }
      // lib.optionalAttrs (filtered ? headers) {
        inherit (filtered) headers;
      }
    ) unwrapped;

  mkJsonMergeScript =
    {
      pkgs,
      target,
      managed,
      strategy ? "merge",
    }:
    let
      jqFilter =
        if strategy == "merge" then
          ''.[0] as $e | .[1] as $m | $e + $m + ([$m | keys[] | select(($e[.] | type) == "object" and ($m[.] | type) == "object") | {key: ., value: ($e[.] + $m[.])}] | from_entries)''
        else
          ".[0] + .[1]";
      mergeScript = pkgs.writeShellScript "mcp-json-merge" ''
        set -eu
        target="$1"
        managed="$2"
        mkdir -p "$(dirname "$target")"
        [ -e "$target" ] || echo '{}' > "$target"
        ${pkgs.jq}/bin/jq -s ${lib.escapeShellArg jqFilter} "$target" "$managed" > "$target.tmp"
        mv "$target.tmp" "$target"
        chmod 600 "$target"
      '';
      managedJson = pkgs.writeText "mcp-managed.json" (builtins.toJSON managed);
    in
    ''
      run ${mergeScript} "${target}" ${managedJson}
    '';

  mkTomlMergeScript =
    {
      pkgs,
      target,
      managed,
      strategy ? "merge",
      mcpKey ? "mcp_servers",
    }:
    let
      yqFilter =
        if strategy == "merge" then
          ". as $item ireduce ({}; . * $item)"
        else
          "select(fileIndex == 0) as $orig | select(fileIndex == 1) as $managed | $orig * $managed | .${mcpKey} = $managed.${mcpKey}";
      mergeScript = pkgs.writeShellScript "mcp-toml-merge" ''
        set -eu
        target="$1"
        managed="$2"
        mkdir -p "$(dirname "$target")"
        managed_toml=$(mktemp)
        trap 'rm -f "$managed_toml"' EXIT
        ${pkgs.yq-go}/bin/yq -p json -o toml '.' "$managed" > "$managed_toml"
        if [ -s "$target" ]; then
          ${pkgs.yq-go}/bin/yq eval-all -p toml -o toml ${lib.escapeShellArg yqFilter} "$target" "$managed_toml" > "$target.tmp"
          mv "$target.tmp" "$target"
        else
          cp "$managed_toml" "$target"
        fi
        chmod 600 "$target"
      '';
      managedJson = pkgs.writeText "mcp-managed.json" (builtins.toJSON managed);
    in
    ''
      run ${mergeScript} "${target}" ${managedJson}
    '';
}
