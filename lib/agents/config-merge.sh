#!/usr/bin/env bash
target="$1"
ops="$2"

mkdir -p "$(dirname "$target")"

tmp=$(mktemp)
trap 'rm -f "$tmp" "$tmp.out"' EXIT

case "$target" in
*.toml)
  if [ -s "$target" ]; then yq -p toml -o json '.' "$target" >"$tmp"; else echo '{}' >"$tmp"; fi
  ;;
*)
  if [ -s "$target" ]; then cp "$target" "$tmp"; else echo '{}' >"$tmp"; fi
  ;;
esac

# Each op is {path: [..], value, strategy}. `replace` sets the value at the
# path; `merge` deep-merges objects and replaces anything else.
# shellcheck disable=SC2016
filter='reduce $ops_doc[0][] as $op (.;
  if $op.strategy == "merge" and (getpath($op.path) | type) == "object" and ($op.value | type) == "object"
  then setpath($op.path; getpath($op.path) * $op.value)
  else setpath($op.path; $op.value) end)'

jq --slurpfile ops_doc "$ops" "$filter" "$tmp" >"$tmp.out"
mv "$tmp.out" "$tmp"

case "$target" in
*.toml) yq -p json -o toml '.' "$tmp" >"$target" ;;
*) cp "$tmp" "$target" ;;
esac

chmod 600 "$target"
