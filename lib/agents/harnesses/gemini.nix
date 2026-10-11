{ ... }:
{
  description = "Gemini coding agent";

  mcpKey = "mcpServers";

  wrapMcpServers = servers: { mcpServers = servers; };

  transformMcpServerSpec =
    {
      cleanedServer,
      filtered,
      serverType,
      ...
    }:
    if serverType == "http" then
      builtins.removeAttrs (
        cleanedServer
        // {
          httpUrl = filtered.serverUrl;
        }
      ) [ "serverUrl" ]
    else if serverType == "sse" then
      builtins.removeAttrs (
        cleanedServer
        // {
          url = filtered.serverUrl;
        }
      ) [ "serverUrl" ]
    else
      cleanedServer;

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.gemini-cli;
    defaultUserDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultMcpTarget = ".gemini/settings.json";
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".gemini/skills";
    defaultMcpTarget = ".gemini/settings.json";
  };
}
