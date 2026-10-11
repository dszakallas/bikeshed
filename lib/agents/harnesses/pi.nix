{ ... }:
{
  description = "Pi coding agent";

  mcpKey = "mcpServers";

  wrapMcpServers = servers: { mcpServers = servers; };

  transformMcpServerSpec =
    {
      cleanedServer,
      filtered,
      serverType,
      ...
    }:
    if serverType == "http" || serverType == "sse" then
      builtins.removeAttrs (
        cleanedServer
        // {
          url = filtered.serverUrl;
        }
      ) [ "serverUrl" ]
    else
      cleanedServer;

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.pi-coding-agent or null;
    defaultUserDirectory = ".pi/agent";
    defaultMemoryFile = "AGENTS.md";
    defaultLinkSkills = true;
    defaultMcpTarget = ".pi/agent/mcp.json";
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".pi/skills";
    defaultMcpTarget = ".pi/mcp.json";
  };
}
