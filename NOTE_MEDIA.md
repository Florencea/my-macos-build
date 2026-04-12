# Media Note

- [Media Note](#media-note)
  - [Hardware Accelerated Encoding on Apple Silicon](#hardware-accelerated-encoding-on-apple-silicon)
  - [Software Encoding Commands](#software-encoding-commands)
  - [Make GIF](#make-gif)
  - [Make GIF (Modern Pipeline)](#make-gif-modern-pipeline)
  - [Download Full Album from YTMusic](#download-full-album-from-ytmusic)

## Hardware Accelerated Encoding on Apple Silicon

- <https://git.ffmpeg.org/gitweb/ffmpeg.git/commit/efece4442f3f583f7d04f98ef5168dfd08eaca5c>
- <https://trac.ffmpeg.org/wiki/HWAccelIntro#VideoToolbox>
- `-q:v` could be set 0 to 100, higher is better (larger file).
- `-movflags +faststart` ensures instant Quick Look preview on macOS and fast network streaming.
- Test on Macbook Pro 14" (M3, 2023), FFmpeg 7.0.1
  - Input: H.264 AVC 1280 x 720 from YouTube
  - Encoder: `hevc_videotoolbox`

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map 0:a? \
  -c:v hevc_videotoolbox \
  -q:v <QUALITY> \
  -tag:v hvc1 \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

| Quality  | Speed | Size  | Description                                                               |
| :------- | :---- | :---- | :------------------------------------------------------------------------ |
| original | -     | 157MB | Baseline.                                                                 |
| `0`      | 15x   | 169MB | Under baseline. Subtitles are legible but character faces look very bad.  |
| `15`     | 15x   | 168MB | Under baseline. Motion frames look pixelated.                             |
| `25`     | 15x   | 166MB | Under baseline. Unconspicuous unless complex motion frames.               |
| `40`     | 15x   | 200MB | Tell differences only when watching complex motion frames simultaneously. |
| `45`     | 15x   | 231MB | Visually consistent. (Sweet Spot)                                         |
| `100`    | 17x   | 3.7GB | Visually consistent. (Near-Lossless, massive file)                        |

## Software Encoding Commands

### H.264 (AVC) crf

| Acceptable | Streaming | Visual Lossless |
| :--------- | :-------- | :-------------- |
| 30         | 23        | 18              |

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map 0:a? \
  -c:v libx264 \
  -crf <CRF> \
  -preset veryslow \
  -vf "subtitles=filename='<ASS_FILE>'" \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

### HEVC (H.265) crf

| Acceptable | Streaming | Visual Lossless |
| :--------- | :-------- | :-------------- |
| 31         | 24        | 20              |

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map 0:a? \
  -c:v libx265 \
  -crf <CRF> \
  -preset veryslow \
  -vf "subtitles=filename='<ASS_FILE>'" \
  -tag:v hvc1 \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

### AV1 crf

| Acceptable | Streaming | Visual Lossless |
| :--------- | :-------- | :-------------- |
| 41         | 30        | 20              |

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map 0:a? \
  -c:v libaom-av1 \
  -b:v 0 \
  -crf <CRF> \
  -preset veryslow \
  -vf "subtitles=filename='<ASS_FILE>'" \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

## Make GIF

_Generate high-quality GIFs using a two-pass color palette generation entirely within FFmpeg._

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -ss <START> \
  -i <INPUT_FILE> \
  -t <DURATION> \
  -vf "fps=<FRAME_RATE>,scale=<WIDTH>:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  <OUTPUT_GIF>
```

**Example:**

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -ss 00:01:13.5 \
  -i 'input.mp4' \
  -t 3.2 \
  -vf "fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  'output.gif'
```

## Make GIF (Modern Pipeline)

_Highly recommended to use [gifski](https://github.com/ImageOptim/gifski) via `yuv4mpegpipe` for zero disk I/O and highest quality color quantization._

```bash
ffmpeg -y -hide_banner -loglevel error -stats \
  -ss <START> \
  -i <INPUT_FILE> \
  -t <DURATION> \
  -vf "fps=<FRAME_RATE>,scale=<WIDTH>:-1:flags=lanczos" \
  -f yuv4mpegpipe - | \
  gifski -q \
    -Q <QUALITY_1_TO_100> \
    -o <OUTPUT_GIF> -
```

## Download Full Album from YTMusic

_Optimized for multiline readability in modern shells._

```bash
yt-dlp \
  --no-warnings \
  --progress \
  -f bestaudio \
  --ppa "ThumbnailsConvertor+FFmpeg_o:-c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\"" \
  --extract-audio \
  --embed-thumbnail \
  --embed-metadata \
  --parse-metadata 'playlist_index:%(meta_track)s' \
  --convert-thumbnails jpg \
  --print before_dl:"[%(playlist_index)s/%(playlist_count)s]: %(playlist_index)s %(title)s" \
  --cookies-from-browser <BROWSER> \
  -o "%(playlist_index)s %(title)s.%(ext)s" \
  <URL>
```
