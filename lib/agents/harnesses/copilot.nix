{
  lib,
  mcpUtils ? import ../mcp-utils.nix { inherit lib; },
  ...
}:
rec {
  description = "GitHub Copilot coding agent";

  mcpServers =
    servers:
    let
      cleaned = mcpUtils.cleanMcpServers servers;
      formattedServers = lib.mapAttrs (
        name: server:
        if server.type == "sse" then
          lib.warn "MCP server '${name}': sse transport is deprecated for GitHub Copilot." (
            builtins.removeAttrs (
              server
              // {
                url = server.serverUrl;
                type = "sse";
                tools = [ "*" ];
              }
            ) [ "serverUrl" ]
          )
        else if server.type == "http" then
          builtins.removeAttrs (
            server
            // {
              type = server.type;
              tools = [ "*" ];
              url = server.serverUrl;
            }
          ) [ "serverUrl" ]
        else
          server
          // {
            type = server.type;
            tools = [ "*" ];
          }
      ) cleaned;
    in
    {
      mcpServers = formattedServers;
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
      target = if target != null then target else "${userDirectory}/mcp-config.json";
    };

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.github-copilot-cli;
    defaultUserDirectory = ".copilot";
    defaultMemoryFile = "copilot-instructions.md";
    defaultWrapper = {
      enable = false;
      executable = null;
      executableName = "copilot";
      environment =
        { userDirectory, ... }:
        {
          COPILOT_HOME = userDirectory;
        };
    };
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".copilot/skills";
    defaultMcpTarget = ".copilot/mcp-config.json";
  };
}
