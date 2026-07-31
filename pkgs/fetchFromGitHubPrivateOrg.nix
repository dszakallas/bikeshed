{ lib, fetchFromGitHub, ... }:
with lib;
args:
let
  varPrefix = args.varPrefix or strings.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] args.owner);
  private = args.private or true;
in
fetchFromGitHub ({ inherit varPrefix private; } // args)
