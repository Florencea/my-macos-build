#!/usr/bin/env bash
# High-quality GIF maker via ffmpeg and gifski
# Usage: mkgif [-w 720] [--fps 10] [-q 70] [-l] [-b edge] [-o out.gif] <input_file_or_url> <from> <duration>
set -euo pipefail

WIDTH=720
FPS=10
QUALITY=70
LOSSY=false
BROWSER="${YT_DLP_BROWSER:-edge}"
OUTPUT_FILE=""
POS_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w | --width)
      WIDTH="$2"
      shift 2
      ;;
    --fps)
      FPS="$2"
      shift 2
      ;;
    -q | --quality)
      QUALITY="$2"
      shift 2
      ;;
    -l | --lossy)
      LOSSY=true
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
[[ -n "$OUTPUT_FILE" ]] || OUTPUT_FILE="$(date +"%Y%m%d%H%M%S")_fps${FPS}.gif"

INPUT_SOURCE="$INPUT_FILE"
if [[ ! -f "$INPUT_FILE" ]]; then
  if ((WIDTH <= 480)); then
    YT_HEIGHT=480
  elif ((WIDTH <= 720)); then
    YT_HEIGHT=720
  elif ((WIDTH <= 1280)); then
    YT_HEIGHT=1080
  else
    YT_HEIGHT=2160
  fi

  YT_FORMAT="bestvideo[height<=${YT_HEIGHT}]/best[height<=${YT_HEIGHT}]/bestvideo/best"
  STREAM_URL="$(yt-dlp --cookies-from-browser "$BROWSER" -g -f "$YT_FORMAT" "$INPUT_FILE" 2>/dev/null || true)"
  if [[ -z "$STREAM_URL" ]]; then
    STREAM_URL="$(yt-dlp -g -f "$YT_FORMAT" "$INPUT_FILE")"
  fi
  INPUT_SOURCE="$(printf '%s\n' "$STREAM_URL" | head -n 1)"
fi

GIFSKI_ARGS=(-q -Q "$QUALITY" -W "$WIDTH")
if [[ "$LOSSY" == true ]]; then
  GIFSKI_ARGS+=(--lossy-quality 75)
fi

ffmpeg -y -hide_banner -loglevel error \
  -ss "$START" \
  -i "$INPUT_SOURCE" \
  -t "$DURATION" \
  -vf "fps=$FPS,scale=$WIDTH:-2:flags=lanczos,format=yuv420p" \
  -f yuv4mpegpipe - |
  gifski "${GIFSKI_ARGS[@]}" -o "$OUTPUT_FILE" -

SIZE="$(stat -f "%z" "$OUTPUT_FILE" | awk '{ if ($1 >= 1048576) printf "%.1fM", $1/1048576; else if ($1 >= 1024) printf "%.1fK", $1/1024; else printf "%dB", $1 }')"
printf "%s %s\n" "$OUTPUT_FILE" "$SIZE"
