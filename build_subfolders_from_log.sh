#!/usr/bin/env bash
set -euo pipefail

LOG="/Users/dylanyoung/wget.log"
OUT_ALL="all_folder_urls_from_log.txt"
OUT_TOP="top_folders_from_log.txt"
OUT_SUB="subfolders_from_log.txt"
OUT_GROUPED="subfolders_by_top_folder.txt"

[[ -s "$LOG" ]] || { echo "Missing or empty $LOG"; exit 1; }

# 1) Extract all discovered URLs from wget.log.
awk '/^--[0-9]{4}-[0-9]{2}-[0-9]{2}/ {print $3} /^Location: / {print $2}' "$LOG" \
  | sed 's/\r$//' \
  | sed 's/[),.]$//' \
  | sed 's/[?#].*$//' \
  | grep '^https\?://.*/files/' \
  | grep '/$' \
  | sort -u > "$OUT_ALL"

# 2) Top-level folders are exactly /files/<name>/
grep -E '^https?://[^/]+/files/[^/]+/$' "$OUT_ALL" \
  | sort -u > "$OUT_TOP"

: > "$OUT_SUB"
: > "$OUT_GROUPED"

while IFS= read -r top; do
  echo "== $top ==" >> "$OUT_GROUPED"

  # Immediate subfolders only: /files/<top>/<sub>/
  grep -E "^${top//\//\/}[^/]+/$" "$OUT_ALL" > .tmp_subfolders || true

  if [[ -s .tmp_subfolders ]]; then
    cat .tmp_subfolders >> "$OUT_SUB"
    cat .tmp_subfolders >> "$OUT_GROUPED"
  else
    echo "(none found in log)" >> "$OUT_GROUPED"
  fi

  echo >> "$OUT_GROUPED"
done < "$OUT_TOP"

sort -u "$OUT_SUB" -o "$OUT_SUB"
rm -f .tmp_subfolders

echo "Created:"
echo "  $OUT_ALL"
echo "  $OUT_TOP"
echo "  $OUT_SUB"
echo "  $OUT_GROUPED"
