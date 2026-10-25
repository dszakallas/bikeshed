{ config, nixpkgs, ... }@args:
let
  inherit (nixpkgs) lib;
  lib' = (import ./lib args);
  ctx = {
    lib = lib';
  };
  mcpServers = {
    "github" = {
      "type" = "http";
      "serverUrl" = "https://api.githubcopilot.com/mcp/";
    };
  };
in
{
  imports = (lib.attrsets.attrValues (lib'.importRec1 ./modules/devenv ctx));
  git-hooks.hooks = {
    markdownlint = {
      excludes = [
        "skills/.*"
      ];
    };
  };
  profiles = {
    "test-agents".module = {
      agents = {
        mcp = {
          enable = true;
          servers = mcpServers;
        };
      }
      // lib.genAttrs lib'.agents.popularHarnesses (name: {
        enable = true;
        mcp = {
          enable = true;
          servers = lib'.agents.mcpServersForAgent name mcpServers;
        };
      });
    };
  };
}
