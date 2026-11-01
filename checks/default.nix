{ pkgs, lib }:
let
  init = lib.agents.mkCodeboxInit pkgs { };
  configMerge = lib.agents.mkConfigMerge pkgs;
in
{
  codebox-init =
    pkgs.runCommand "codebox-init-test"
      {
        nativeBuildInputs = [
          init
          configMerge
          pkgs.jq
          pkgs.yq-go
        ];
      }
      ''
        export HOME=$TMPDIR/home
        export CODEBOX_INIT_DIR=$TMPDIR/init
        mkdir -p $HOME $CODEBOX_INIT_DIR $TMPDIR/skill-a $TMPDIR/skill-b $TMPDIR/memory

        echo memory > $TMPDIR/memory/AGENTS.md

        cat > $CODEBOX_INIT_DIR/00-base.yaml <<YAML
        apiVersion: bikeshed.szakallas.net/v1alpha1
        kind: CodeboxInit
        spec:
          skills:
            enable: true
            directory: .agents/skills
            entries:
              skill-a: { source: $TMPDIR/skill-a }
          harnesses:
            opencode:
              enable: true
              userDirectory: .config/opencode
              linkSkills: true
              skillsDirectory: .config/opencode/skills
              memory:
                enable: true
                directory: .config/opencode
                target: AGENTS.md
                source: $TMPDIR/memory/AGENTS.md
              mcp:
                strategy: merge
                target: .config/opencode/opencode.json
                servers:
                  mcp:
                    one: { type: remote, url: "https://one.example" }
              settings:
                target: .config/opencode/opencode.json
                entries:
                  provider.acme:
                    value: { options: { baseURL: "https://llm.example/v1" } }
            codex:
              enable: false
              mcp:
                target: .codex/config.toml
                servers:
                  mcp_servers:
                    nope: { url: "https://nope.example" }
        YAML

        cat > $CODEBOX_INIT_DIR/10-user.yaml <<YAML
        apiVersion: bikeshed.szakallas.net/v1alpha1
        kind: CodeboxInit
        spec:
          skills:
            entries:
              skill-b: { source: $TMPDIR/skill-b }
          harnesses:
            opencode:
              mcp:
                servers:
                  mcp:
                    two: { type: remote, url: "https://two.example" }
              settings:
                entries:
                  provider.acme:
                    value: { options: { apiKey: secret }, npm: acme-sdk }
                  theme:
                    value: light
                    strategy: replace
            claude-qwen:
              enable: true
              harness: claude
              userDirectory: .claude-qwen
              linkSkills: true
              skillsDirectory: .claude-qwen/skills
              wrapper:
                sessionVariables:
                  CLAUDE_CONFIG_DIR: \$HOME/.claude-qwen
        YAML

        # pre-existing config written by the harness, and a stale link
        mkdir -p $HOME/.config/opencode/skills
        echo '{"mcp":{"cli":{"type":"local"}},"theme":"dark"}' > $HOME/.config/opencode/opencode.json
        ln -s /nonexistent $HOME/.config/opencode/skills/stale

        codebox-init
        codebox-init

        test -L $HOME/.agents/skills/skill-a
        test -L $HOME/.agents/skills/skill-b
        test -L $HOME/.config/opencode/skills/skill-b
        test -L $HOME/.claude-qwen/skills/skill-a
        test ! -e $HOME/.config/opencode/skills/stale
        test -L $HOME/.config/opencode/AGENTS.md
        test ! -e $HOME/.codex

        # Wrapper scripts
        test -x $HOME/.bikeshed/bin/opencode
        test -x $HOME/.bikeshed/bin/claude-qwen
        grep -q 'export CLAUDE_CONFIG_DIR="\$HOME/\.claude-qwen"' $HOME/.bikeshed/bin/claude-qwen

        jq -e '.theme == "light" and (.mcp | keys == ["cli","one","two"])
          and .provider.acme == {options: {baseURL: "https://llm.example/v1", apiKey: "secret"}, npm: "acme-sdk"}' \
          $HOME/.config/opencode/opencode.json

        # TOML target
        mkdir -p $TMPDIR/t
        printf '[mcp_servers.old]\nurl = "https://old.example"\n' > $TMPDIR/t/config.toml
        echo '[{"path":["mcp_servers","new"],"value":{"url":"https://new.example"},"strategy":"replace"}]' > $TMPDIR/t/ops.json
        bikeshed-config-merge $TMPDIR/t/config.toml $TMPDIR/t/ops.json
        yq -p toml -o json -e '.mcp_servers.old != null and .mcp_servers.new != null' $TMPDIR/t/config.toml

        # Test running with explicit base_spec and overrides_dir arguments
        export HOME=$TMPDIR/home2
        mkdir -p $HOME $TMPDIR/overrides
        cat > $TMPDIR/overrides/extra.yaml <<YAML
        apiVersion: bikeshed.szakallas.net/v1alpha1
        kind: CodeboxInit
        spec:
          harnesses:
            opencode:
              enable: true
        YAML
        codebox-init "$CODEBOX_INIT_DIR/00-base.yaml" "$TMPDIR/overrides"
        test -x $HOME/.bikeshed/bin/opencode
        test -L $HOME/.agents/skills/skill-a

        # wrong apiVersion is rejected
        sed -i 's#v1alpha1#v0#' $CODEBOX_INIT_DIR/10-user.yaml
        if codebox-init; then echo "expected failure" >&2; exit 1; fi

        touch $out
      '';
}
