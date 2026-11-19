#!/usr/bin/env bash
# Clip Maker (local files and YouTube videos, Apple Silicon HEVC)
# Usage: mkclp [-q 50] [-c] [-b edge] [-o out.mp4] <input_file_or_url> <from> <duration>
set -euo pipefail

QUALITY=50
QUALITY_SET=false
FORCE_COPY=false
BROWSER="${YT_DLP_BROWSER:-edge}"
OUTPUT_FILE=""
POS_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -q | --quality)
      QUALITY="$2"
      QUALITY_SET=true
      shift 2
      ;;
    -c | --copy)
      FORCE_COPY=true
      shift
      ;;
    -b | --browser)
      BROWSER="$2"
      shift 2
      ;;
    -o | --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POS_ARGS+=("$1")
        shift
      done
      ;;
    *)
      POS_ARGS+=("$1")
      shift
      ;;
  esac
done

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
