#! /usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

### Use Touch ID for sudo Commands
if ! (cat /etc/pam.d/sudo | grep 'pam_tid.so'); then
  echo "Set TouchID for sudo commands"
  sudo sed -i '' '2i\
auth       sufficient     pam_tid.so\
' /etc/pam.d/sudo
else
  echo "File modefied, skip Set TouchID for sudo commands"
fi

### Install Homebrew
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew exist, skip Homebrew installation"
fi

### Install Cloudflare Warp
brew install --cask cloudflare-warp
## Remove this line after Cloudflare Warp install
exit 0

### Setup SFMono fonts
cp -R /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/
### Disable macOS popup showing accented characters when holding down a key
defaults write -g ApplePressAndHoldEnabled -bool false
### Disable Window Animations
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
### Setup git config
git config --global user.name "Florencea"
git config --global user.email "bearflorencea@gmail.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.quotepath false

### Install fish
brew install fish
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
mkdir -p "$HOME/.config/fish"
mkdir -p "$HOME/.config/fish/conf.d"
mkdir -p "$HOME/.config/fish/functions"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/conf.d/00-paths.fish.txt -o "$HOME/.config/fish/conf.d/00-paths.fish"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/conf.d/fnm.fish.txt -o "$HOME/.config/fish/conf.d/fnm.fish"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/functions/fish_prompt.fish.txt -o "$HOME/.config/fish/functions/fish_prompt.fish"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/config.fish.txt -o "$HOME/.config/fish/config.fish"

### Install essential fonts
brew install --cask font-jetbrains-mono
brew install --cask font-inter

### Install apps
brew install --cask istat-menus@6
defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"
brew install --cask 1password
brew install --cask c0re100-qbittorrent
brew install --cask microsoft-edge
brew install --cask iina
brew install --cask keka
brew install --cask kekaexternalhelper
brew install --cask logi-options+
brew install --cask visual-studio-code

### Rosetta2
/usr/sbin/softwareupdate --install-rosetta --agree-to-license

### Install cli tools
brew install bash
brew install curl
brew install ffmpeg
# Node.js
brew install fnm
eval "$(fnm env)"
fnm install --lts
fnm default lts-latest
npm config set audit false engine-strict true fund false ignore-scripts true save-exact true
brew install gcc
brew install gifski
brew install git
brew install jq
brew install mtr
brew install nano
brew install nanorc
echo "include /opt/homebrew/share/nanorc/*.nanorc" >~/.nanorc
brew install python
brew install rsync
brew install shfmt
brew install wget
brew install yt-dlp
brew install yq
brew install zsh

### Reset LaunchPad
macos_version=$(sw_vers -productVersion)
major=$(echo "$macos_version" | awk -F '.' '{print $1}')
minor=$(echo "$macos_version" | awk -F '.' '{print $2}')
if [[ $major -gt 15 || ($major -eq 15 && $minor -ge 2) ]]; then
  rm -rf /private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad
else
  defaults write com.apple.dock ResetLaunchPad -bool true
fi
killall Dock
### Clear script
rm "$0"
