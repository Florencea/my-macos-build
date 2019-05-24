# My macOS build

- 常用指令紀錄

  ```fish
  # 重置launchpad
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock

  # 防止AdobeCreativeCloud開機啟動
  sudo rm -f /Library/LaunchAgents/com.adobe.AdobeCreativeCloud.plist

  # SSD開啟trimforce
  sudo trimforce enable

  # 禁用Chrome本機快取
  defaults write com.google.Chrome DiskCacheDir -string /dev/null

  # 下載舊版macOS
  curl -O https://raw.githubusercontent.com/munki/macadmin-scripts/master/installinstallmacos.py
  sudo python installinstallmacos.py

  # 製作git.io縮網址
  curl -i https://git.io -F "url=<目標網址>" -F "code=<自訂縮網址>" | grep Location
  ```

  ```fish
  # 好用macOS工具紀錄

  # google drive 命令列控制工具
  brew install gdrive
  gdrive download <雲端硬碟檔案ID>
  gdrive download -r <雲端硬碟資料夾ID>

  # mega 命令列控制工具
  brew install megatools
  megadl <mega網址>

  # youtube 下載工具
  brew install youtube-dl
  youtube-dl -F <影片ID>
  youtube-dl -f <格式碼> <影片ID>

  # 萬用音訊轉檔app
  brew cask install mediahuman-audio-converter
  ```

  ```fish
  # macOS ffmpeg參數紀錄
  # 硬體編碼使用 videotoolbox, 可用參數非常少
  # videotoolbox 使用 Intel 內顯，獨顯無用
  # 參考數據 i7-8850H, 720p h264原始檔案, av1軟編約 0.01x, hevc軟編約 0.1x, h264軟編約 5x, hevc硬編約 12x, h264硬編約 19x
  # 軟編請使用 crf 與編碼速度，而非位元率來控制品質
  # 硬編的位元率計算並不單純，可以先使用軟編計算位元率，但同位元率下硬編畫質會略差軟編(編碼速度問題)
  # crf設置部分，視覺無損(h264/hevc/av1)為(18/20/20)，一般網源為(23/24/30)，最低可看為(30/31/41)
  # 參考 https://magiclen.org/vcodec/

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

- [常用 Ubuntu 指令紀錄](ubuntu-1804-cmd.md)

- [git commit rules](git-commit-rules.md)

- hubmle tab config

  - for light color

  ```text
  {"options.show_top":"0","options.show_closed":"0","column.0.0":"1","column.1.0":"apps","options.auto_close":"1","open.closed":"true","options.hide_options":"1","options.show_recent":"0","options.shadow_color":"transparent","options.highlight_font_color":"#000","options.show_root":"0","options.show_devices":"0","apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","options.show_weather":"0","options.highlight_color":"#f1f1f1","options.width":"0.656","options.background_color":"#fafafa","options.font_color":"#333","options.lock":"1","options.css":"#main a{border-radius:1em;}","options.font_size":"20","options.show_apps":"1","options.show_2":"0"}
  ```

  - for dark color

  ```text
  {"apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","column.0.0":"1","column.1.0":"apps","open.closed":"true","options.auto_close":"1","options.background_color":"#202124","options.css":"#main a{border-radius:1em;}","options.font_color":"#bec1c5","options.font_size":"20","options.hide_options":"1","options.highlight_color":"#333639","options.highlight_font_color":"#eff1f2","options.lock":"1","options.shadow_color":"transparent","options.show_2":"0","options.show_apps":"1","options.show_closed":"0","options.show_devices":"0","options.show_recent":"0","options.show_root":"0","options.show_top":"0","options.show_weather":"0","options.width":"0.656"}
  ```

- 安裝環境自動安裝腳本

  - 精簡版(僅安裝必要軟體)

  ```bash
  curl -L https://git.io/florencea-macos-build-install -o tempsh;sh tempsh
  ```

  - 完整版腳本開頭會詢問輸入 github 使用者名稱、github 信箱、git 系統預設文字編輯器、fish shell 的問候語

  ```bash
  curl -L https://git.io/florencea-macos-build-install-full -o tempsh;sh tempsh
  ```

- DNS-over-HTTPS 自動安裝腳本(可以新建一個網路設定檔之後再執行)

  ```bash
  curl -L https://git.io/florencea-macos-build-doh | sh
  ```

  - 安裝完成後請將系統 DNS 改為`127.0.0.1`與`::1`

- 取得 ublock 備份

  - 此規則集不阻擋第三方腳本與框架，相當於訂閱了多個規則集的 ABP，但裝後不理，網站比較不會出問題

  ```bash
  curl -L https://git.io/florencea-macos-build-ublock -o ublock.txt
  ```

- 取得 ublock-adv 備份

  - 此規則集啟用進階動態過濾，以及大量自訂規則，建議手機用戶使用，能夠有效減少請求數量，但網站較有可能出問題

  ```bash
  curl -L https://git.io/florencea-macos-build-ublock-adv -o ublock-adv.txt
  ```

- 設置 gpg (詳見 [gpg.md](gpg.md))

  - 安裝 [GPG Suite](https://gpgtools.org/)

    ```fish
    brew cask install gpg-suite
    ```

  - 建立 GPG key

    ```fish
    gpg --full-generate-key

    # 請選擇你要使用的金鑰種類:
    #   (1) RSA 和 RSA (預設)
    #   (2) DSA 和 Elgamal
    #   (3) DSA (僅能用於簽署)
    #   (4) RSA (僅能用於簽署)
    你要選哪一個? 1

    # RSA 金鑰的長度可能介於 1024 位元和 4096 位元之間.
    你想要用多大的金鑰尺寸? (2048) 4096

    # 請指定這把金鑰的有效期限是多久.
    #         0 = 金鑰不會過期
    #      <n>  = 金鑰在 n 天後會到期
    #      <n>w = 金鑰在 n 週後會到期
    #      <n>m = 金鑰在 n 月後會到期
    #      <n>y = 金鑰在 n 年後會到期
    金鑰的有效期限是多久? (0) 0

    以上正確嗎? (y/N) y

    # GnuPG 需要建構使用者 ID 以識別你的金鑰.

    真實姓名: <your_name>

    電子郵件地址: <your_github_email>

    註釋:

    變更姓名(N), 註釋(C), 電子郵件地址(E)或確定(O)/退出(Q)? o
    ```

  - 設定 GPG key 的密碼

  - 輸出 GPG key

    ```fish
    gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
    ```

  - 複製完整 public key 至 github 或 gitlab

  - 在 git 中使用 GPG key

    ```fish
    git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
    git config --global commit.gpgsign true
    git config --global gpg.program gpg
    ```
