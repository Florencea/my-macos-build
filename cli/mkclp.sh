#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
mkclp: Clip Maker (local files and YouTube videos, Apple Silicon HEVC)
Usage: mkclp [options] <input_file_or_url> <from> <duration>
Options:
  -q, --quality <num>    VideoToolbox quality 0-100 (default: 50)
  -c, --copy             Force lossless stream copy
  -b, --browser <name>   Browser for YouTube cookies (default: chrome)
  -o, --output <file>    Custom output file path
  -h, --help             Show this help message
EOF
}

QUALITY=50
QUALITY_SET=false
FORCE_COPY=false
BROWSER="${YT_DLP_BROWSER:-chrome}"
OUTPUT_FILE=""
POS_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -q | --quality)
      QUALITY="${2:?Error: --quality requires a value}"
      QUALITY_SET=true
      shift 2
      ;;
    -c | --copy)
      FORCE_COPY=true
      shift
      ;;
    -b | --browser)
      BROWSER="${2:?Error: --browser requires a value}"
      shift 2
      ;;
    -o | --output)
      OUTPUT_FILE="${2:?Error: --output requires a value}"
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POS_ARGS+=("$1")
        shift
      done
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      exit 1
      ;;
    *)
      POS_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#POS_ARGS[@]} -ne 3 ]]; then
  usage >&2
  exit 1
fi

INPUT_FILE="${POS_ARGS[0]}"
START="${POS_ARGS[1]}"
DURATION="${POS_ARGS[2]}"
[[ -n "$OUTPUT_FILE" ]] || OUTPUT_FILE="$(date +"%Y%m%d%H%M%S")_clip.mp4"

FFMPEG_INPUTS=()
MAP_ARGS=()
VC_ARGS=(-c:v hevc_videotoolbox -q:v "$QUALITY" -profile:v main -pix_fmt yuv420p -tag:v hvc1 -c:a aac -b:a 192k)

if [[ -f "$INPUT_FILE" ]]; then
  FFMPEG_INPUTS=(-ss "$START" -i "$INPUT_FILE")
  MAP_ARGS=(-map 0:v:0 -map "0:a?")

  FORMAT="$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE" || true)"
  VIDEO_CODEC="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE" || true)"

  if [[ "$FORCE_COPY" == true ]] || { [[ "$FORMAT" == *mp4* ]] && [[ "$VIDEO_CODEC" == "h264" || "$VIDEO_CODEC" == "hevc" ]] && [[ "$QUALITY_SET" == false ]]; }; then
    VC_ARGS=(-c:v copy -c:a copy)
  fi
else
  YT_FORMAT="bestvideo[height<=1080]+bestaudio/best[height<=1080]"
  RAW_URLS="$(yt-dlp --cookies-from-browser "$BROWSER" -g -f "$YT_FORMAT" "$INPUT_FILE" 2>/dev/null || true)"
  if [[ -z "$RAW_URLS" ]]; then
    RAW_URLS="$(yt-dlp -g -f "$YT_FORMAT" "$INPUT_FILE")"
  fi

  STREAM_URLS=()
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      STREAM_URLS+=("$line")
    fi
  done <<<"$RAW_URLS"

  if [[ ${#STREAM_URLS[@]} -ge 2 ]]; then
    FFMPEG_INPUTS=(-ss "$START" -i "${STREAM_URLS[0]}" -ss "$START" -i "${STREAM_URLS[1]}")
    MAP_ARGS=(-map 0:v:0 -map "1:a?")
  else
    FFMPEG_INPUTS=(-ss "$START" -i "${STREAM_URLS[0]}")
    MAP_ARGS=(-map 0:v:0 -map "0:a?")
  fi
fi

ffmpeg -y -hide_banner -loglevel error \
  "${FFMPEG_INPUTS[@]}" \
  -t "$DURATION" \
  "${MAP_ARGS[@]}" \
  "${VC_ARGS[@]}" \
  -map_chapters -1 \
  -movflags +faststart \
  "$OUTPUT_FILE"

SIZE="$(stat -f "%z" "$OUTPUT_FILE" | awk '{ if ($1 >= 1048576) printf "%.1fM", $1/1048576; else if ($1 >= 1024) printf "%.1fK", $1/1024; else printf "%dB", $1 }')"
printf "%s %s\n" "$OUTPUT_FILE" "$SIZE"
