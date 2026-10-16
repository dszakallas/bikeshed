#!/usr/bin/env bash
# shellcheck disable=SC2154
set -euo pipefail

mkdir -p "$out"

root_dir="${sourceRoot:-${subDir:-}}"
if [ "${dontUnpack:-0}" = 1 ] || [ "${dontUnpack:-false}" = "true" ]; then
  if [ -n "$root_dir" ]; then
    search_dir="$src/$root_dir"
  else
    search_dir="$src"
  fi
else
  search_dir="."
fi

is_skill_included() {
  local skill_name="$1"
  local dir_name="$2"

  if [ "${includeAll:-false}" = "true" ]; then
    return 0
  fi

  # shellcheck disable=SC2086
  for item in ${includeList:-}; do
    if [ "$item" = "$skill_name" ] || [ "$item" = "$dir_name" ]; then
      return 0
    fi
  done

  return 1
}

is_skill_excluded() {
  local skill_name="$1"
  local dir_name="$2"

  # shellcheck disable=SC2086
  for item in ${excludeList:-}; do
    if [ "$item" = "$skill_name" ] || [ "$item" = "$dir_name" ]; then
      return 0
    fi
  done

  return 1
}

extract_frontmatter_name() {
  local file="$1"
  local fm_name

  fm_name=$(yq --front-matter=extract '.name // ""' "$file" 2>/dev/null || true)
  if [ "$fm_name" = "null" ]; then
    fm_name=""
  fi

  printf "%s" "$fm_name"
}

if [ "${preserveSourceRoot:-false}" = "true" ]; then
  cp -r "$search_dir"/. "$out/"
  chmod -R u+w "$out"

  if [ -f "$out/SKILL.md" ]; then
    skill_name="$pname"
    dir_name=$(basename "$search_dir")
    fm_name=$(extract_frontmatter_name "$out/SKILL.md")
    skill_name="${fm_name:-$skill_name}"

    if ! is_skill_included "$skill_name" "$dir_name" || is_skill_excluded "$skill_name" "$dir_name"; then
      find "$out" -mindepth 1 -delete
    fi
  else
    search_root="$out"
    if [ -d "$out/skills" ]; then
      search_root="$out/skills"
    fi

    while IFS= read -r -d '' skill_md; do
      skill_dir=$(dirname "$skill_md")
      if [ "$skill_dir" = "$search_root" ]; then
        continue
      fi

      dir_name=$(basename "$skill_dir")
      fm_name=$(extract_frontmatter_name "$skill_md")
      skill_name="${fm_name:-$dir_name}"

      if ! is_skill_included "$skill_name" "$dir_name" || is_skill_excluded "$skill_name" "$dir_name"; then
        rm -rf "$skill_dir"
      elif [ -n "$fm_name" ] && [ "$fm_name" != "$dir_name" ]; then
        parent_dir=$(dirname "$skill_dir")
        if [ ! -e "$parent_dir/$fm_name" ]; then
          mv "$skill_dir" "$parent_dir/$fm_name"
        fi
      fi
    done < <(find "$search_root" -name SKILL.md -print0)
  fi
elif [ -f "$search_dir/SKILL.md" ]; then
  skill_name="$pname"
  dir_name=$(basename "$search_dir")

  if is_skill_included "$skill_name" "$dir_name" && ! is_skill_excluded "$skill_name" "$dir_name"; then
    cp -r "$search_dir"/* "$out/"
  fi
else
  search_root="$search_dir"
  if [ -d "$search_dir/skills" ]; then
    search_root="$search_dir/skills"
  fi

  while IFS= read -r -d '' skill_md; do
    skill_dir=$(dirname "$skill_md")
    if [ "$skill_dir" = "$search_root" ]; then
      continue
    fi

    dir_name=$(basename "$skill_dir")
    fm_name=$(extract_frontmatter_name "$skill_md")
    skill_name="${fm_name:-$dir_name}"

    if is_skill_included "$skill_name" "$dir_name" && ! is_skill_excluded "$skill_name" "$dir_name"; then
      mkdir -p "$out/$skill_name"
      cp -r "$skill_dir"/* "$out/$skill_name/"
    fi
  done < <(find "$search_root" -name SKILL.md -print0)
fi
