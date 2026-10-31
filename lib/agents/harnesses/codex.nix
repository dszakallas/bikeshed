{
  lib,
  mcpUtils ? import ../mcp-utils.nix { inherit lib; },
  ...
}:
rec {
  description = "Codex coding agent";

  mcpServers =
    servers:
    let
      cleaned = mcpUtils.cleanMcpServers servers;
      formattedServers = lib.mapAttrs (
        name: server:
        if server.type == "http" || server.type == "sse" then
          builtins.removeAttrs
            (
              server
              // {
                url = server.serverUrl;
              }
              // lib.optionalAttrs (server ? headers) {
                http_headers = server.headers;
              }
            )
            [
              "serverUrl"
              "type"
            ]
        else
          builtins.removeAttrs server [ "type" ]
      ) cleaned;
    in
    {
      mcp_servers = formattedServers;
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
    mcpUtils.mkTomlMergeScript {
      inherit pkgs strategy;
      managed = mcpServers servers;
      target = if target != null then target else "${userDirectory}/config.toml";
      mcpKey = "mcp_servers";
    };

  homeConfiguration = {
    defaultPackage = pkgs: null;
    defaultUserDirectory = ".codex";
    defaultMemoryFile = "AGENTS.md";
    defaultLinkSkills = true;
    defaultWrapper = {
      enable = false;
      executable = null;
      executableName = "codex";
      environment =
        { userDirectory, ... }:
        {
          CODEX_HOME = userDirectory;
        };
    };
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".codex/skills";
    defaultMcpTarget = ".codex/config.toml";
    format = "toml";
  };
}
