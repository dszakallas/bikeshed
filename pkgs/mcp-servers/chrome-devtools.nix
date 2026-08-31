{ nodejs, writeShellScript }:
let
  # npx re-execs the package's bin script via its own `#!/usr/bin/env node`
  # shebang, so `node` must be resolvable on PATH even though npx itself is
  # invoked by absolute path. MCP hosts commonly spawn servers with a PATH
  # that lacks the nix store, so prepend nodejs's bin dir rather than
  # replacing PATH outright, which would clobber a PATH set up by whatever
  # launched the host (e.g. a CLI agent's shell environment).
  npx = writeShellScript "chrome-devtools-mcp-npx" ''
    export PATH="${nodejs}/bin:$PATH"
    exec "${nodejs}/bin/npx" "$@"
  '';
in
{
  type = "stdio";
  command = "${npx}";
  args = [
    "-y"
    "chrome-devtools-mcp@latest"
    "--no-usage-statistics"
    "--no-performance-crux"
  ];
  env = { };
}
