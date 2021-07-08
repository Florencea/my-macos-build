# My macOS Build

## Quick Link

- [React Note](react/README.md)
- [FFmpeg Note](ffmpeg/README.md)

## Download Link

- <a href="https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/ublock-advanced.txt" download>uBlock Origin Configuration</a>
- <a href="https://github.com/Florencea/my-macos-build/raw/main/configs/tampermonkey-backup.txt" download>Tampermonkey Configuration</a>
- <a href="https://github.com/Florencea/my-macos-build/raw/main/configs/tongwentang-pref.json" download>NewTongWenTang Configuration</a>

## macOS Reset Steps

- For Intel + T2 machines

### 1. Backup Data and Sign Out all Services

- [What to do before you sell, give away, or trade in your Mac](https://support.apple.com/en-us/HT201065)

### 2. Erase Secure Keys in T2 Chip

- [Start up from macOS Recovery](https://support.apple.com/en-us/HT201314#startup) <kbd>command</kbd> + <kbd>R</kbd>
- Open `Terminal` app in menu bar

```bash
xartutil --erase-all
```

- [Reset NVRAM or PRAM on your Mac](https://support.apple.com/en-us/HT204063) <kbd>command</kbd> + <kbd>option</kbd> + <kbd>P</kbd> + <kbd>R</kbd>
- [Start up from Network Recovery](https://support.apple.com/en-us/HT201314#internet) <kbd>command</kbd> + <kbd>option</kbd> + <kbd>R</kbd>

### 3. Reinstall macOS

- [Use Disk Utility to erase your Mac](https://support.apple.com/en-us/HT208496#erasedisk)
- [Reinstall macOS](https://support.apple.com/en-us/HT204904#reinstall)

### 4. Setup `System Preferences` app

- In `Security & Privacy -> Privacy -> Full Disk Access` add `Terminal` app and check it

### 5. Setup `Finder` app and Dock

### 6. Data Recovery from Backup

- Setup `Music` app
- Copy media to `Music` app
- Copy others to Home Directory

### 7. Install Apps from App Store

### 8. Execute `install.sh`

### 9. Setup Apps

### 10. Setup Development Environment

- Setup `Google Chrome` app
- [Setup SSH Key](#generate-ssh-key)
- [Setup GPG Key](#macos-gpg-steps)
- Setup `Visual Studio Code` app

## macOS commands

### Generate SSH Key

```bash
ssh-keygen -t ed25519
```

```bash
cat .ssh/id_ed25519.pub | pbcopy
```

### Use Touch ID for `sudo` command

```bash
sudo nano /etc/pam.d/sudo
```

- Insert at line 2

```bash
auth       sufficient     pam_tid.so
```

### Disable Window Pulse Animation

```bash
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```

### Disable Adobe Create Cloud Launch at Boot Up

```bash
sudo rm -f /Library/LaunchAgents/com.adobe.AdobeCreativeCloud.plist
```

### Reset Launchpad App Icons

```bash
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

### Rust language Installation

```bash
curl https://sh.rustup.rs | sh
```

```bash
set -U fish_user_paths $HOME/.cargo/bin $fish_user_paths
```

```bash
mkdir -p ~/.config/fish/completions
```

- Open a new shell

```bash
rustup completions fish > ~/.config/fish/completions/rustup.fish
```

## macOS GPG Steps

- `gnupg` and `pinentry-mac` are required

### 1. Generate GPG Key

```bash
gpg --full-generate-key
```

### 2. Export GPG Key

```bash
gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s") | pbcopy
```

### 3. Paste to GitHub, GitLab or Bitbucket

- GPG Key is already in clipboard

### 4. Setup Git Configuration

```bash
git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
```

```bash
git config --global commit.gpgsign true
```

```bash
git config --global gpg.program gpg
```

### 5. Save GPG Passphrase in macOS `Keychain Access` app

```bash
printf "pinentry-program /usr/local/bin/pinentry-mac\n" >> ~/.gnupg/gpg-agent.conf
```

```bash
printf "no-tty\n" >> ~/.gnupg/gpg.conf
```

```bash
killall gpg-agent
```

## macOS Firefox Config

### Chrome UI for Firefox

- <https://github.com/muckSponge/MaterialFox>

### Disable UI animations

```text
ui.prefersReducedMotion 1
```

```text
xul.panel-animations.enabled false
```

### Force Cloudflare TRR

```text
network.trr.mode 3
```

### Disable Pockets Extension

```text
extensions.pocket.enabled false
```

### Disable Reader View

```text
reader.parse-on-load.enabled false
```

### Disable Captive Detection

```text
captivedetect.canonicalURL empty
```

```text
network.captive-portal-service.enabled false
```

### Devtool Device Specification

- Device Name

```text
Pixel 4a
```

- User Agent

```text
Mozilla/5.0 (Android 11; Mobile; rv:89.0) Gecko/89.0 Firefox/89.0
```

- Screen Size

  - Width

  ```text
  396
  ```

  - Height

  ```text
  858
  ```

- DPR

```text
2.727272727272727
```
