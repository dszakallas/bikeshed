{ lib, ... }:
{
  description = "OpenCode coding agent";

  mcpKey = "mcp";

  wrapMcpServers = servers: { mcp = servers; };

  # opencode uses its own schema: servers live under `mcp`, the transport
  # is `local`/`remote`, stdio command+args collapse into a single array,
  # and env vars are named `environment`.
  transformMcpServerSpec =
    {
      filtered,
      serverType,
      ...
    }:
    if serverType == "http" || serverType == "sse" then
      {
        type = "remote";
        url = filtered.serverUrl;
      }
      // lib.optionalAttrs (filtered ? headers) { inherit (filtered) headers; }
    else
      {
        type = "local";
        command = [ filtered.command ] ++ (filtered.args or [ ]);
      }
      // lib.optionalAttrs (filtered ? env) { environment = filtered.env; };

  homeConfiguration = {
    defaultPackage = pkgs: pkgs.opencode;
    defaultUserDirectory = ".config/opencode";
    defaultMemoryFile = "AGENTS.md";
    defaultLinkSkills = true;
    defaultMcpTarget = ".config/opencode/opencode.json";
  };

  projectConfiguration = {
    defaultLinkSkills = false;
    defaultSkillsDirectory = ".opencode/skills";
    defaultMcpTarget = "opencode.json";
  };
}
