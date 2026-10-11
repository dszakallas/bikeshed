{ lib, ... }:
{
  description = "Codex coding agent";

  mcpKey = "mcp_servers";

  wrapMcpServers = servers: { mcp_servers = servers; };

  transformMcpServerSpec =
    {
      cleanedServer,
      filtered,
      serverType,
      ...
    }:
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
      cleanedServer;

  homeConfiguration = {
    defaultPackage = pkgs: null;
    defaultUserDirectory = ".codex";
    defaultMemoryFile = "AGENTS.md";
    defaultLinkSkills = true;
    defaultMcpTarget = ".codex/config.toml";
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".codex/skills";
    defaultMcpTarget = ".codex/config.toml";
    format = "toml";
  };
}
