#!/usr/bin/env bash
set -euo pipefail

# Render all .puml files under content/posts into diagrams/<name>.png
# For each foo.puml located in a post bundle directory, we render to
# the sibling directory "diagrams/foo.png".

shopt -s nullglob

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
content_dir="$root_dir/content/posts"

if ! command -v plantuml >/dev/null 2>&1; then
  echo "Error: plantuml not found in PATH. Enter nix develop (or direnv) to get it." >&2
  exit 1
fi

if ! command -v dot >/dev/null 2>&1; then
  echo "Warning: graphviz 'dot' not found. Some diagrams may not render." >&2
fi

mapfile -t files < <(find "$content_dir" -type f -name "*.puml" | sort)

if (( ${#files[@]} == 0 )); then
  echo "No .puml files found under $content_dir"
  exit 0
fi

updated=0
for f in "${files[@]}"; do
  dir="$(dirname "$f")"
  base="$(basename "$f" .puml)"
  out_dir="$dir/diagrams"
  out_png="$out_dir/$base.png"
  mkdir -p "$out_dir"

  # Render only if missing or source is newer than the png
  if [[ ! -f "$out_png" || "$f" -nt "$out_png" ]]; then
    echo "[PUML] Rendering: $f -> $out_png"
    plantuml -tpng -o diagrams "$f"
    updated=$((updated+1))
  else
    echo "[PUML] Up-to-date: $out_png"
  fi

done

echo "[PUML] Done. Updated $updated file(s)."
