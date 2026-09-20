rec {
  description = "My personal Nix configuration";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };

  nixConfig = {
    extra-experimental-features = [
      "nix-command"
      "flakes"
      "configurable-impure-env"
    ];
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://devenv.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      ctx = (inputs // outputs);
      lib = import ./lib ctx;
      outputs =
        flake-utils.lib.eachDefaultSystem (system: {
          packages = (
            let
              pkgs = nixpkgs.legacyPackages.${system};
              packages = lib.callPackageWithRec (inputs // pkgs) ./pkgs;
            in
            packages
          );
        })
        // flake-utils.lib.eachDefaultSystemPassThrough (system: {
          inherit lib;
          systemModules = lib.importRec1 ./modules/system ctx;
          homeModules = lib.importRec1 ./modules/home ctx;
          devenvModules = lib.importRec1 ./modules/devenv ctx;
        });
    in
    outputs;
}
