{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;
  callHarness = f: import f { inherit lib; };
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
