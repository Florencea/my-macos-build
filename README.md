# My macOS Build

## Quick Links

- [React Note](react/README.md)
- [FFmpeg Note](ffmpeg/README.md)

## Extenstion Configs

- [uBlock Origin Configs](https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/ublock-advanced.txt)
- [Violentmonkey Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/violentmonkey-backup.zip)
- [NewTongwentong Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/tongwentang-pref.json)

## macOS Commands

### Reset LaunchPad

```bash
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

### Use Touch ID for sudo Commands

```bash
sudo nano /etc/pam.d/sudo
```

- Add this at line 2

```bash
auth       sufficient     pam_tid.so
```

### Remove Quarantine Attributes

```bash
sudo xattr -r -d com.apple.quarantine <FILE>
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

- Setup "Google Chrome.app"
- Setup SSH Key

```bash
ssh-keygen -t ed25519
```

```bash
cat .ssh/id_ed25519.pub | pbcopy
```

- Setup GPG Key

```bash
gpg --full-generate-key
```

```bash
gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s") | pbcopy
```

- Import GPG Key to GitHub, GitLab or Bitbucket

```bash
git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
```

```bash
git config --global commit.gpgsign true
```

```bash
git config --global gpg.program gpg
```

```bash
printf "pinentry-program /opt/homebrew/bin/pinentry-mac\n" >> ~/.gnupg/gpg-agent.conf
```

```bash
printf "no-tty\n" >> ~/.gnupg/gpg.conf
```

```bash
killall gpg-agent
```

- Setup "Visual Studio Code.app"

## Firefox Setup

- Set DNS over HTTPS

```text
https://dns.google/dns-query
```

- Set ECS to `false`

```text
network.trr.disable-ECS
```

- Set all prefetch configs to default

```text
prefetch
```

- Devtools

```text
Mozilla/5.0 (Android 12; Mobile; rv:94.0) Gecko/94.0 Firefox/94.0
```

```text
396 x 858
```

```text
2.727272727272727
```
