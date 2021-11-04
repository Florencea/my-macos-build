# My macOS Build

## Quick Links

- [React Note](react/README.md)
- [Rust Note](rust/README.md)
- [FFmpeg Note](ffmpeg/README.md)

## Extenstion Configs

- [uBlock Origin Configs](https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/ublock-advanced.txt)
- [Tampermonkey Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/tampermonkey-backup.txt)
- [NewTongwentong Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/tongwentang-pref.json)

## macOS Commands

### Reset LaunchPad

```bash
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

### Disable Window Animations

```bash
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```

### Generate SSH Key

```bash
ssh-keygen -t ed25519
cat .ssh/id_ed25519.pub | pbcopy
```

### Use Touch ID for sudo Commands

```bash
sudo nano /etc/pam.d/sudo
# Add this at line 2
auth       sufficient     pam_tid.so
```

### Rust Installation

```bash
curl https://sh.rustup.rs | sh
set -U fish_user_paths $HOME/.cargo/bin $fish_user_paths
mkdir -p ~/.config/fish/completions
# Open new shell
rustup completions fish > ~/.config/fish/completions/rustup.fish
```

### Remove Quarantine Attributes

```bash
sudo xattr -r -d com.apple.quarantine <FILE>
```

## macOS Setup

- For Apple Silicon macs
- For macOS Big Sur / Monterey

### 1. Backup and logout

- <https://support.apple.com/zh-tw/HT201065>

### 2. Reinstall macOS

- <https://support.apple.com/zh-tw/HT212030>
- <https://support.apple.com/zh-tw/HT204904>

### 3. System Performance

- Privacy -> Full Disk Access, Add "Terminal.app"

### 4. Finder and Dock

### 5. Data Recovery from Backup

- Setup "Music.app"
- Import media files to "Music.app"
- Copy data to ~/

### 6. Install Apps from App Store

### 7. Execute install.sh

### 8. Setup Apps

### 9. Setup Developer tools

- Setup "Google Chrome.app"
- Setup SSH Key
- Setup GPG Key
- Setup "Visual Studio Code.app"

## macOS GPG Setup

- For Apple Silicon macs
- Requirement: gnupg, pinentry-mac

### 1. Generate GPG Key

```bash
gpg --full-generate-key
```

### 2. Export GPG Key

```bash
gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s") | pbcopy
```

### 3. Import GPG Key to GitHub, GitLab or Bitbucket

### 4. Setup Git

```bash
git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
git config --global commit.gpgsign true
git config --global gpg.program gpg
```

### 5. Setup macOS Keychain

```bash
printf "pinentry-program /opt/homebrew/bin/pinentry-mac\n" >> ~/.gnupg/gpg-agent.conf
printf "no-tty\n" >> ~/.gnupg/gpg.conf
killall gpg-agent
```

## Firefox Setup

### Use Chrome UI

- <https://github.com/muckSponge/MaterialFox>

### `about:config`

```bash
# Disable UI Animation
ui.prefersReducedMotion 1
xul.panel-animations.enabled false
# Force TRR
network.trr.mode 3
# Disable Pocket
extensions.pocket.enabled false
# Disable Reader Mode
reader.parse-on-load.enabled false
# Disable Captive Detect
captivedetect.canonicalURL empty
network.captive-portal-service.enabled false
```

### Devtools

```bash
# Device
Pixel 4a
# User Agent
Mozilla/5.0 (Android 11; Mobile; rv:92.0) Gecko/92.0 Firefox/92.0
# Screen Size
396 x 858
# DPR
2.727272727272727
```
