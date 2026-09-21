#!/bin/zsh
set -o errexit
set -o nounset
set -o pipefail

# Description: ASS-Combiner: combine .cht.ass into original mkv as default subtitle track, move up, and clean up directory
# Usage: rea [input_dir]
# Example: rea 'input'

# 1. Parse arguments
INPUT_DIR="${1:-}"
if [[ -z "$INPUT_DIR" ]]; then
  echo "rea: ASS-Combiner: combine .cht.ass into original mkv as default subtitle track, move up, and clean up directory" >&2
  echo "Usage: rea [input_dir]" >&2
  echo "       rea 'input'" >&2
  exit 1
fi

# 2. Check required tools
for cmd in ffmpeg; do
  command -v "$cmd" &>/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

# 3. Validate input directory
[[ -d "$INPUT_DIR" ]] || {
  echo "Error: Directory $INPUT_DIR does not exist" >&2
  exit 1
}

INPUT_BASE="${INPUT_DIR:t}"
ABS_INPUT_DIR="${INPUT_DIR:A}"
PARENT_DIR="${ABS_INPUT_DIR:h}"

# Safety guard: prevent deleting root or empty paths
if [[ "$ABS_INPUT_DIR" == "/" || -z "$ABS_INPUT_DIR" ]]; then
  echo "Error: Input directory cannot be root or empty" >&2
  exit 1
fi

# 4. Locate media and subtitle files
local -a MKV_FILES ASS_FILES
MKV_FILES=("$ABS_INPUT_DIR"/*.mkv(N))
ASS_FILES=(
  "$ABS_INPUT_DIR"/*[Cc][Hh][Tt]*.ass(N)
  "$ABS_INPUT_DIR"/*[Tt][Cc]*.ass(N)
  "$ABS_INPUT_DIR"/*[Zh][Hh]-[Tt][Ww]*.ass(N)
)
if (($#ASS_FILES == 0)); then
  ASS_FILES=("$ABS_INPUT_DIR"/*.ass(N))
fi

if (($#MKV_FILES == 0)); then
  echo "Error: No .mkv file found in $INPUT_DIR" >&2
  exit 1
fi
if (($#ASS_FILES == 0)); then
  echo "Error: No .ass subtitle file found in $INPUT_DIR" >&2
  exit 1
fi

INPUT_FILE="${MKV_FILES[1]}"
INPUT_ASS_TW="${ASS_FILES[1]}"

# 5. Mux subtitle and clean up
TMPFILE="${PARENT_DIR}/.tmp_${0:t:r}_$$.mkv"
OUTPUT_FILE="${PARENT_DIR}/${INPUT_BASE}.mkv"
trap 'rm -f "$TMPFILE"' EXIT

# Mux .cht.ass into mkv as the sole default subtitle track (stripping original subtitles and cover art video streams)
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -sn \
  -i "$INPUT_FILE" \
  -i "$INPUT_ASS_TW" \
  -map 0:v:0 \
  -map "0:a:0?" \
  -map 1:s:0 \
  -c copy \
  -disposition:s:0 default \
  -metadata:s:s:0 language=chi \
  -metadata:s:s:0 title="繁體中文" \
  "$TMPFILE"

mv "$TMPFILE" "$OUTPUT_FILE"
rm -rf "$ABS_INPUT_DIR"
