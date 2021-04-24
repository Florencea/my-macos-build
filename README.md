# My macOS build

## Reset macOS

```bash
[Clear T2 chip]
# Boot from recovery (command + R)
# Open Terminal.app
xartutil --erase-all
# Clear PRROM (command + option + P + R)
# Boot from network recovery (command + option + R)
[macOS system installation]
# Open Disk Utility.app
# Clear System Volume useing APFS
[System performances config]
[Finder config]
  ├──[Music.app config]
  │       ├──[Data copy(Music) to Music.app]
  │       └──[Data copy(Others) to ~/]
  └──[install.sh]
          ├──[GarageBand installation]
          ├──[Terminal config]
          ├──[Browser config]
          │        └──[SSH&GPG config]
          │              └──[VSCode config]
          └──[Other apps config]
```

## Online scripts

```bash
# Get Ublock Origin configuations
curl -L https://github.com/Florencea/my-macos-build/raw/main/configs/ublock-advanced.txt -o ublock-advanced.txt

# Make GIF, ffmpeg required
curl -L https://github.com/Florencea/my-macos-build/raw/main/scripts/make-gif.sh -o mkgif.sh;fish mkgif.sh <input_file> <from(hh:mm:ss or sec)> <during(sec)>

# Download old macOS system images
curl -O https://raw.githubusercontent.com/munki/macadmin-scripts/master/installinstallmacos.py
sudo python installinstallmacos.py
```

## fish shell alias

```bash
nano ~/.config/fish/config.fish
alias mmb="code ~/GitHub/my-macos-build"
alias mkgif="sh ~/GitHub/my-macos-build/scripts/make-gif.sh"
alias ubk="sh ~/GitHub/my-macos-build/scripts/ublock-backup.sh"
alias ua="sh ~/GitHub/my-macos-build/scripts/update-all.sh"
alias urb="sh ~/GitHub/my-macos-build/scripts/ublock-rule-backup.sh"
alias myself-cli="sh ~/GitHub/myself-cli/myself-cli.sh"
```

## macOS commends

```bash
# SSH key generate
ssh-keygen -t ed25519
cat .ssh/id_ed25519.pub | pbcopy

# Reset Launchpad
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock

# Disable window open effects
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO

# Disable AdobeCreativeCloud on system boot
sudo rm -f /Library/LaunchAgents/com.adobe.AdobeCreativeCloud.plist

# Use TouchID for sudo commends
sudo nano /etc/pam.d/sudo
# add this on line 2
auth       sufficient     pam_tid.so
```

## Firefox DevTools configuations

```bash
# name
Pixel 4a
# user agent
Mozilla/5.0 (Android 11; Mobile; rv:88.0) Gecko/88.0 Firefox/88.0
# size
396 x 858
# DPR
2.727272727272727
```
