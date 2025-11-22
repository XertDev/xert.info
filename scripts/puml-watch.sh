#!/usr/bin/env bash
set -euo pipefail

# Watch all .puml files under content/posts and rebuild PNGs on change.

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
content_dir="$root_dir/content/posts"
build_script="$root_dir/scripts/puml-build.sh"

if ! command -v entr >/dev/null 2>&1; then
  echo "Error: entr not found in PATH. Enter nix develop (or direnv) to get it." >&2
  exit 1
fi

"$build_script"

# Collect .puml files to watch. If none, wait until they appear.
while true; do
  mapfile -t files < <(find "$content_dir" -type f -name "*.puml" | sort)
  if (( ${#files[@]} == 0 )); then
    echo "[PUML] No .puml files found. Watching for new files... (Ctrl+C to stop)"
    sleep 2
    continue
  fi
  printf '%s\n' "${files[@]}" | entr -cdr sh -c '"$0"' "$build_script"
  echo "[PUML] File set changed. Rebuilding watch list..."
  sleep 0.5
done
