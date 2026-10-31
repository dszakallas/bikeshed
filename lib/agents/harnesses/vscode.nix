{
  lib,
  mcpUtils ? import ../mcp-utils.nix { inherit lib; },
  ...
}:
rec {
  description = "VSCode Copilot coding agent";

  mcpServers =
    servers:
    let
      cleaned = mcpUtils.cleanMcpServers servers;
      formattedServers = lib.mapAttrs (
        name: server:
        if server.type == "http" || server.type == "sse" then
          builtins.removeAttrs (
            server
            // {
              url = server.serverUrl;
              type = server.type;
            }
          ) [ "serverUrl" ]
        else
          server // { type = server.type; }
      ) cleaned;
    in
    {
      servers = formattedServers;
    };

  formatMcpServers = mcpServers;

  mcpServer =
    {
      pkgs,
      strategy ? "merge",
      userDirectory,
      servers,
      target ? null,
    }:
    mcpUtils.mkJsonMergeScript {
      inherit pkgs strategy;
      managed = mcpServers servers;
      target = if target != null then target else "${userDirectory}/.vscode/mcp.json";
    };

  homeConfiguration = null;

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".vscode/skills";
    defaultMcpTarget = ".vscode/mcp.json";
  };
}
