{ self, packages, ... }@ctx:
{
  config,
  hostPlatform,
  lib,
  options,
  pkgs,
  system,
  ...
}:
let
  inherit (lib)
    flatten
    optionals
    ;
  unmanagedFile =
    f:
    ctx.lib.textRegion {
      name = moduleName;
      content = ''
        # Unmanaged local overrides
        [[ -s "$HOME/.local/share/${f}" ]] && source "$HOME/.local/share/${f}"
      '';
    };
  files = with pkgs; [
    age
    age-plugin-yubikey
    bat
    findutils
    fswatch
    gawk
    gnused
    gnumake
    ripgrep
    rsync
    ssh-to-age
    sops
    tree
    zstd
  ];
  adm = with pkgs; [
    btop
    dig
    htop
    ncdu
    nmap
    tmux
  ];
  dev = with pkgs; [
    delta
    jq
    yq-go
  ];
  moduleName = "bikeshed/home/base";
in
{
  imports = [
    (import ./denv.nix ctx)
    (import ./fzf.nix ctx)
    (import ./git.nix ctx)
    (import ./k8s.nix ctx)
    (import ./go.nix ctx)
    (import ./python.nix ctx)
  ]
  ++ (optionals hostPlatform.isDarwin [ (import ./darwin.nix ctx) ]);

  config = {
    home = {
      packages = flatten [
        adm
        files
        dev
      ];
      file.".vimrc".text = ctx.lib.textRegion {
        name = moduleName;
        comment-char = ''"'';
        content = builtins.readFile ./vimrc;
      };
      # in some shell scripts, alias doesn't work, so we use a wrapper script
      file.".bikeshed/bin/docker" = {
        text = ''
          #!/bin/sh
          exec podman "$@"
        '';
        executable = true;
      };
      sessionVariables = {
        EDITOR = "vim";
        LANG = "en_US.UTF-8";
      };
      shellAliases = {
        la = "ls -la";
        v = "vim";
        docker = "podman";
      };
    };
    programs = {
      vim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [
          vim-airline
          vim-fugitive
          vim-surround
          nerdcommenter
          ctrlp-vim
          syntastic
          srcery-vim
          editorconfig-vim
          tagbar
        ];
        settings = {
          ignorecase = true;
        };
      };

      bash = {
        enable = true;
        bashrcExtra = unmanagedFile "bashrc";
        profileExtra = ''
          export PATH="$HOME/.bikeshed/bin:$PATH"
          # Unmanaged executables
          export PATH="$HOME/.local/bin:$PATH"
        ''
        + unmanagedFile "env";
      };

      zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        history = {
          path = "$HOME/.histfile";
        };

        initContent = unmanagedFile "zshrc";
        envExtra = ''
          export PATH="$HOME/.bikeshed/bin:$PATH"
          # Unmanaged executables
          export PATH="$HOME/.local/bin:$PATH"
        ''
        + unmanagedFile "env";

        oh-my-zsh = {
          enable = true;
          theme = "fino-time";
        };
      };
    };
  };
}
