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
      agents.mcp = {
        enable = true;
        servers = mcpServers;
      };
      agents.vscode = {
        enable = true;
        mcp.enable = true;
        mcp.servers = lib'.agents.mcpServersForAgent "vscode" mcpServers;
      };
      agents.claude = {
        enable = true;
        mcp.enable = true;
        mcp.servers = lib'.agents.mcpServersForAgent "claude" mcpServers;
      };
      agents.copilot = {
        enable = true;
        mcp.enable = true;
        mcp.servers = lib'.agents.mcpServersForAgent "copilot" mcpServers;
      };
      agents.gemini = {
        enable = true;
        mcp.enable = true;
        mcp.servers = lib'.agents.mcpServersForAgent "gemini" mcpServers;
      };
      agents.opencode = {
        enable = true;
        mcp.enable = true;
        mcp.servers = lib'.agents.mcpServersForAgent "opencode" mcpServers;
      };
      agents.codex = {
        enable = true;
        mcp.enable = true;
        mcp.servers = lib'.agents.mcpServersForAgent "codex" mcpServers;
      };
    };
  };
}
