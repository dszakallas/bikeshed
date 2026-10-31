{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;
  mcpUtils = import ../mcp-utils.nix { inherit lib; };
  callHarness = f: import f { inherit lib mcpUtils; };
in
{
  antigravity = callHarness ./antigravity.nix;
  claude = callHarness ./claude.nix;
  codex = callHarness ./codex.nix;
  copilot = callHarness ./copilot.nix;
  gemini = callHarness ./gemini.nix;
  opencode = callHarness ./opencode.nix;
  pi = callHarness ./pi.nix;
  vscode = callHarness ./vscode.nix;
}
