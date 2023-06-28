#! /bin/bash

# encode mkv (hevc) to mp4

if [ "$#" -ne 1 ]; then
  echo "Usage: re4 [input.mkv]"
  echo "       rea \"input.mkv\""
  exit 1
fi
INPUT_FILE=$1
FILE_EXT="mp4"
OUTPUT_FILE="${INPUT_FILE/mkv/$FILE_EXT}"

if [ -f "$INPUT_FILE" ]; then
  printf "mkv to mp4 start, params: -c:v copy -c:a copy -tag:v hvc1 \n"
  OUTPUT_ERROR=$(ffmpeg -hide_banner -loglevel error -i "$INPUT_FILE" -c:v copy -c:a copy -tag:v hvc1 "$OUTPUT_FILE" 2>&1)
  if [ -n "$OUTPUT_ERROR" ]; then
    echo "$OUTPUT_ERROR"
    rm "$OUTPUT_FILE" >/dev/null 2>&1
    exit 1
  else
    printf "done.\n"
  fi
else
  echo "file: \"$INPUT_FILE\" do not exist."
fi
