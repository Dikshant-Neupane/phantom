#!/usr/bin/env bash
# Run `phantom check` over files and directories; exit non-zero if any file fails.
#
# Usage: scripts/ci_check.sh PATH [PATH...]
# Environment:
#   PHANTOM_STRICT   "true" (default) adds --strict (invisible / bidirectional characters)
#   PHANTOM_EXCLUDE  space-separated shell patterns of files to skip (matched against the path)
#   PHANTOM_ARGS     extra arguments for `phantom check`, e.g. "--deny cap.counters"
# Used by the composite GitHub Action in action.yml; also handy locally and in pre-commit.
set -uo pipefail

strict="${PHANTOM_STRICT:-true}"
exclude="${PHANTOM_EXCLUDE:-}"
extra="${PHANTOM_ARGS:-}"

if [ "$#" -eq 0 ]; then
  echo "usage: ci_check.sh PATH [PATH...]" >&2
  exit 2
fi

flags=()
if [ "$strict" = "true" ]; then
  flags+=(--strict)
fi
# shellcheck disable=SC2206  # intentional word splitting of PHANTOM_ARGS
flags+=($extra)

excluded() {
  local file="$1" pattern
  # shellcheck disable=SC2086  # intentional word splitting of the pattern list
  for pattern in $exclude; do
    # shellcheck disable=SC2053  # the pattern is meant to be a glob
    if [[ "$file" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

files=()
for path in "$@"; do
  if [ -d "$path" ]; then
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(find "$path" -type f -name '*.py' \
      -not -path '*/.*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*' \
      -not -path '*/venv/*' -not -path '*/.venv/*' -print0 | sort -z)
  elif [ -f "$path" ]; then
    files+=("$path")
  else
    echo "::error::path not found: $path" >&2
    exit 2
  fi
done

failed=0
checked=0
for file in "${files[@]}"; do
  if excluded "$file"; then
    continue
  fi
  checked=$((checked + 1))
  if ! phantom check "${flags[@]}" "$file"; then
    echo "::error file=$file::phantom check failed"
    failed=$((failed + 1))
  fi
done

echo "phantom: checked $checked file(s), $failed failed"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
