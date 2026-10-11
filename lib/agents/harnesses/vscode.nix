{ ... }:
{
  description = "VSCode Copilot coding agent";

  mcpKey = "servers";

  wrapMcpServers = servers: { servers = servers; };

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
          type = serverType;
        }
      ) [ "serverUrl" ]
    else
      cleanedServer // { type = serverType; };

  homeConfiguration = null;

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".vscode/skills";
    defaultMcpTarget = ".vscode/mcp.json";
  };
}
