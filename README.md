# My macOS build

## 目錄連結

- [設置 gpg](gpg.md)
- [常用 Ubuntu 指令紀錄](ubuntu-1804-cmd.md)
- [git commit rules](git-commit-rules.md)
- [ffmpeg 紀錄](ffmpeg.md)

## humble tab config

- for light color

```text
{"options.show_top":"0","options.show_closed":"0","column.0.0":"1","column.1.0":"apps","options.auto_close":"1","open.closed":"true","options.hide_options":"1","options.show_recent":"0","options.shadow_color":"transparent","options.highlight_font_color":"#000","options.show_root":"0","options.show_devices":"0","apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","options.show_weather":"0","options.highlight_color":"#f1f1f1","options.width":"0.656","options.background_color":"#fafafa","options.font_color":"#333","options.lock":"1","options.css":"#main a{border-radius:1em;}","options.font_size":"20","options.show_apps":"1","options.show_2":"0"}
```

- for dark color

```text
{"apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","column.0.0":"1","column.1.0":"apps","open.closed":"true","options.auto_close":"1","options.background_color":"#202124","options.css":"#main a{border-radius:1em;}","options.font_color":"#bec1c5","options.font_size":"20","options.hide_options":"1","options.highlight_color":"#333639","options.highlight_font_color":"#eff1f2","options.lock":"1","options.shadow_color":"transparent","options.show_2":"0","options.show_apps":"1","options.show_closed":"0","options.show_devices":"0","options.show_recent":"0","options.show_root":"0","options.show_top":"0","options.show_weather":"0","options.width":"0.656"}
```

## macOS 指令紀錄

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
```

## macOS 工具紀錄

```fish
# 安裝rust
curl https://sh.rustup.rs -sSf | sh

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

# 下載舊版macOS
curl -O https://raw.githubusercontent.com/munki/macadmin-scripts/master/installinstallmacos.py
sudo python installinstallmacos.py

# 製作git.io縮網址
curl -i https://git.io -F "url=<目標網址>" -F "code=<自訂縮網址>" | grep Location
```

## 安裝環境自動安裝腳本

- 精簡版

```fish
curl -L https://git.io/florencea-macos-build-install -o tempsh;sh tempsh
```

- 完整版腳本開頭會詢問輸入 github 使用者名稱、github 信箱、git 系統預設文字編輯器、fish shell 的問候語

```fish
curl -L https://git.io/florencea-macos-build-install-full -o tempsh;sh tempsh
```

- DNS-over-HTTPS 自動安裝腳本(可以新建一個網路設定檔之後再執行)

```fish
curl -L https://git.io/florencea-macos-build-doh | sh
# 安裝完成後請將系統 DNS 改為 127.0.0.1 與 ::1
```

- 取得 ublock 備份(不阻擋第三方腳本與框架，相當於訂閱了多個規則集的 ABP，裝後不理，網站比較不會出問題)

```fish
curl -L https://git.io/florencea-macos-build-ublock -o ublock.txt
```

- 取得 ublock-adv 備份(啟用進階動態過濾，大量自訂規則，建議手機使用，有效減少請求數量，網站較有可能出問題)

```fish
curl -L https://git.io/florencea-macos-build-ublock-adv -o ublock-adv.txt
```

## 重灌基本流程(適用 SSD 機種與高速網路環境)

```fish
[系統安裝]
  ├──[install.sh]
  │      ├──[istatMenus設定]
  │      ├──[終端機設定]
  │      └──[App Store安裝]
  │               ├──[Chrome設定]
  │               │       ├──[SSH設定]
  │               │       │     └──[GPG設定]
  │               │       │           └──[其餘App設定]
  │               │       └──[DNS設定]
  │               └──[GarageBand安裝]
  │                         └──[資料拷貝(Patches)]
  ├──[iTunes設定]
  │       └──[資料拷貝(Music)]
  │               ├──[資料拷貝(文件)]
  │               ├──[資料拷貝(影片)]
  │               ├──[資料拷貝(下載項目)]
  │               └──[資料拷貝(Patches)至桌面]
  ├──[系統設定]
  └──[Finder設定]
```
