# FFmpeg 使用筆記

## 有關 Apple Silicon 中的硬體加速編碼

- FFmpeg 2021 年 3 月後針對 Apple Silicon 釋出的版本 videotoolbox 增加了 `-q:v` 參數可以控制品質(Apple Silicon 專用)
- `-q:v` 值的範圍為`0` ~ `100`，值越接近 `100` 品質越好(事實上在源碼中會轉換成比例故範圍才是 0~100)
- 一樣品質越好檔案大小越大，但已經不像控制`-b:v`位元率差的那麼嚴重
- 以下測試使用 Mac mini (M1, 2020), FFmpeg 4.4.1
  - 測試輸入影片為 H.264 AVC 1280 x 720
  - 使用 videotoolbox 硬體加速編碼為 hevc

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -c:v hevc_videotoolbox
  -q:v <品質>
  -tag:v hvc1
  <輸出檔案>
```

| 品質參數 | 編碼速度 | 檔案大小 | 人眼識別品質                                                                             |
| -------- | -------- | -------- | ---------------------------------------------------------------------------------------- |
| 原檔     | -        | 285MB    | 基準值                                                                                   |
| `0`      | 11x      | 101MB    | 低於基準值，字幕勉強可讀，紋理與花紋甚至五官都會糊掉，接近 Line 用行動訊號視訊通話的程度 |
| `15`     | 11x      | 131MB    | 低於基準值，非靜止幀出現非常明顯色塊，接近舊 Intel MBP FaceTime 影片品質                 |
| `25`     | 11x      | 174MB    | 低於基準值，動態複雜場景色塊才會明顯，大約是一般網路串流 H264 品質                       |
| `40`     | 11x      | 244MB    | 除非並行觀看高動態場景，視覺上無法區分與基準值差異                                       |
| `45`     | 11x      | 277MB    | 視覺上無法區分與基準值差異                                                               |
| `50`     | 11x      | 316MB    | 視覺上無法區分與基準值差異                                                               |
| `65`     | 11x      | 528MB    | 視覺上無法區分與基準值差異                                                               |
| `100`    | 11x      | 4GB      | 視覺上無法區分與基準值差異                                                               |

## 有關硬體加速編碼

- FFmpeg 使用 macOS 的 videotoolbox API 執行硬體加速編碼
- 硬體加速編碼**相當高效**但**自訂性差**
  - 在碼率低的狀況，硬編跟軟編品質差不多
  - 中高碼率的狀況，軟編品質遠勝硬編
- 硬編只會使用**Intel 內顯**
- 軟編可以使用 crf 參數控制品質，越接近 0 品質越好，但檔案越大
- 以下測試使用 MacBook Pro (15-inch, 2018) Intel Core i7-8850H, FFmpeg 4.3
  - 測試輸入影片為 H.264 AVC 1280 x 720

| 輸出格式 | 編碼器(硬編)   | 速度(硬編) | 編碼器(軟編) | 速度(軟編) |
| -------- | -------------- | ---------- | ------------ | ---------- |
| H.264    | `videotoolbox` | 19x        | `libx264`    | 5x         |
| HEVC     | `videotoolbox` | 12x        | `libx265`    | 0.1x       |
| AV1      | 無             | -          | `libaom-av1` | 0.01x      |

## 軟編指令

- H.264 crf 參數設定

| 人眼可接受最低品質 | 普通(網路串流) | 視覺無損 |
| ------------------ | -------------- | -------- |
| 30                 | 23             | 18       |

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libx264
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<同目錄下的字幕檔>'"
  <輸出檔案>
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

- HEVC crf 參數設定

| 人眼可接受最低品質 | 普通(網路串流) | 視覺無損 |
| ------------------ | -------------- | -------- |
| 31                 | 24             | 20       |

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libx265
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<同目錄下的字幕檔>'"
  -tag:v hvc1
  <輸出檔案>
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

- AV1 crf 參數設定

| 人眼可接受最低品質 | 普通(網路串流) | 視覺無損 |
| ------------------ | -------------- | -------- |
| 41                 | 30             | 20       |

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libaom-av1
  -b:v 0
  -crf <crf>
  -preset veryslow
  -vf "subtitles=filename='<同目錄下的字幕檔>'"
  <輸出檔案>
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

## 硬編指令

- H.264

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -c:v h264_videotoolbox
  -profile:v <profile: main | high | baseline>
  -b:v <video bitrate, 預設值: 400k>
  -b:a <audio bitrate, 預設值: 128k>
  -vf "subtitles=filename='<同目錄下的字幕檔>'"
  <輸出檔案>
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
  -i <輸入檔案>
  -c:v hevc_videotoolbox
  -profile:v <profile: main | high>
  -b:v <video bitrate, 預設值: 400k>
  -b:a <audio bitrate, 預設值: 128k>
  -vf "subtitles=filename='<同目錄下的字幕檔>'"
  -tag:v hvc1
  <輸出檔案>
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

## 製作 GIF

- [make-gif.sh](../scripts/make-gif.sh)

```bash
ffmpeg
  -hide_banner
  -ss <開始時間(秒 或 時:分:秒)>
  -t <GIF時間長度(秒)>
  -i <輸入影片>
  -filter_complex "[0:v] fps=<GIF每秒幾幀>,scale=w=<GIF寬度>:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  <輸出GIF>
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
