{
  lib,
  mcpUtils ? import ../mcp-utils.nix { inherit lib; },
  ...
}:
rec {
  description = "OpenCode coding agent";

  # opencode uses its own schema: servers live under `mcp`, the transport
  # is `local`/`remote`, stdio command+args collapse into a single array,
  # and env vars are named `environment`.
  mcpServers =
    servers:
    let
      cleaned = mcpUtils.cleanMcpServers servers;
      formattedServers = lib.mapAttrs (
        name: server:
        if server.type == "http" || server.type == "sse" then
          {
            type = "remote";
            url = server.serverUrl;
          }
          // lib.optionalAttrs (server ? headers) { inherit (server) headers; }
        else
          {
            type = "local";
            command = [ server.command ] ++ (server.args or [ ]);
          }
          // lib.optionalAttrs (server ? env) { environment = server.env; }
      ) cleaned;
    in
    {
      mcp = formattedServers;
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
      target = if target != null then target else "${userDirectory}/opencode.json";
    };

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.opencode;
    defaultUserDirectory = ".config/opencode";
    defaultMemoryFile = "AGENTS.md";
    defaultLinkSkills = true;
    defaultWrapper = {
      enable = false;
      executable = null;
      executableName = "opencode";
      environment =
        { userDirectory, ... }:
        {
          OPENCODE_CONFIG_DIR = userDirectory;
        };
    };
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".opencode/skills";
    defaultMcpTarget = "opencode.json";
  };
}
