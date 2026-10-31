{
  lib,
  mcpUtils ? import ../mcp-utils.nix { inherit lib; },
  ...
}:
rec {
  description = "Gemini coding agent";

  mcpServers =
    servers:
    let
      cleaned = mcpUtils.cleanMcpServers servers;
      formattedServers = lib.mapAttrs (
        name: server:
        if server.type == "http" then
          builtins.removeAttrs (server // { httpUrl = server.serverUrl; }) [
            "serverUrl"
            "type"
          ]
        else if server.type == "sse" then
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
      target = if target != null then target else "${userDirectory}/settings.json";
    };

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.gemini-cli;
    defaultUserDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultWrapper = {
      enable = false;
      executable = null;
      executableName = "gemini";
      environment =
        { userDirectory, ... }:
        {
          GEMINI_CONFIG_DIR = userDirectory;
        };
    };
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".gemini/skills";
    defaultMcpTarget = ".gemini/settings.json";
  };
}
