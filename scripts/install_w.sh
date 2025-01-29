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
### Disable Window Animations
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
### Disable macOS popup showing accented characters when holding down a key
defaults write -g ApplePressAndHoldEnabled -bool false
### Setup git config
git config --global user.name "Florencea"
git config --global user.email "bearflorencea@gmail.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.quotepath false
git config --global core.ignorecase false

### Install essential fonts
brew install --cask font-jetbrains-mono
brew install --cask font-inter

### Install fish
brew install fish
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
mkdir -p "$HOME/.config/fish"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/config.fish.txt -o "$HOME/.config/fish/config.fish"

### Install apps
brew install --cask istat-menus@6
defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"
brew install --cask c0re100-qbittorrent
brew install --cask google-chrome
brew install --cask dingtalk
brew install --cask docker
brew install --cask iina
brew install --cask keka
brew install --cask kekaexternalhelper
brew install --cask logi-options+
brew install --cask microsoft-auto-update
brew install --cask microsoft-excel
brew install --cask microsoft-powerpoint
brew install --cask microsoft-word
brew install --cask tailscale
brew install --cask visual-studio-code

### Rosetta2
/usr/sbin/softwareupdate --install-rosetta --agree-to-license

### Install cli tools
brew install bash
brew install curl
brew install ffmpeg
brew install fnm
eval "$(fnm env)"
fnm install --lts
fnm default lts-latest
printf "audit=false\nfund=false\nloglevel=error\nupdate-notifier=false\nengine-strict=true\nsave=true\n" >"$HOME/.npmrc"
printf "# fnm\nfnm env | source\nfish_add_path \"\$(npm config get prefix)/bin\"\n" >>$HOME/.config/fish/config.fish
printf "# fnm\neval \"\$(fnm env)\"\nexport PATH=\"\$(npm config get prefix)/bin:\$PATH\"\n" >>$HOME/.zshrc
brew install gcc
brew install gifski
brew install git
brew install jq
brew install mtr
brew install nano
brew install nanorc
echo "include /opt/homebrew/share/nanorc/*.nanorc" >~/.nanorc
brew install rsync
brew install python
brew install wget
brew install yt-dlp
brew install yq
brew install zsh

### Reset LaunchPad
defaults write com.apple.dock ResetLaunchPad -bool true
killall Dock
### Clear script
rm "$0"
