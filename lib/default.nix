{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;
  text = import ./text.nix ctx;
  imports = import ./imports.nix ctx;
  agents = import ./agents ctx;
  git = import ./git.nix ctx;
in
text // imports // agents // git
