# My macOS build

## Reset macOS

```fish
[Clear T2 chip]
# Boot from recovery, open Terminal.app excuting xartutil, and than clear PRROM & reboot from network recovery
xartutil --erase-all
[macOS system installation]
[System Performances]
[Finder performances]
  ├──[install.sh]
curl -L https://github.com/Florencea/my-macos-build/raw/main/scripts/install.sh -o install.sh;sh install.sh
  │      ├──[GarageBand installation]
  │      ├──[Terminal performances]
  │      ├──[Browser setup]
  │      │        └──[SSH&GPG setup]
  │      │              └──[VSCode setup]
  │      └──[Apps performances]
  └──[Music performances]
          ├──[Data copy(Music) to Music.app]
          ├──[Data copy(GarageBand) to ~/]
          ├──[Data copy(GitHub) to ~/]
          ├──[Data copy(Installations) to ~/]
          └──[Data copy(Repositories) to ~/]
```

## Online scripts

```fish
# Download Google Drive public single file
curl -L https://github.com/Florencea/my-macos-build/raw/main/scripts/gdrive-download.sh -o gd.sh;sh gd.sh <ID> <downloaded file name>

# Setup DNS-over-HTTPS(change DNS to 127.0.0.1 and ::1 after installation)
curl -L https://github.com/Florencea/my-macos-build/raw/main/scripts/doh.sh | sh

# Get Ublock Origin configuations
curl -L https://github.com/Florencea/my-macos-build/raw/main/configs/ublock-advanced.txt -o ublock-advanced.txt

# Make GIF, ffmpeg required
curl -L https://github.com/Florencea/my-macos-build/raw/main/scripts/make-gif.sh -o mkgif.sh;fish mkgif.sh <input_file> <from(hh:mm:ss or sec)> <during(sec)>

# Download old macOS system images
curl -O https://raw.githubusercontent.com/munki/macadmin-scripts/master/installinstallmacos.py
sudo python installinstallmacos.py
```

## fish shell alias

```fish
nano ~/.config/fish/config.fish
alias mmb="code ~/GitHub/my-macos-build"
alias mkgif="sh ~/GitHub/my-macos-build/scripts/make-gif.sh"
alias ubk="sh ~/GitHub/my-macos-build/scripts/ublock-backup.sh"
alias al="sh ~/GitHub/ledger/al/al.sh"
alias gd="sh ~/GitHub/my-macos-build/scripts/gdrive-download.sh"
alias ua="sh ~/GitHub/my-macos-build/scripts/update-all.sh"
alias urb="sh ~/GitHub/my-macos-build/scripts/ublock-rule-backup.sh"
alias cra="sh ~/GitHub/my-macos-build/scripts/create-react-app.sh"
alias crat="sh ~/GitHub/my-macos-build/scripts/create-react-app-tailwind.sh"
```

## Firefox about:config

- Chrome UI for Firefox: [MaterialFox](https://github.com/muckSponge/MaterialFox)

```fish
# enable fission
fission.autostart true

# disable ui animations
ui.prefersReducedMotion 1
xul.panel-animations.enabled false

# enable cloudflare trr
network.trr.bootstrapAddress 104.16.248.249
network.trr.mode 3

# enable http3(warning: unstable)
network.http.http3.enabled true

# disable pockets
extensions.pocket.enabled false

# disable captivedetect
captivedetect.canonicalURL empty
network.captive-portal-service.enabled false
```

## macOS commends

```fish
# SSH key generate
ssh-keygen -t ed25519
cat .ssh/id_ed25519.pub | pbcopy

# Reset Launchpad
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock

# Disable window open effects
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO

# Disable AdobeCreativeCloud on system boot
sudo rm -f /Library/LaunchAgents/com.adobe.AdobeCreativeCloud.plist

# Parallels 16.1.1 TNT start with network
sudo -b /Applications/Parallels\ Desktop.app/Contents/MacOS/prl_client_app

# Use TouchID for sudo commends
sudo nano /etc/pam.d/sudo
# add this on line 2
auth       sufficient     pam_tid.so

# Enable TRIM for non Apple SSDs
sudo trimforce enable

# Disable Chrome local cache(recommend for hard disk machines)
defaults write com.google.Chrome DiskCacheDir -string /dev/null

# Remove macOS file extension attributes(-r means recursively, deal with delete files after Safari Technology Preview uninstallation)
xattr -r -c <file or directory>

# Rust Installation
curl https://sh.rustup.rs | sh
set -U fish_user_paths $HOME/.cargo/bin $fish_user_paths
mkdir -p ~/.config/fish/completions
# open new shell
rustup completions fish > ~/.config/fish/completions/rustup.fish
```

## humble tab config

```json
# light theme
{"options.show_top":"0","options.show_closed":"0","column.0.0":"1","column.1.0":"apps","options.auto_close":"1","open.closed":"true","options.hide_options":"1","options.show_recent":"0","options.shadow_color":"transparent","options.highlight_font_color":"#000","options.show_root":"0","options.show_devices":"0","apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","options.show_weather":"0","options.highlight_color":"#f1f1f1","options.width":"0.656","options.background_color":"#fafafa","options.font_color":"#333","options.lock":"1","options.css":"#main a{border-radius:1em;}","options.font_size":"20","options.show_apps":"1","options.show_2":"0"}

# dark theme
{"apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","column.0.0":"1","column.1.0":"apps","open.closed":"true","options.auto_close":"1","options.background_color":"#202124","options.css":"#main a{border-radius:1em;}","options.font_color":"#bec1c5","options.font_size":"20","options.hide_options":"1","options.highlight_color":"#333639","options.highlight_font_color":"#eff1f2","options.lock":"1","options.shadow_color":"transparent","options.show_2":"0","options.show_apps":"1","options.show_closed":"0","options.show_devices":"0","options.show_recent":"0","options.show_root":"0","options.show_top":"0","options.show_weather":"0","options.width":"0.656"}
```

## Firefox DevTools configuations

```fish
# name
Pixel 4a
# user agent
Mozilla/5.0 (Android 11; Mobile; rv:82.0) Gecko/82.0 Firefox/82.0
# size
396 x 858
# DPR
2.727272727272727
```
