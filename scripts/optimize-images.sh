#!/usr/bin/env bash
# Convert jpg/jpeg/png images in a folder to WebP.
#
# Usage:
#   scripts/optimize-images.sh <folder> [-q QUALITY] [-r] [--delete-originals]
#
# Options:
#   -q QUALITY           WebP quality 0-100 (default: 80)
#   -r                    Recurse into subfolders (default: top-level only)
#   --delete-originals    Remove the source jpg/jpeg/png after a successful conversion
#
# Examples:
#   scripts/optimize-images.sh img
#   scripts/optimize-images.sh assets -q 85 -r --delete-originals

set -euo pipefail

QUALITY=80
RECURSIVE=0
DELETE_ORIGINALS=0
FOLDER=""

usage() {
  grep '^#' "$0" | cut -c3-
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -q)
      QUALITY="$2"
      shift 2
      ;;
    -r)
      RECURSIVE=1
      shift
      ;;
    --delete-originals)
      DELETE_ORIGINALS=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ -n "$FOLDER" ]]; then
        echo "Unexpected argument: $1" >&2
        usage
      fi
      FOLDER="$1"
      shift
      ;;
  esac
done

if [[ -z "$FOLDER" ]]; then
  echo "Error: folder argument is required." >&2
  usage
fi

if [[ ! -d "$FOLDER" ]]; then
  echo "Error: '$FOLDER' is not a directory." >&2
  exit 1
fi

if ! command -v cwebp >/dev/null 2>&1; then
  echo "Error: cwebp is not installed. Install it with 'brew install webp'." >&2
  exit 1
fi

if [[ "$RECURSIVE" -eq 1 ]]; then
  MAXDEPTH_ARGS=()
else
  MAXDEPTH_ARGS=(-maxdepth 1)
fi

total_before=0
total_after=0
count=0

while IFS= read -r -d '' file; do
  base="${file%.*}"
  out="${base}.webp"

  if [[ -e "$out" ]]; then
    echo "Skipping (already exists): $out"
    continue
  fi

  before=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
  cwebp -quiet -q "$QUALITY" "$file" -o "$out"
  after=$(stat -f%z "$out" 2>/dev/null || stat -c%s "$out")

  total_before=$((total_before + before))
  total_after=$((total_after + after))
  count=$((count + 1))

  printf '%s: %d -> %d bytes (%.0f%% smaller)\n' \
    "$file" "$before" "$after" "$(echo "scale=2; (1 - $after/$before) * 100" | bc)"

  if [[ "$DELETE_ORIGINALS" -eq 1 ]]; then
    rm "$file"
  fi
done < <(find "$FOLDER" "${MAXDEPTH_ARGS[@]}" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0)

if [[ "$count" -eq 0 ]]; then
  echo "No convertible images found in '$FOLDER'."
  exit 0
fi

echo "---"
echo "Converted $count image(s): $total_before -> $total_after bytes total"
