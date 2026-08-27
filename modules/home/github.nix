{ ... }@ctx:
{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  moduleName = "davids-dotfiles-common/home/github";
in
{
  options = {
    bikeshed.github = {
      enable = mkEnableOption "GitHub configuration";
      ssh = {
        enable = mkEnableOption "Enable GitHub SSH configuration";
      };
      extensions = mkOption {
        type = types.listOf types.package;
        default = [ ];
        example = literalExpression "[ pkgs.gh-stack ]";
        description = ''
          gh CLI extensions to install. Each package must expose a
          `bin/gh-<name>` executable matching its `pname`.

          These are linked into gh's data directory, so gh reports them as
          local extensions: they carry no version and are not upgradable with
          `gh extension upgrade`. Because the directory is managed, extensions
          cannot be installed imperatively with `gh extension install`.
        '';
      };
    };
  };
  config = mkIf config.bikeshed.github.enable {
    programs.gh = {
      enable = true;
      inherit (config.bikeshed.github) extensions;
      # home-manager owns config.yml once programs.gh is enabled, which drops
      # the aliases gh writes into its own default config. Keep them.
      settings.aliases.co = "pr checkout";
    };
    programs.zsh = {
      oh-my-zsh.plugins = [ "gh" ];
    };
    home.sessionVariables = {
      GH_PAGER = "cat";
    };
    bikeshed.ssh.knownHostsLines = mkIf config.bikeshed.github.ssh.enable (
      ctx.lib.textRegion {
        name = moduleName;
        content = ''
          github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
          github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
          github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        '';
      }
    );
  };
}
