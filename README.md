# My macOS build

## 其他目錄連結

- [設置 gpg](gpg.md)
- [常用 Ubuntu 指令紀錄](ubuntu-1804-cmd.md)
- [git commit rules](git-commit-rules.md)
- [ffmpeg 紀錄](ffmpeg.md)

## 重灌基本流程(適用 SSD 機種與高速網路環境)

```fish
[清除touchbar資料]
# 需使用還原磁區之終端機執行，且執行後需重開機再執行重灌，否則會錯誤
xartutil --erase-all
[系統安裝]
  ├──[install.sh]
curl -L https://git.io/florencea-macos-build-install -o install.sh;sh install.sh
  │      ├──[AppStore安裝(GarageBand與其他)]
  │      │        └──[資料拷貝(Patches)]
  │      ├──[終端機設定]
  │      ├──[Safari設定]
  │      │        └──[SSH與GPG設定]
  │      │              └──[Atom設定]
  │      └──[Atom以外App設定]
  ├──[iTunes設定]
  │       ├──[資料拷貝(Music)至音樂App中]
  │       ├──[資料拷貝(GarageBand)(或等待iCloud同步)]
  │       ├──[資料拷貝(GitHub)至家目錄]
  │       ├──[資料拷貝(Patches)至桌面]
  │       ├──[資料拷貝(文件)(或等待iCloud同步)]
  │       ├──[資料拷貝(影片)]
  ├──[系統設定]
  └──[Finder設定]
```

## 自動腳本

```fish
# DNS-over-HTTPS(安裝完成後請將系統 DNS 改為 127.0.0.1 與 ::1)
curl -L https://git.io/florencea-macos-build-doh | sh

# 取得 ublock-adv 備份
curl -L https://git.io/florencea-macos-build-ublock-adv -o ublock-adv.txt

# 製作 gif，需安裝fish與ffmpeg
curl -L https://git.io/florencea-macos-build-mkgif -o mkgif.sh;fish mkgif.sh <input_file> <from(hh:mm:ss or sec)> <during(sec)>

# 製作git.io縮網址
curl -i https://git.io -F "url=<目標網址>" -F "code=<自訂縮網址>" | grep Location

# 下載舊版macOS
curl -O https://raw.githubusercontent.com/munki/macadmin-scripts/master/installinstallmacos.py
sudo python installinstallmacos.py
```

## fish alias

```fish
nano ~/.config/fish/config.fish
alias mmb="atom ~/GitHub/my-macos-build"
alias mkgif="sh ~/GitHub/my-macos-build/make-gif.sh"
alias ubk="sh ~/GitHub/my-macos-build/ublock-backup.sh"
alias al="sh ~/GitHub/ledger/al/al.sh"
```

## macOS 指令紀錄

```fish
# 重置launchpad
defaults write com.apple.dock ResetLaunchPad -bool true
killall Dock

# 防止AdobeCreativeCloud開機啟動
sudo rm -f /Library/LaunchAgents/com.adobe.AdobeCreativeCloud.plist

# 使用TouchID驗證sudo
sudo nano /etc/pam.d/sudo
# 在第二行加入
auth       sufficient     pam_tid.so

# SSD開啟trimforce
sudo trimforce enable

# 禁用Chrome本機快取(硬碟機種適用)
defaults write com.google.Chrome DiskCacheDir -string /dev/null

# 移除macOS檔案擴展屬性(-r是遞迴的意思，為了在Safari Developer Preview移除後刪除殘餘檔案)
xattr -r -c <file or directory>
```

## humble tab config

```json
# light theme
{"options.show_top":"0","options.show_closed":"0","column.0.0":"1","column.1.0":"apps","options.auto_close":"1","open.closed":"true","options.hide_options":"1","options.show_recent":"0","options.shadow_color":"transparent","options.highlight_font_color":"#000","options.show_root":"0","options.show_devices":"0","apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","options.show_weather":"0","options.highlight_color":"#f1f1f1","options.width":"0.656","options.background_color":"#fafafa","options.font_color":"#333","options.lock":"1","options.css":"#main a{border-radius:1em;}","options.font_size":"20","options.show_apps":"1","options.show_2":"0"}

# dark theme
{"apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","column.0.0":"1","column.1.0":"apps","open.closed":"true","options.auto_close":"1","options.background_color":"#202124","options.css":"#main a{border-radius:1em;}","options.font_color":"#bec1c5","options.font_size":"20","options.hide_options":"1","options.highlight_color":"#333639","options.highlight_font_color":"#eff1f2","options.lock":"1","options.shadow_color":"transparent","options.show_2":"0","options.show_apps":"1","options.show_closed":"0","options.show_devices":"0","options.show_recent":"0","options.show_root":"0","options.show_top":"0","options.show_weather":"0","options.width":"0.656"}
```
