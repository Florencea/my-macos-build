#! /usr/bin/fish
# require ffmpeg, fish
# nano ~/.config/fish/config.fish
# alias mkgif="sh ~/GitHub/my-macos-build/make-gif.sh"
if test (count $argv) -lt 3; or test (count $argv) -gt 3
echo "Usage: mkgif [input_file] [from(hh:mm:ss or sec)] [during(sec)]"
echo "       mkgif \"input.mp4\" 01:02:08 11.0"
exit 1
end
if test -f $argv[1]
set n mkgif_(date +"%Y%m%d%H%M%S")
set er (ffmpeg -hide_banner -loglevel error -ss $argv[2] -t $argv[3] -i "$argv[1]" -filter_complex "[0:v] fps=12,scale=w=480:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1" "$n.gif" 2>&1)
if test $er
echo $er
rm $n.gif > /dev/null 2>&1
exit 1
else
echo "done. see $n.gif"
end
else
echo "file: \"$argv[1]\" do not exist."
end
