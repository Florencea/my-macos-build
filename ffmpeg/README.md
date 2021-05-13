# FFmpeg 使用筆記

## 編碼說明

- 硬編呼叫 macOS 的 `videotoolbox` API
- 硬編速度壓倒性的勝過軟編，但自訂性較低
  - 無法控制畫質，僅僅是「能看」的程度，再提升碼率也無法提升畫質
  - 低碼率軟硬編品質差異不大，中碼率以上軟編壓倒性較好
  - 可用於高速壓制，但不適合收藏
- 硬編使用 Intel 內顯，獨立顯卡無法被呼叫
- `crf`可控制軟編品質，數值越接近`0`畫質越高，但檔案尺寸越大
  - 參考資料 <https://magiclen.org/vcodec/>

## 測試

- 裝置 MacBook Pro (15-inch, 2018) Intel Core i7-8850H
- 輸入檔案 H.264 AVC 1280 x 720

| 輸出格式 | 硬編編碼器     | 硬編速度 | 軟編編碼器   | 軟編速度 |
| -------- | -------------- | -------- | ------------ | -------- |
| H.264    | `videotoolbox` | 19x      | `libx264`    | 5x       |
| HEVC     | `videotoolbox` | 12x      | `libx265`    | 0.1x     |
| AV1      | 無             | -        | `libaom-av1` | 0.01x    |

## 軟體編碼指令

### 軟編 H.264

- `crf`數值設定

| 人眼能接受的最低限度 | 一般網路播放 | 視覺無損 |
| -------------------- | ------------ | -------- |
| 30                   | 23           | 18       |

- 為了保證畫質，故設定 present veryslow

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libx264
  -crf <crf數值>
  -preset veryslow
  -vf "subtitles=filename='<與輸入檔案同目錄下的字幕檔案>'"
  <輸出檔案名稱>
```

- 範例

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

### 軟編 HEVC

- `crf`數值設定

| 人眼能接受的最低限度 | 一般網路播放 | 視覺無損 |
| -------------------- | ------------ | -------- |
| 31                   | 24           | 20       |

- 為了保證畫質，故設定 present veryslow
- 為了使輸出的影片能夠被 macOS 的預覽程式識別，要加入 hvc1 的 tag

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libx265
  -crf <crf數值>
  -preset veryslow
  -vf "subtitles=filename='<與輸入檔案同目錄下的字幕檔案>'"
  -tag:v hvc1
  <輸出檔案名稱>
```

- 範例

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

### 軟編 AV1

- `crf`數值設定

| 人眼能接受的最低限度 | 一般網路播放 | 視覺無損 |
| -------------------- | ------------ | -------- |
| 41                   | 30           | 20       |

- 為了保證畫質，故設定 present veryslow

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libaom-av1
  -b:v 0
  -crf <crf數值>
  -preset veryslow
  -vf "subtitles=filename='<與輸入檔案同目錄下的字幕檔案>'"
  <輸出檔案名稱>
```

- 範例

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

## 硬體編碼指令

### 硬編 H.264

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -c:v h264_videotoolbox
  -profile:v <欲選擇的 profile: main | high | baseline>
  -b:v <影片碼率，預設 400k>
  -b:a <音軌碼率，預設 128k>
  -vf "subtitles=filename='<與輸入檔案同目錄下的字幕檔案>'"
  <輸出檔案名稱>
```

- 範例

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

### 硬編 HEVC

- 為了使輸出的影片能夠被 macOS 的預覽程式識別，要加入 hvc1 的 tag

```bash
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -c:v hevc_videotoolbox
  -profile:v <欲選擇的 profile: main | high>
  -b:v <影片碼率，預設 400k>
  -b:a <音軌碼率，預設 128k>
  -vf "subtitles=filename='<與輸入檔案同目錄下的字幕檔案>'"
  -tag:v hvc1
  <輸出檔案名稱>
```

- 範例

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

## 使用 FFmpeg 從影片製作 GIF

- 除非有進一步需求，建議使用儲存庫內的 [`make-gif.sh`](../scripts/make-gif.sh)
- `h=-1`表示寬度會隨高度調整
- 透過減少調色盤的顏色來縮小 GIF 體積

```bash
ffmpeg
  -hide_banner
  -ss <開始時間(秒，可接受小數) 或 開始時間(HH:mm:ss，秒可接受小數)>
  -t <時間長度(秒，可接受小數)>
  -i <輸入影片檔案>
  -filter_complex "[0:v] fps=<每秒幾幀>,scale=w=<GIF圖片寬度>:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  <輸出GIF檔案名稱>
```

- 範例

```bash
ffmpeg
  -hide_banner
  -ss 00:01:13.5
  -t 3.2
  -i 'input.mp4'
  -filter_complex "[0:v] fps=12,scale=w=480:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1"
  'output.gif'
```
