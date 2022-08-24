#! /bin/bash
# require ffmpeg
# nano ~/.config/fish/config.fish
# alias mkgif="sh ~/Codespaces/my-macos-build/scripts/make-gif.sh"
if [ "$#" -ne 3 ]; then
  echo "Usage: mkgif [input_file] [from(hh:mm:ss or sec)] [during(sec)]"
  echo "       mkgif \"input.mp4\" 01:02:08 11.0"
  exit 1
fi
INPUT_FILE=$1
OUTPUT_FILE="mkgif_$(date +"%Y%m%d%H%M%S").gif"
if [ -f "$INPUT_FILE" ]; then
  OUTPUT_ERROR=$(ffmpeg -hide_banner -loglevel error -ss "$2" -t "$3" -i "$1" -filter_complex "[0:v] fps=12,scale=w=480:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1" "$OUTPUT_FILE" 2>&1)
  if [ -n "$OUTPUT_ERROR" ]; then
    echo "$OUTPUT_ERROR"
    rm "$OUTPUT_FILE" >/dev/null 2>&1
    exit 1
  else
    echo "done. see $OUTPUT_FILE"
  fi
else
  echo "file: \"$INPUT_FILE\" do not exist."
fi
