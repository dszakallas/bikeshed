{
  lib,
  mcpUtils ? import ../mcp-utils.nix { inherit lib; },
  ...
}:
rec {
  description = "Claude coding agent";

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
      target = if target != null then target else "${userDirectory}/.claude.json";
    };

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.claude-code;
    defaultUserDirectory = ".claude";
    defaultMemoryFile = "CLAUDE.md";
    defaultLinkSkills = true;
    defaultWrapper = {
      enable = true;
      executable = null;
      executableName = "claude";
      environment =
        { userDirectory, ... }:
        {
          # We need to set this so claude code searches for ~/.claude/.claude.json for its config file.
          CLAUDE_CONFIG_DIR = userDirectory;
        };
    };
  };

  projectConfiguration = {
    defaultLinkSkills = true;
    defaultSkillsDirectory = ".claude/skills";
    defaultMcpTarget = ".mcp.json";
  };
}
