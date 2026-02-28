#!/usr/bin/env bash
set -euo pipefail

BASE="https://myrient.erista.me/files/"
OUT_ALL="subfolders.txt"
OUT_BY_FOLDER="subfolders_by_folder.txt"

# Pull top-level folder URLs from local index.html
grep -oE 'href="[^"]+/"' index.html \
  | sed 's/^href="//; s/"$//' \
  | grep -vE '^\./$|^\.\./$|^/$' \
  | sed "s#^#$BASE#" \
  | sort -u > top_folders.txt

: > "$OUT_ALL"
: > "$OUT_BY_FOLDER"

while IFS= read -r folder_url; do
  echo "== $folder_url ==" >> "$OUT_BY_FOLDER"

  # Fetch folder page and extract immediate subfolder links.
  # Keep only relative links that end with '/'.
  curl -L -s "$folder_url" \
    | grep -oE 'href="[^"]+/"' \
    | sed 's/^href="//; s/"$//' \
    | grep -vE '^\./$|^\.\./$|^/$|^[a-z]+://|^#' \
    | sed "s#^#$folder_url#" \
    | sort -u > .tmp_sub.txt || true

  if [[ -s .tmp_sub.txt ]]; then
    cat .tmp_sub.txt >> "$OUT_ALL"
    cat .tmp_sub.txt >> "$OUT_BY_FOLDER"
  else
    echo "(no subfolders found or blocked)" >> "$OUT_BY_FOLDER"
  fi

  echo >> "$OUT_BY_FOLDER"
done < top_folders.txt

sort -u "$OUT_ALL" -o "$OUT_ALL"
rm -f .tmp_sub.txt

echo "Created:"
echo "  top_folders.txt"
echo "  $OUT_ALL"
echo "  $OUT_BY_FOLDER"
