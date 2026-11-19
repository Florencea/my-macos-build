#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
rea: Combine .ass subtitle into .mkv as default track and remove source directory
Usage: rea <input_dir>
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

INPUT_DIR="${1:-}"
if [[ -z "$INPUT_DIR" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Error: Directory $INPUT_DIR does not exist" >&2
  exit 1
fi

ABS_INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
if [[ -z "$ABS_INPUT_DIR" || "$ABS_INPUT_DIR" == "/" ]]; then
  echo "Error: Input directory cannot be root or empty" >&2
  exit 1
fi

INPUT_BASE="$(basename "$ABS_INPUT_DIR")"
PARENT_DIR="$(dirname "$ABS_INPUT_DIR")"

shopt -s nullglob
MKV_FILES=("$ABS_INPUT_DIR"/*.mkv)
ASS_FILES=("$ABS_INPUT_DIR"/*.ass)
shopt -u nullglob

if [[ ${#MKV_FILES[@]} -ne 1 ]]; then
  echo "Error: Expected exactly 1 .mkv file in $INPUT_DIR (found ${#MKV_FILES[@]})" >&2
  exit 1
fi

if [[ ${#ASS_FILES[@]} -eq 0 ]]; then
  echo "Error: No .ass subtitle file found in $INPUT_DIR" >&2
  exit 1
fi

SELECTED_ASS=""
for ass in "${ASS_FILES[@]}"; do
  if printf '%s' "$(basename "$ass")" | grep -iqE '(cht|tc|zh-tw)'; then
    SELECTED_ASS="$ass"
    break
  fi
done
[[ -n "$SELECTED_ASS" ]] || SELECTED_ASS="${ASS_FILES[0]}"

TMPFILE="${PARENT_DIR}/.tmp_rea_$$.mkv"
OUTPUT_FILE="${PARENT_DIR}/${INPUT_BASE}.mkv"
trap 'rm -f "${TMPFILE:-}"' EXIT

ffmpeg -y -hide_banner -loglevel error \
  -sn \
  -i "${MKV_FILES[0]}" \
  -i "$SELECTED_ASS" \
  -map 0:v:0 \
  -map "0:a:0?" \
  -map 1:s:0 \
  -c copy \
  -disposition:s:0 default \
  -metadata:s:s:0 language=chi \
  -metadata:s:s:0 title="繁體中文" \
  "$TMPFILE"

mv -f "$TMPFILE" "$OUTPUT_FILE"
rm -rf "${ABS_INPUT_DIR:?}"

SIZE="$(stat -f "%z" "$OUTPUT_FILE" | awk '{ if ($1 >= 1048576) printf "%.1fM", $1/1048576; else if ($1 >= 1024) printf "%.1fK", $1/1024; else printf "%dB", $1 }')"
printf "%s %s\n" "$(basename "$OUTPUT_FILE")" "$SIZE"
