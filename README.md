# macOS 使用筆記

- 流程與腳本為作者個人使用，不見得符合所有人的工作流程

## 快速連結

- [React 開發筆記](react/README.md)
- [FFmpeg 使用筆記](ffmpeg/README.md)
- <a href="https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/ublock-advanced.txt" download>uBlock Origin 設定檔右鍵下載</a>
- <a href="https://github.com/Florencea/my-macos-build/raw/main/configs/tampermonkey-backup.txt" download>Tampermonkey 設定檔右鍵下載</a>
- <a href="https://github.com/Florencea/my-macos-build/raw/main/configs/tongwentang-pref.json" download>新同文堂 設定檔右鍵下載</a>

## macOS 重灌流程

- 此流程適用於 Intel + T2 機型，需連網

### 步驟 0：備份/登出各帳號

- 可參考 [將 Mac 賣掉、送人或換購以前的注意事項](https://support.apple.com/zh-tw/HT201065)

### 步驟 1：清除 T2 晶片資料

- 使用 Recovery 磁區開機 <kbd>command</kbd> + <kbd>R</kbd>
- 從選單列開啟「終端機」
- 輸入 `xartutil --erase-all`
- 重新開機
- 清除 PRROM <kbd>command</kbd> + <kbd>option</kbd> + <kbd>P</kbd> + <kbd>R</kbd>
- 使用 Network Recovery 開機 <kbd>command</kbd> + <kbd>option</kbd> + <kbd>R</kbd>

### 步驟 2：安裝 macOS

- 從選單列開啟「磁碟工具程式」
- 清除欲安裝 macOS 的卷宗，使用 APFS 格式
- 正常執行安裝程式，等待安裝完成
- 安裝完成後，正常執行 macOS 初始設定

### 步驟 3：系統偏好設定

- 記得 `安全性與隱私權 -> 隱私權 -> 完全取用磁碟` 加入 `終端機` 並打勾

### 步驟 4：Finder 設定

### 步驟 5：複製檔案

- 設定 音樂 App
- 複製 音樂檔案 至 音樂 App
- 複製 其餘檔案 至 家目錄

### 步驟 6：執行 `install.sh`

- 建議此時什麼都別做，等待安裝完成

### 步驟 7：從 App Store 安裝軟體

- 安裝 Line、GarageBand 等等
- 放著 GarageBand 下載所有樂器包，約數十 GB

### 步驟 8：其餘 App 設定

- 需先經由`install.sh`安裝其餘 App

### 步驟 9：開發環境 設定

- 需先經由`install.sh`安裝瀏覽器與字型
- 設定瀏覽器，還原擴充元件設定，登入所有服務
- 設定 SSH 與 GPG
  - 生成 SSH Key，更新各服務的金鑰
  - 生成 GPG Key，更新各服務的金鑰
- 最後，確認 Git, SSH, GPG 設定完成後，設定 Visual Studio Code

## macOS 命令列

### 生成 SSH Key

```bash
ssh-keygen -t ed25519
```

```bash
cat .ssh/id_ed25519.pub | pbcopy
```

### 使用 Touch ID 代替 sudo 時的密碼輸入

```bash
sudo nano /etc/pam.d/sudo
```

- 在第 2 行加入

```bash
auth       sufficient     pam_tid.so
```

### 禁用 視窗彈出動畫

```bash
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```

### 禁用 Adobe Create Cloud 開機啟動

```bash
sudo rm -f /Library/LaunchAgents/com.adobe.AdobeCreativeCloud.plist
```

### 重置 Launchpad

```bash
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

## macOS GPG 設定步驟

- 需安裝`gnupg`與`pinentry-mac`

### 生成 GPG Key

```bash
gpg --full-generate-key
```

### 輸出 GPG Key

```bash
gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s") | pbcopy
```

### 拷貝至各平台

- 將已拷貝至剪貼簿的 GPG Key 貼到 GitHub、GitLab、Bitbucket

### 設定 Git 使用 GPG

```bash
git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
```

```bash
git config --global commit.gpgsign true
```

```bash
git config --global gpg.program gpg
```

### 設定 macOS 系統鑰匙圈紀錄 GPG 密碼

```bash
printf "pinentry-program /usr/local/bin/pinentry-mac\n" >> ~/.gnupg/gpg-agent.conf
```

```bash
printf "no-tty\n" >> ~/.gnupg/gpg.conf
```

```bash
killall gpg-agent
```

## macOS Firefox 開發者工具裝置模擬設定檔備份

```bash
# 裝置名稱
Pixel 4a
# user agent
Mozilla/5.0 (Android 11; Mobile; rv:88.0) Gecko/88.0 Firefox/88.0
# 螢幕尺寸
396 x 858
# DPR
2.727272727272727
```
