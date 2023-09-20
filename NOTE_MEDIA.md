# Media Note

- [Media Note](#media-note)
  - [Execute Media Scripts from remote](#execute-media-scripts-from-remote)
  - [Hardware Accelerated Encoding on Apple Silicon](#hardware-accelerated-encoding-on-apple-silicon)
  - [Software Encoding Commands](#software-encoding-commands)
  - [Make GIF](#make-gif)
  - [Downlaod Full Album from YTMusic](#downlaod-full-album-from-ytmusic)

## Execute Media Scripts from remote

- **Note:** `[ffmpeg](https://ffmpeg.org/)` and `[yt-dlp](https://github.com/yt-dlp/yt-dlp)` required.
- Use [Node.js](https://nodejs.org/en)

```sh
npx -y github:Florencea/my-macos-build
```

- Use [deno](https://deno.com/)

```sh
deno run -A 'https://raw.githubusercontent.com/Florencea/my-macos-build/main/scripts/vv.mjs'
```

## Hardware Accelerated Encoding on Apple Silicon

- <https://git.ffmpeg.org/gitweb/ffmpeg.git/commit/efece4442f3f583f7d04f98ef5168dfd08eaca5c>
- `-q:v` could be set 0 to 100, higher is better(larger file)
- Test on Macbook Pro 16" (M1 Pro, 2021), FFmpeg 6.0
  - Input H.264 AVC 1280 x 720
  - use `hevc_videotoolbox`

```sh
ffmpeg
  -hide_banner
  -i <INPUT_FILE>
  -c:v hevc_videotoolbox
  -q:v <QUALITY>
  -tag:v hvc1
  <OUTPUT_FILE>
```

| Quality  | Speed | Size  | Description                                                               |
| -------- | ----- | ----- | ------------------------------------------------------------------------- |
| original | -     | 258MB | Baseline                                                                  |
| `0`      | 14x   | 115MB | Under baseline. Subtitles are legible but charactor faces looks very bad. |
| `15`     | 14x   | 155MB | Under baseline. Motion frames looks pixelated.                            |
| `25`     | 14x   | 211MB | Under baseline. But unconspicuous unless complex motion frames.           |
| `40`     | 14x   | 296MB | Tell differences only when watching complex motion frames simultaneously. |
| `45`     | 14x   | 330MB | Visually consistent.                                                      |
| `100`    | 16x   | 4.4GB | Visually consistent.                                                      |

## Software Encoding Commands

- H.264 crf

| Acceptable | Streaming | Visual Loseless |
| ---------- | --------- | --------------- |
| 30         | 23        | 18              |

```sh
ffmpeg
  -hide_banner
  -i <INPUT_FILE>
  -vcodec libx264
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<ASS_FILE>'"
  <OUTPUT_FILE>
```

```sh
ffmpeg
  -hide_banner
  -i 'input.mp4'
  -vcodec libx264
  -crf 18
  -preset veryslow
  -vf "subtitles=filename='input.ass'"
  'output.mp4'
```

- HEVC crf

| Acceptable | Streaming | Visual Loseless |
| ---------- | --------- | --------------- |
| 31         | 24        | 20              |

```sh
ffmpeg
  -hide_banner
  -i <INPUT_FILE>
  -vcodec libx265
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<ASS_FILE>'"
  -tag:v hvc1
  <OUTPUT_FILE>
```

```sh
ffmpeg
  -hide_banner
  -i 'input.mp4'
  -vcodec libx265
  -crf 20
  -preset veryslow
  -vf "subtitles=filename='input.ass'"
  -tag:v hvc1
  'output.mp4'
```

- AV1 crf

| Acceptable | Streaming | Visual Loseless |
| ---------- | --------- | --------------- |
| 41         | 30        | 20              |

```sh
ffmpeg
  -hide_banner
  -i <INPUT_FILE>
  -vcodec libaom-av1
  -b:v 0
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<ASS_FILE>'"
  <OUTPUT_FILE>
```

```sh
ffmpeg
  -hide_banner
  -i 'input.mp4'
  -vcodec libaom-av1
  -b:v 0
  -crf 18
  -preset veryslow
  -vf "subtitles=filename='input.ass'"
  'output.mp4'
```

## Make GIF

- [vv.mjs](../scripts/vv.mjs) `mkgif`, `mkgifv`

```sh
ffmpeg
  -hide_banner
  -ss <Start(seconds or HH:mm:ss)>
  -t <Duration(sec)>
  -i <INPUT_FILE>
  -filter_complex "[0:v] fps=<FRAME_RATE>,scale=w=<WIDTH>:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  <OUTPUT_GIF>
```

```sh
ffmpeg
  -hide_banner
  -ss 00:01:13.5
  -t 3.2
  -i 'input.mp4'
  -filter_complex "[0:v] fps=12,scale=w=480:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  'output.gif'
```

## Downlaod Full Album from YTMusic

```sh
yt-dlp -f bestaudio --ppa "ThumbnailsConvertor+FFmpeg_o:-c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\"" --extract-audio --embed-thumbnail --embed-metadata --parse-metadata 'playlist_index:%(meta_track)s' --convert-thumbnails jpg -o "%(playlist_index)s %(title)s.%(ext)s" --cookies-from-browser <BROWSER> <URL>
```

```sh
yt-dlp -f bestaudio --ppa "ThumbnailsConvertor+FFmpeg_o:-c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\"" --extract-audio --embed-thumbnail --embed-metadata --parse-metadata 'playlist_index:%(meta_track)s' --convert-thumbnails jpg -o "%(playlist_index)s %(title)s.%(ext)s" --cookies-from-browser chrome 'https://music.youtube.com/playlist?list=OLAK5uy_l23NWV6DZh0-0g8A-A-bpvJfRTIamU0-8'
```
