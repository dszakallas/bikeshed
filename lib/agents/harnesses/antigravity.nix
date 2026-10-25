{ ... }:
{
  description = "Antigravity coding agent";

  mcpKey = "mcpServers";

  wrapMcpServers = servers: { mcpServers = servers; };

  transformMcpServerSpec =
    {
      cleanedServer,
      serverType,
      ...
    }:
    cleanedServer // { type = serverType; };

  homeConfiguration = {
    defaultPackage = pkgs: null;
    defaultUserDirectory = ".gemini/antigravity-cli";
    defaultMemoryDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultLinkSkills = true;
    defaultSkillsDirectory = ".gemini/config/skills";
    defaultMcpTarget = ".gemini/antigravity-cli/mcp_config.json";
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".gemini/skills";
    defaultMcpTarget = null;
  };
}
