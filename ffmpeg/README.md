# FFmpeg Note

## Hardware Accelerated Encodeing in macOS

- FFmpeg call `videotoolbox` API for hardware accelerated encodeing in macOS
- Hardware accelerated encodeing is **mush faster** but **less customizable**
  - Video looks similar at `low` bitrate for both hardware and software encoding
  - However video use hardware accelerated encodeing looks terrible at `mid` or `high` bitrate
- Hardware accelerated encodeing **works on Intel Integrated GPU only**
- Software encoding could set `crf` for video quality, smaller is better, but video size get larger
- Tests runs on MacBook Pro (15-inch, 2018) Intel Core i7-8850H, FFmpeg 4.3
  - Input video H.264 AVC 1280 x 720

| Output Format | Encoder(Hardware) | Speed(Hardware) | Encoder(Software) | Speed(Software) |
| ------------- | ----------------- | --------------- | ----------------- | --------------- |
| H.264         | `videotoolbox`    | 19x             | `libx264`         | 5x              |
| HEVC          | `videotoolbox`    | 12x             | `libx265`         | 0.1x            |
| AV1           | 無                | -               | `libaom-av1`      | 0.01x           |

## Software Encoding Commands

- H.264 `crf` configuration

| Acceptable | Normal | Visual Loseless |
| ---------- | ------ | --------------- |
| 30         | 23     | 18              |

```bash
ffmpeg
  -hide_banner
  -i <input file>
  -vcodec libx264
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<subtitle file in same directory>'"
  <output file>
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

- HEVC `crf` configuration

| Acceptable | Normal | Visual Loseless |
| ---------- | ------ | --------------- |
| 31         | 24     | 20              |

```bash
ffmpeg
  -hide_banner
  -i <input file>
  -vcodec libx265
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<subtitle file in same directory>'"
  -tag:v hvc1
  <output file>
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

- AV1 `crf` configuration

| Acceptable | Normal | Visual Loseless |
| ---------- | ------ | --------------- |
| 41         | 30     | 20              |

```bash
ffmpeg
  -hide_banner
  -i <input file>
  -vcodec libaom-av1
  -b:v 0
  -crf <crf數值>
  -preset veryslow
  -vf "subtitles=filename='<subtitle file in same directory>'"
  <output file>
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

## Hardware Encoding Commands

- H.264

```bash
ffmpeg
  -hide_banner
  -i <input file>
  -c:v h264_videotoolbox
  -profile:v <profile: main | high | baseline>
  -b:v <video bitrate, default: 400k>
  -b:a <audio bitrate, default: 128k>
  -vf "subtitles=filename='<subtitle file in same directory>'"
  <output file>
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
  -i <input file>
  -c:v hevc_videotoolbox
  -profile:v <profile: main | high>
  -b:v <video bitrate, default: 400k>
  -b:a <audio bitrate, default: 128k>
  -vf "subtitles=filename='<subtitle file in same directory>'"
  -tag:v hvc1
  <output file>
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

## Make GIF from Video

- [make-gif.sh](../scripts/make-gif.sh)

```bash
ffmpeg
  -hide_banner
  -ss <start at(second or HH:mm:ss)>
  -t <duration(second)>
  -i <input video>
  -filter_complex "[0:v] fps=<gif frame per second>,scale=w=<gif width>:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  <output gif>
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
