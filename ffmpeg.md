# ffmpeg 紀錄

- 硬體編碼使用 `videotoolbox`, 可用參數非常少
- `videotoolbox` 使用 Intel 內顯，獨顯無用
- 參考數據使用 i7-8850H, 720p h264 AVC 原始檔案
  - av1 軟編約 `0.01x`
  - hevc 軟編約 `0.1x`
  - h264 軟編約 `5x`
  - hevc 硬編約 `12x`
  - h264 硬編約 `19x`
- 軟編請使用 `crf` 與編碼速度，而非位元率來控制品質
- 硬編的位元率計算並不單純，可以先使用軟編計算位元率，但同位元率下硬編畫質會略差軟編(編碼速度問題)
- crf 設置部分，視覺無損`(h264/hevc/av1)`為`(18/20/20)`，一般網源為`(23/24/30)`，最低可看為`(30/31/41)`
- 參考 [https://magiclen.org/vcodec/](https://magiclen.org/vcodec/)

```fish
# ffmpeg h264 軟體編碼
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libx264
  -crf 18
  -preset veryslow
  -vf "subtitles=filename='<同一目錄下的字幕檔名>'"
  <輸出檔案>

# ffmpeg hevc 軟體編碼
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libx265
  -crf 20
  -preset veryslow
  -vf "subtitles=filename='<同一目錄下的字幕檔名>'"
  <輸出檔案>

# ffmpeg av1 軟體編碼
# 目前 av1 在 macOS 除了瀏覽器，就只有VLC能播，且無硬解，暫時不建議使用
# ffmpeg 4.1.3 中 av1 依舊是實驗功能，故需加上 -strict -2
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -vcodec libaom-av1
  -b:v 0
  -crf 20
  -strict -2
  -vf "subtitles=filename='<同一目錄下的字幕檔名>'"
  <輸出檔案>

# ffmpeg h264 macos 硬體加速編碼
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -c:v h264_videotoolbox
  -profile:v <欲套用之profile(main, high, baseline)>
  -b:v <視訊流平均位元率(400k)>
  -b:a <音訊流平均位元率(128k)>
  -vf "subtitles=filename='<同一目錄下的字幕檔名>'"
  <輸出檔案>

# ffmpeg hevc macos 硬體加速編碼
# 為了給 macOS 內建預覽程式識別，必須將影片標記為 hvc1
ffmpeg
  -hide_banner
  -i <輸入檔案>
  -c:v hevc_videotoolbox
  -profile:v <欲套用之profile(main, high)>
  -b:v <視訊流平均位元率(400k)>
  -b:a <音訊流平均位元率(128k)>
  -vf "subtitles=filename='<同一目錄下的字幕檔名>'"
  -tag:v hvc1
  <輸出檔案>
```
