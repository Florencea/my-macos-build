#! /bin/bash

if [ "$#" -ne 1 ]; then
  echo "Usage: rea [input_dir]"
  echo "       rea \"input\""
  exit 1
fi
INPUT_DIR=$1
INPUT_FILE="$INPUT_DIR.mkv"
INPUT_ASS="$INPUT_DIR.cht.ass"
TEMP_FILE="temp_$INPUT_FILE"
OUTPUT_FILE="$INPUT_DIR.result.mkv"

if [-d "$INPUT_DIR"]; then
  cd $INPUT_DIR
  if [ -f "$INPUT_FILE" ]; then
    if [ -f "$INPUT_ASS" ]; then
      mv "$INPUT_FILE" "$TEMP_FILE"
      printf "combile ass start, params: -c:v copy -c:a copy -c:s copy\n"
      OUTPUT_ERROR=$(ffmpeg -i "$TEMP_FILE" -i "$INPUT_ASS" -c:v copy -c:a copy -c:s copy -map 0:0 -map 0:1 -map 1:0 -disposition:s:0 default "$OUTPUT_FILE" 2>&1)
      if [ -n "$OUTPUT_ERROR" ]; then
        echo "$OUTPUT_ERROR"
        rm "$OUTPUT_FILE" >/dev/null 2>&1
        exit 1
      else
        rm $TEMP_FILE
        mv $OUTPUT_FILE $INPUT_FILE
        printf "done.\n"
      fi
    else
      echo "file: \"$INPUT_ASS\" do not exist."
    fi
  else
    echo "file: \"$INPUT_FILE\" do not exist."
  fi
else
  echo "directory \"$INPUT_DIR\" do not exist."
fi
