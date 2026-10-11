{ ... }:
{
  description = "Claude coding agent";

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
          type = serverType;
        }
      ) [ "serverUrl" ]
    else
      cleanedServer // { type = serverType; };

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.claude-code;
    defaultUserDirectory = ".claude";
    defaultMemoryFile = "CLAUDE.md";
    defaultLinkSkills = true;
    # Config lives under CLAUDE_CONFIG_DIR (set below), not $HOME/.claude.json.
    defaultMcpTarget = ".claude/.claude.json";
    sessionVariables = {
      CLAUDE_CONFIG_DIR = "$HOME/.claude";
    };
  };

  projectConfiguration = {
    defaultLinkSkills = true;
    defaultSkillsDirectory = ".claude/skills";
    defaultMcpTarget = ".mcp.json";
  };
}
