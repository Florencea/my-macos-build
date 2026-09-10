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
- Test on MacBook Pro 16" (M1 Pro, 2021), FFmpeg 9.0.1
  - Input: H.264 AVC 1280 x 720 from YouTube (Big Buck Bunny)
  - Encoder: `hevc_videotoolbox`

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map "0:a?" \
  -c:v hevc_videotoolbox \
  -q:v <QUALITY> \
  -tag:v hvc1 \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

| Quality  | Speed | Size  | VMAF  | Description                                                               |
| :------- | :---- | :---- | :---- | :------------------------------------------------------------------------ |
| original | -     | 81MB  | 100.0 | Baseline reference.                                                       |
| `0`      | 13.1x | 17MB  | 13.7  | Poor. Heavy blocking and severe loss of fine details.                     |
| `15`     | 13.1x | 22MB  | 31.6  | Low. Motion frames exhibit noticeable compression artifacts.              |
| `25`     | 13.2x | 28MB  | 48.5  | Fair. Acceptable for low-bandwidth mobile playback.                       |
| `40`     | 13.1x | 41MB  | 67.7  | Good. Minor differences only visible in complex motion scenes.            |
| `45`     | 13.1x | 48MB  | 73.8  | **Visually consistent. (Sweet Spot: storage-optimized, ~41% reduction).** |
| `50`     | 13.1x | 58MB  | 79.1  | **Visually consistent. (Sweet Spot: quality-optimized, ~29% reduction).** |
| `60`     | 11.1x | 95MB  | 88.5  | Diminishing returns. (+64% size vs q50, exceeds baseline size).           |
| `75`     | 10.0x | 196MB | 95.7  | Severe bloat. (3.4x size of q50 for marginal perceptual improvement).     |
| `100`    | 13.8x | 1.9GB | 98.9  | Near-lossless. (~33x size of q50, impractical file inflation).            |

> [!TIP]
> **Why `-q:v 45–50` is the Sweet Spot Range:**
>
> - **`-q:v 45`**: Best for storage and fast sharing (saves ~41% disk space, stays well under 50MB).
> - **`-q:v 50`**: Best for visual fidelity (VMAF climbs to 79.1 with +5.3 gain, while still saving ~29% space).
> - **Above `50`**: Stepping to `60` balloons size to 95MB (exceeding original video size). `75` and `100` cause severe bloat (up to 1.9GB, ~33×) with negligible real-world benefit during normal playback.

## Software Encoding Commands

- Benchmark tested on MacBook Pro 16" (M1 Pro, 2021), FFmpeg 9.0.1
  - Input: H.264 AVC 1280 x 720 from YouTube (Big Buck Bunny)

> [!NOTE]
>
> - `-map "0:a?"` is quoted to prevent wildcard globbing in modern shells (Zsh / Fish).
> - `-vf "subtitles=..."` is optional for burning subtitles and requires FFmpeg built with `libass` (e.g. via `homebrew-ffmpeg/ffmpeg/ffmpeg --with-libass`).
> - For HEVC and AV1, **10-bit color (`-pix_fmt yuv420p10le`) is strongly recommended** even for 8-bit sources to prevent color banding (posterization) in gradients/dark scenes and improve compression efficiency.
> - For AV1, `libsvtav1` is the modern standard on Apple Silicon; presets range from `0` to `13` (integers, recommended `4` to `6`).

### H.264 (AVC) crf

| Metric             | Acceptable     | Streaming      | Visual Lossless |
| :----------------- | :------------- | :------------- | :-------------- |
| **CRF**            | 30             | 23             | 18              |
| **Speed (M1 Pro)** | ~3.0x (71 fps) | ~2.6x (64 fps) | ~2.3x (57 fps)  |

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map "0:a?" \
  -c:v libx264 \
  -crf <CRF> \
  -preset veryslow \
  -vf "subtitles=filename='<ASS_FILE>'" \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

### HEVC (H.265) crf

| Metric             | Acceptable       | Streaming        | Visual Lossless  |
| :----------------- | :--------------- | :--------------- | :--------------- |
| **CRF**            | 31               | 26               | 21               |
| **Speed (M1 Pro)** | ~0.27x (6.6 fps) | ~0.23x (5.6 fps) | ~0.19x (4.8 fps) |

> [!WARNING]
> `libx265 -preset veryslow` is computationally prohibitive on CPU (~0.2x, 5× slower than real-time playback). If encoding speed or thermals are a concern, consider hardware encoding via `hevc_videotoolbox` (~13x) or SVT-AV1.

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map "0:a?" \
  -c:v libx265 \
  -crf <CRF> \
  -preset veryslow \
  -pix_fmt yuv420p10le \
  -vf "subtitles=filename='<ASS_FILE>'" \
  -tag:v hvc1 \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

### AV1 crf

| Metric               | Acceptable      | Streaming       | Visual Lossless |
| :------------------- | :-------------- | :-------------- | :-------------- |
| **CRF**              | 40              | 31              | 24              |
| **Speed (Preset 6)** | ~4.8x (115 fps) | ~4.7x (113 fps) | ~4.7x (115 fps) |
| **Speed (Preset 4)** | ~2.8x (68 fps)  | ~2.8x (67 fps)  | ~2.7x (65 fps)  |

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map "0:a?" \
  -c:v libsvtav1 \
  -crf <CRF> \
  -preset <PRESET_0_TO_13> \
  -pix_fmt yuv420p10le \
  -svtav1-params tune=0 \
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
  -vf "fps=<FRAME_RATE>,scale=<WIDTH>:-2:flags=lanczos,format=yuv420p" \
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
  -o "%(playlist_index)02d %(title)s.%(ext)s" \
  <URL>
```
