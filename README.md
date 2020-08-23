# My macOS build

## Reset macOS

```fish
[Clear T2 chip]
# Boot from recovery, open Terminal.app excuting xartutil, and than clear PRROM & reboot from network recovery
xartutil --erase-all
[macOS system installation]
[Disable SIP]
# Boot from recovery
csrutil disable
[System Performances(Remember to give full persission to Terminal.app)]
[Finder performances]
  ├──[install.sh]
curl -L https://git.io/florencea-install -o install.sh;sh install.sh
  │      ├──[GarageBand installation]
  │      ├──[Terminal performances]
  │      ├──[Browser performances]
  │      │        └──[SSH&GPG setup]
  │      │              └──[Atom setup]
  │      └──[Apps performances]
  │               └──[Photoshop & parallels installation]
  └──[Music performances]
          ├──[Data copy(Music) to Music.app]
          ├──[Data copy(GarageBand) to ~/]
          ├──[Data copy(GitHub) to ~/]
          ├──[Data copy(Installations) to ~/]
          └──[Data copy(Repositories) to ~/]
```

## Scripts

```fish
# Download Google Drive public single file
curl -L https://git.io/florencea-gd -o gd.sh;sh gd.sh <ID> <downloaded file name>

# Setup DNS-over-HTTPS(change DNS to 127.0.0.1 and ::1 after installation)
curl -L https://git.io/florencea-doh | sh

# Get Ublock Origin configuations
curl -L https://git.io/florencea-ublock-advanced -o ublock-advanced.txt

# Make GIF, ffmpeg required
curl -L https://git.io/florencea-mkgif -o mkgif.sh;fish mkgif.sh <input_file> <from(hh:mm:ss or sec)> <during(sec)>

# Make git.io short URLs
curl -i https://git.io -F "url=<target URL>" -F "code=<shorten URL>" | grep Location

# Download old macOS system images
curl -O https://raw.githubusercontent.com/munki/macadmin-scripts/master/installinstallmacos.py
sudo python installinstallmacos.py
```

## fish shell alias

```fish
nano ~/.config/fish/config.fish
alias mmb="atom ~/GitHub/my-macos-build"
alias mkgif="sh ~/GitHub/my-macos-build/scripts/make-gif.sh"
alias ubk="sh ~/GitHub/my-macos-build/scripts/ublock-backup.sh"
alias al="sh ~/GitHub/ledger/al/al.sh"
alias gd="sh ~/GitHub/my-macos-build/scripts/gdrive-download.sh"
alias ua="sh ~/GitHub/my-macos-build/scripts/update-all.sh"
```

## Firefox about:config

- Chrome UI for Firefox: [MaterialFox](https://github.com/muckSponge/MaterialFox)

```fish
# enable fission
fission.autostart true

# disable ui animations
ui.prefersReducedMotion 1
xul.panel-animations.enabled false

# enable webrender
gfx.webrender.all true
gfx.webrender.compositor true

# enable trr
network.trr.bootstrapAddress 104.16.248.249
network.trr.mode 3

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
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
set -U fish_user_paths $HOME/.cargo/bin $fish_user_paths
mkdir -p ~/.config/fish/completions
rustup completions fish > ~/.config/fish/completions/rustup.fish

# CCLS header completions in macOS 10.15
csrutil disable
xcode-select --install
cd /usr/
sudo mount -uw /
sudo ln -s /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include include
sudo DevToolsSecurity -enable

# Solving error for Atom package clang-format
atom .atom/packages/atom-beautify/src/beautifiers/clang-format.coffee
# find line 84
return @exe("clang-format").run([ @dumpToFile(dumpFile, text) ["--style=file"] ]).finally( -> fs.unlink(dumpFile) )
# change to
return @exe("clang-format").run([ @dumpToFile(dumpFile, text) ["--style=file"] ]).finally( -> fs.unlink(dumpFile, ->) )

# Solving error for Atom package beautysh
atom .atom/packages/atom-beautify/src/beautifiers/beautysh.coffee
# find line 35
beautysh.run([ '-t', '-f', file ])
# change to
beautysh.run([ '-t', file ])
# find line 38
beautysh.run([ '-i', options.indent_size, '-f', file ])
# change to
beautysh.run([ '-i', options.indent_size, file ])
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
Nokia 7 plus
# user agent
Mozilla/5.0 (Android 10; Mobile; rv:79.0) Gecko/79.0 Firefox/79.0
# size
414 x 828
# DPR
2.608695652173913
```
