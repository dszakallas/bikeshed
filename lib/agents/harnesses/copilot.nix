{ lib, ... }:
{
  description = "GitHub Copilot coding agent";

  mcpKey = "mcpServers";

  wrapMcpServers = servers: { mcpServers = servers; };

  transformMcpServerSpec =
    {
      name,
      cleanedServer,
      filtered,
      serverType,
      ...
    }:
    if serverType == "sse" then
      lib.warn "MCP server '${name}': sse transport is deprecated for GitHub Copilot." (
        builtins.removeAttrs (
          cleanedServer
          // {
            url = filtered.serverUrl;
            type = "sse";
            tools = [ "*" ];
          }
        ) [ "serverUrl" ]
      )
    else if serverType == "http" then
      builtins.removeAttrs (
        cleanedServer
        // {
          type = serverType;
          tools = [ "*" ];
          url = filtered.serverUrl;
        }
      ) [ "serverUrl" ]
    else
      cleanedServer
      // {
        type = serverType;
        tools = [ "*" ];
      };

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.github-copilot-cli;
    defaultUserDirectory = ".copilot";
    defaultMemoryFile = "copilot-instructions.md";
    defaultMcpTarget = ".copilot/mcp-config.json";
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".copilot/skills";
    defaultMcpTarget = ".copilot/mcp-config.json";
  };
}
