# FFmpeg Note

## Hardware Accelerated Encoding on Apple Silicon

- <https://git.ffmpeg.org/gitweb/ffmpeg.git/commit/efece4442f3f583f7d04f98ef5168dfd08eaca5c>
- `-q:v` could be set 0 to 100, higher is better(larger file)
- Test on Mac mini (M1, 2020), FFmpeg 4.4.1
  - Input H.264 AVC 1280 x 720
  - use `hevc_videotoolbox`

```bash
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
| original | -     | 285MB | Baseline                                                                  |
| `0`      | 11x   | 101MB | Under baseline. Subtitles are legible but charactor faces looks very bad. |
| `15`     | 11x   | 131MB | Under baseline. Motion frames looks pixelated.                            |
| `25`     | 11x   | 174MB | Under baseline. But unconspicuous unless complex motion frames.           |
| `40`     | 11x   | 244MB | Tell differences only when watching complex motion frames simultaneously. |
| `45`     | 11x   | 277MB | Visually consistent.                                                      |
| `50`     | 11x   | 316MB | Visually consistent.                                                      |
| `65`     | 11x   | 528MB | Visually consistent.                                                      |
| `100`    | 11x   | 4GB   | Visually consistent.                                                      |

## Hardware Accelerated Encoding

- FFmpeg use videotoolbox API in macOS
- High efficiency but lack of customization
- Only available on Intel Integrated Graphics
- Use `crf` for video quality, lower is better(larger file)
- Test on MacBook Pro (15-inch, 2018) Intel Core i7-8850H, FFmpeg 4.3
  - Input H.264 AVC 1280 x 720

| Format | Codec(Hardware) | Speed(Hardware) | Codec(Software) | Speed(Software) |
| ------ | --------------- | --------------- | --------------- | --------------- |
| H.264  | `videotoolbox`  | 19x             | `libx264`       | 5x              |
| HEVC   | `videotoolbox`  | 12x             | `libx265`       | 0.1x            |
| AV1    | -               | -               | `libaom-av1`    | 0.01x           |

## Commands(Software)

- H.264 crf

| Acceptable | Streaming | Visual Loseless |
| ---------- | --------- | --------------- |
| 30         | 23        | 18              |

```bash
ffmpeg
  -hide_banner
  -i <INPUT_FILE>
  -vcodec libx264
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<ASS_FILE>'"
  <OUTPUT_FILE>
```

```bash
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

```bash
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

```bash
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

```bash
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

```bash
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

## Commands(Hardware)

- H.264

```bash
ffmpeg
  -hide_banner
  -i <INPUT_FILE>
  -c:v h264_videotoolbox
  -profile:v <profile: main | high | baseline>
  -b:v <video bitrate, Default: 400k>
  -b:a <audio bitrate, Default: 128k>
  -vf "subtitles=filename='<ASS_FILE>'"
  <OUTPUT_FILE>
```

```bash
ffmpeg
  -hide_banner
  -i 'input.mp4'
  -c:v h264_videotoolbox
  -profile:v main
  -b:v 2000k
  -b:a 128k
  -vf "subtitles=filename='input.ass'"
  'output.mp4'
```

- HEVC

```bash
ffmpeg
  -hide_banner
  -i <INPUT_FILE>
  -c:v hevc_videotoolbox
  -profile:v <profile: main | high>
  -b:v <video bitrate, Default: 400k>
  -b:a <audio bitrate, Default: 128k>
  -vf "subtitles=filename='<ASS_FILE>'"
  -tag:v hvc1
  <OUTPUT_FILE>
```

```bash
ffmpeg
  -hide_banner
  -i 'input.mp4'
  -c:v hevc_videotoolbox
  -profile:v main
  -b:v 2000k
  -b:a 128k
  -vf "subtitles=filename='input.ass'"
  -tag:v hvc1
  'output.mp4'
```

## Make GIF

- [make-gif.sh](../scripts/make-gif.sh)

```bash
ffmpeg
  -hide_banner
  -ss <Start(seconds or HH:mm:ss)>
  -t <Duration(sec)>
  -i <INPUT_FILE>
  -filter_complex "[0:v] fps=<FRAME_RATE>,scale=w=<WIDTH>:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  <OUTPUT_GIF>
```

```bash
ffmpeg
  -hide_banner
  -ss 00:01:13.5
  -t 3.2
  -i 'input.mp4'
  -filter_complex "[0:v] fps=12,scale=w=480:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  'output.gif'
```
