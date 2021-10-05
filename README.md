# My macOS Build

## 快速連結

- [React 開發筆記](react/README.md)
- [Rust 開發筆記](rust/README.md)
- [FFmpeg 使用筆記](ffmpeg/README.md)

## 右鍵下載

- [uBlock Origin 設定檔](https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/ublock-advanced.txt)
- [Tampermonkey 設定檔](https://github.com/Florencea/my-macos-build/raw/main/configs/tampermonkey-backup.txt)
- [新同文堂 設定檔](https://github.com/Florencea/my-macos-build/raw/main/configs/tongwentang-pref.json)

## macOS 指令

### 重新排列 LaunchPad

```bash
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

### 禁用視窗彈出動畫

```bash
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```

### 生成 SSH Key

```bash
ssh-keygen -t ed25519
cat .ssh/id_ed25519.pub | pbcopy
```

### 使用 Touch ID 取代密碼驗證 sudo 指令

```bash
sudo nano /etc/pam.d/sudo
# 在第 2 行加入
auth       sufficient     pam_tid.so
```

### 安裝 Rust 工具鏈

```bash
curl https://sh.rustup.rs | sh
set -U fish_user_paths $HOME/.cargo/bin $fish_user_paths
mkdir -p ~/.config/fish/completions
# 打開新的終端機視窗
rustup completions fish > ~/.config/fish/completions/rustup.fish
```

## macOS 重設步驟

- 適用於 Apple Silicon 機型
- 適用 macOS Big Sur

### 1. 備份所有資料，登出所有服務

- [將 Mac 賣掉、送人或換購以前的注意事項](https://support.apple.com/zh-tw/HT201065)

### 2. 重新安裝 macOS

- [如何清除配備 Apple 晶片的 Mac](https://support.apple.com/zh-tw/HT212030)
- [如何重新安裝 macOS](https://support.apple.com/zh-tw/HT204904)

### 3. 系統偏好設定

- 「安全性與隱私權 -> 隱私權 -> 完全取用磁碟」 加入「終端機」並打勾

### 4. Finder 與 Dock 設定

### 5. 自備份回復資料

- 設定 「音樂」
- 將音樂檔案拷貝至 「音樂」
- 將其餘檔案拷貝至家目錄

### 6. 自 App Store 安裝 App

### 7. 執行 install.sh

### 8. 各 App 設定

### 9. 開發環境設定

- 設定 「Google Chrome」
- 設定 SSH Key
- 設定 GPG Key
- 設定 「Visual Studio Code」

## macOS GPG 設定

- 適用 Apple Silicon 機型
- 需安裝 「gnupg」 與 「pinentry-mac」

### 1. 生成 GPG Key

```bash
gpg --full-generate-key
```

### 2. 匯出 GPG Key(指令已將 Key 複製至剪貼板)

```bash
gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s") | pbcopy
```

### 3. 將匯出的 GPG Key 輸入到 GitHub, GitLab 或 Bitbucket

### 4. 設定 Git 使用 GPG

```bash
git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
git config --global commit.gpgsign true
git config --global gpg.program gpg
```

### 5. 設定「鑰匙圈存取」使用 GPG Key

```bash
printf "pinentry-program /opt/homebrew/bin/pinentry-mac\n" >> ~/.gnupg/gpg-agent.conf
printf "no-tty\n" >> ~/.gnupg/gpg.conf
killall gpg-agent
```

## Firefox 設定

### 在 Firefox 使用 Chrome UI

- <https://github.com/muckSponge/MaterialFox>

### about:config

```bash
# 禁用 UI 動畫
ui.prefersReducedMotion 1
xul.panel-animations.enabled false
# 強制使用 TRR
network.trr.mode 3
# 禁用 Pocket
extensions.pocket.enabled false
# 禁用閱讀器模式
reader.parse-on-load.enabled false
# 禁用網路狀態偵測
captivedetect.canonicalURL empty
network.captive-portal-service.enabled false
```

### 開發者工具行動裝置設定

```bash
# 裝置名稱
Pixel 4a
# 使用者代理
Mozilla/5.0 (Android 11; Mobile; rv:90.0) Gecko/90.0 Firefox/90.0
# 螢幕尺寸
396 x 858
# DPR
2.727272727272727
```
