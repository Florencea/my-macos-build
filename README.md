# My macOS Build

## Quick Links

- [Next.js Note](NOTE_NEXTJS.md)
- [Vite Note](NOTE_VITEJS.md)
- [UmiJS Note](NOTE_UMIJS.md)
- [FFmpeg Note](NOTE_FFMPEG.md)
- [Iceraven Note](NOTE_ICERAVEN.md)

## Extenstion Configs

- [uBlock Origin Configs](https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/ublock-advanced.txt)
- [Violentmonkey Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/violentmonkey-backup.zip)

## macOS Commands

### Reset LaunchPad

```bash
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

### Use Touch ID for sudo Commands

```bash
sudo sed -i '' '2i\
auth       sufficient     pam_tid.so\
' /etc/pam.d/sudo
```

## macOS Setup

- For Apple Silicon and macOS 12

### 1. Logout Browsers and Reinstall macOS

- <https://support.apple.com/zh-tw/HT212749>

### 2. System Performance

- Privacy -> Full Disk Access, Add "Terminal.app"

### 3. Finder and Dock

### 4. Data Recovery from Backup

- Setup "Music.app"
- Import media files to "Music.app"
- Copy data to ~/

### 5. Install Apps from App Store

### 6. Execute install.sh

### 7. Setup Apps

### 8. Setup Developer tools

- Setup SSH Key

```bash
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat .ssh/id_ed25519.pub | pbcopy
```

- Setup "Visual Studio Code.app"

## Firefox Devtools

```text
Mozilla/5.0 (Android 12; Mobile; rv:94.0) Gecko/94.0 Firefox/94.0
```

```text
396 x 858
```

```text
2.727272727272727
```
