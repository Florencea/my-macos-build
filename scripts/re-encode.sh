#! /bin/bash

# require ffmpeg
# nano ~/.config/fish/config.fish
# alias rec="sh ~/GitHub/my-macos-build/scripts/re-encode.sh"
if [ "$#" -ne 1 ]; then
  echo "Usage: rec [input_file]"
  echo "       rec \"input.mp4\""
  exit 1
fi
INPUT_FILE=$1
OUTPUT_FILE="temp_$INPUT_FILE"
if [ -f "$INPUT_FILE" ]; then
  printf "re-encode start, params: -vcodec copy -acodec copy\n"
  OUTPUT_ERROR=$(ffmpeg -hide_banner -loglevel error -i "$INPUT_FILE" -vcodec copy -acodec copy "$OUTPUT_FILE" 2>&1)
  if [ -n "$OUTPUT_ERROR" ]; then
    echo "$OUTPUT_ERROR"
    rm "$OUTPUT_FILE" >/dev/null 2>&1
    exit 1
  else
    rm $INPUT_FILE
    mv $OUTPUT_FILE $INPUT_FILE
    printf "done.\n"
  fi
else
  echo "file: \"$INPUT_FILE\" do not exist."
fi
