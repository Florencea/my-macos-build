# ffmpeg Note

-   Hardware encoding using `videotoolbox`, however the parameters could not be fully customized.
    -   It works only on Intel integrated graphics, not discreted GPUs.
-   Test using a h264 AVC 720p file, Intel i7-8850H on Macbook Pro 15" 2018.
    -   `av1` software encoding `0.01x`
    -   `hevc` software encoding `0.1x`
    -   `h264` software encoding `5x`
    -   `hevc` hardware encoding `12x`
    -   `h264` hardware encoding `19x`
-   For quality in software encoding, use `crf` and `-present` parameters, not bitrate.
-   For hardware encoding, appropriate bitrate could not be estimated easily.
-   You can try software encoding to find acceptable bitrate, but video encoded by `videotoolbox` may not look as good as the one from software encoding using same bitrate.
-   About `crf`
    -   Visually loseless
        -   `h264`: 18
        -   `hevc`: 20
        -   `av1`: 20
    -   Normal for online streaming
        -   `h264`: 23
        -   `hevc`: 24
        -   `av1`: 30
    -   Lowest quality acceptable for human eyes
        -   `h264`: 30
        -   `hevc`: 31
        -   `av1`: 41
-   Referenced from <https://magiclen.org/vcodec/>

```fish
# ffmpeg h264 software encoding
ffmpeg
  -hide_banner
  -i <input file>
  -vcodec libx264
  -crf 18
  -preset veryslow
  -vf "subtitles=filename='<subtitle file in same directory>'"
  <output file.mp4>

# ffmpeg hevc software encoding
ffmpeg
  -hide_banner
  -i <input file>
  -vcodec libx265
  -crf 20
  -preset veryslow
  -vf "subtitles=filename='<subtitle file in same directory>'"
  <output file.mp4>

# ffmpeg av1 software encoding
ffmpeg
  -hide_banner
  -i <input file>
  -vcodec libaom-av1
  -b:v 0
  -crf 20
  -vf "subtitles=filename='<subtitle file in same directory>'"
  <output file.mp4>

# ffmpeg h264 hardware encoding on macOS
ffmpeg
  -hide_banner
  -i <input file>
  -c:v h264_videotoolbox
  -profile:v <prefered profile: main, high or baseline>
  -b:v <video bitrate, default is 400k>
  -b:a <audio bitrate, default is 128k>
  -vf "subtitles=filename='<subtitle file in same directory>'"
  <output file.mp4>

# ffmpeg hevc hardware encoding on macOS
# In order to mark video as hevc for Finder and Quicktime Player, add tag hvc1
ffmpeg
  -hide_banner
  -i <input file>
  -c:v hevc_videotoolbox
  -profile:v <prefered profile: main or highe>
  -b:v <video bitrate, default is 400k>
  -b:a <audio bitrate, default is 128k>
  -vf "subtitles=filename='<subtitle file in same directory>'"
  -tag:v hvc1
  <output file.mp4>

# make GIF using ffmpeg
ffmpeg
  -hide_banner
  -ss <start position(sec)>
  -t <durination(sec)>
  -i <input file>
  -filter_complex "[0:v] fps=12,scale=w=480:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  <output file.gif>
```
