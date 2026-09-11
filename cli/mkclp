#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Description: Clip Maker (Supports --quality [value], local files and YouTube videos)
# Usage: mkclp [--quality 50] [input_file_or_url] [from(hh:mm:ss or sec)] [during(sec)]
# Example: mkclp 'input.mp4' 01:02:08 11.0
#          mkclp JoSY6AWKqHs 00:01:59 2
#          mkclp JoSY6AWKqHs 00:01:59 2 --quality 45

# 1. Parse options
QUALITY=50
TEMP_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  -q | --quality)
    if [[ $# -lt 2 ]]; then
      echo "Error: --quality requires a value" >&2
      exit 1
    fi
    QUALITY="$2"
    shift 2
    ;;
  *)
    TEMP_ARGS+=("$1")
    shift 1
    ;;
  esac
done

set -- "${TEMP_ARGS[@]}"

# 2. Check arguments
INPUT_FILE="${1:-}"
START="${2:-}"
DURATION="${3:-}"

if [[ -z "$DURATION" ]]; then
  echo "mkclp: Clip Maker (Supports --quality [value], local files and YouTube videos)" >&2
  echo "Usage: mkclp [--quality 50] [input_file_or_url] [from(hh:mm:ss or sec)] [during(sec)]" >&2
  echo "       mkclp 'input.mp4' 01:02:08 11.0" >&2
  echo "       mkclp JoSY6AWKqHs 00:01:59 2" >&2
  echo "       mkclp JoSY6AWKqHs 00:01:59 2 --quality 45" >&2
  exit 1
fi

# 3. Check required tools
for cmd in ffmpeg ffprobe; do
  command -v "$cmd" &>/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

IS_YT=false
if [[ ! -f "$INPUT_FILE" ]]; then
  command -v yt-dlp &>/dev/null || {
    echo "Error: File $INPUT_FILE does not exist and yt-dlp is not installed" >&2
    exit 1
  }
  IS_YT=true
fi

# 4. Resolve input source
VC_ARGS=(-c:v copy)
FFMPEG_INPUTS=()
MAP_ARGS=()

if [[ "$IS_YT" == true ]]; then
  # Fetch up to 1080p best video and audio streams
  BROWSER="${YT_DLP_BROWSER:-chrome}"
  YT_FORMAT="bestvideo[height<=1080]+bestaudio/best[height<=1080]"
  RAW_URLS=$(yt-dlp --cookies-from-browser "$BROWSER" -g -f "$YT_FORMAT" "$INPUT_FILE" 2>/dev/null || true)
  if [[ -z "$RAW_URLS" ]]; then
    RAW_URLS=$(yt-dlp -g -f "$YT_FORMAT" "$INPUT_FILE" 2>/dev/null || true)
  fi
  if [[ -z "$RAW_URLS" ]]; then
    echo "Error: Failed to get stream URL from yt-dlp for input: $INPUT_FILE" >&2
    exit 1
  fi

  readarray -t STREAM_URLS <<<"$RAW_URLS"

  # Support separate video and audio streams
  if [[ ${#STREAM_URLS[@]} -ge 2 ]]; then
    FFMPEG_INPUTS=(-ss "$START" -i "${STREAM_URLS[0]}" -ss "$START" -i "${STREAM_URLS[1]}")
    MAP_ARGS=(-map 0:v:0 -map "1:a?")
  else
    FFMPEG_INPUTS=(-ss "$START" -i "${STREAM_URLS[0]}")
    MAP_ARGS=(-map 0:v:0 -map "0:a?")
  fi

  # Hardware HEVC encoding optimized for Apple devices and LINE (Sweet Spot: q=50)
  VC_ARGS=(-c:v hevc_videotoolbox -q:v "$QUALITY" -profile:v main -pix_fmt yuv420p -tag:v hvc1)
else
  FFMPEG_INPUTS=(-ss "$START" -i "$INPUT_FILE")
  MAP_ARGS=(-map 0:v:0 -map "0:a?")

  # Detect container format and video codec
  FORMAT=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE" || true)
  VIDEO_CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE" || true)

  # Re-encode non-mp4 or non-h264/hevc video using hevc_videotoolbox
  if [[ ! "$FORMAT" =~ "mp4" ]] || [[ "$VIDEO_CODEC" != "h264" && "$VIDEO_CODEC" != "hevc" ]]; then
    VC_ARGS=(-c:v hevc_videotoolbox -q:v "$QUALITY" -profile:v main -pix_fmt yuv420p -tag:v hvc1)
  fi
fi

# 5. Generate video clip
OUTPUT_FILE="$(date +"%Y%m%d%H%M%S")_clip.mp4"

ffmpeg -y -hide_banner \
  -loglevel error \
  "${FFMPEG_INPUTS[@]}" \
  -t "$DURATION" \
  "${MAP_ARGS[@]}" \
  "${VC_ARGS[@]}" \
  -c:a aac \
  -b:a 192k \
  -map_chapters -1 \
  -movflags +faststart \
  "$OUTPUT_FILE"

# 6. Display output result
printf "%s " "$OUTPUT_FILE"
ls -lh "$OUTPUT_FILE" | awk '{print $5}'
