{
  lib,
  mcpUtils ? import ../mcp-utils.nix { inherit lib; },
  ...
}:
rec {
  description = "Pi coding agent";

  mcpServers =
    servers:
    let
      cleaned = mcpUtils.cleanMcpServers servers;
      formattedServers = lib.mapAttrs (
        name: server:
        if server.type == "http" || server.type == "sse" then
          builtins.removeAttrs (server // { url = server.serverUrl; }) [
            "serverUrl"
            "type"
          ]
        else
          builtins.removeAttrs server [ "type" ]
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
      target = if target != null then target else "${userDirectory}/mcp.json";
    };

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.pi-coding-agent or null;
    defaultUserDirectory = ".pi/agent";
    defaultMemoryFile = "AGENTS.md";
    defaultLinkSkills = true;
    defaultWrapper = {
      enable = false;
      executable = null;
      executableName = "pi";
      environment =
        { userDirectory, ... }:
        {
          PI_CODING_AGENT_DIR = userDirectory;
        };
    };
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".pi/skills";
    defaultMcpTarget = ".pi/mcp.json";
  };
}
