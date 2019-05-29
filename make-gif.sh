#! /bin/bash
# nano ~/.config/fish/config.fish
# alias mkgif="bash ~/Documents/workspace_florencea/my-macos-build/make-gif.sh"
echo "usage: mkgif <input_file> <from(sec)> <during(sec)>"
echo "making gif for $1 ..."
echo "from: $2 sec"
echo "during: $3 sec"
ffmpeg -ss $2 -t $3 -i $1 -filter_complex "[0:v] fps=12,scale=w=480:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1" $1.gif > /dev/null 2>&1
echo "done."
echo "see $1.gif"
