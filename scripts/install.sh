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

### Set Default DNS Servers
services=$(networksetup -listallnetworkservices | grep 'Wi-Fi\|Ethernet\|USB')
while read -r service; do
  echo "Setting Google DNS for $service"
  networksetup -setdnsservers "$service" empty
  networksetup -setdnsservers "$service" '8.8.8.8' '8.8.4.4' '2001:4860:4860::8888' '2001:4860:4860::8844'
done <<<"$services"

### Install Homebrew
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew exist, skip Homebrew installation"
fi

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

### Update Homebrew taps
brew tap homebrew/cask-versions
brew tap homebrew/cask-fonts

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
brew install --cask istat-menus
defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"
brew install --cask google-chrome
brew install --cask iina
brew install --cask keka
brew install --cask kekaexternalhelper
brew install --cask c0re100-qbittorrent
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
printf "audit=false\nfund=false\nupdate-notifier=false\nengine-strict=true\nsave=true\n" >"$HOME/.npmrc"
printf "# fnm\nfnm env | source\nfish_add_path \"\$(npm config get prefix)/bin\"\n" >>$HOME/.config/fish/config.fish
printf "# fnm\neval \"\$(fnm env)\"\nexport PATH=\"\$(npm config get prefix)/bin:\$PATH\"\n" >>$HOME/.zshrc
export PATH="$(npm config get prefix)/bin:$PATH"
npm install --audit false --fund false --loglevel error --progress false --global true npm
npm doctor
corepack enable
corepack prepare pnpm@latest --activate
pnpm install-completion fish &>/dev/null
pnpm install-completion zsh &>/dev/null
brew install gcc
brew install git
brew install jq
brew install mtr
brew install nano
brew install nanorc
echo "include /opt/homebrew/share/nanorc/*.nanorc" >~/.nanorc
brew install rsync
brew install python
python3 -m pip install --upgrade pip
brew install wget
brew install yt-dlp/taps/yt-dlp
brew install yq
brew install zsh

### Reset LaunchPad
defaults write com.apple.dock ResetLaunchPad -bool true
killall Dock
### Clear script
rm "$0"
