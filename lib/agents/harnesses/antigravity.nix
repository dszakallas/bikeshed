{
  lib,
  mcpUtils ? import ../mcp-utils.nix { inherit lib; },
  ...
}:
rec {
  description = "Antigravity coding agent";

  mcpServers =
    servers:
    let
      cleaned = mcpUtils.cleanMcpServers servers;
      formattedServers = lib.mapAttrs (name: server: server // { type = server.type; }) cleaned;
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
      target = if target != null then target else "${userDirectory}/mcp_config.json";
    };

  homeConfiguration = {
    defaultPackage = pkgs: null;
    defaultUserDirectory = ".gemini/antigravity-cli";
    defaultMemoryDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultLinkSkills = true;
    defaultSkillsDirectory = ".gemini/config/skills";
    defaultWrapper = {
      enable = false;
      executable = null;
      executableName = "agy";
      environment =
        { memoryDirectory, ... }:
        {
          GEMINI_HOME = memoryDirectory;
        };
    };
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".gemini/skills";
    defaultMcpTarget = null;
  };
}
