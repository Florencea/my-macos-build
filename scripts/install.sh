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
git config --global diff.lockb.textconv bun
git config --global diff.lockb.binary true

### Generate SSH Key
if [ -d "$HOME/.ssh" ]; then
  echo "$HOME/.ssh exist, skip ssh key generation"
else
  cd "$HOME"
  ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519" && cat "$HOME/.ssh/id_ed25519.pub"
fi

### Update Homebrew taps
brew tap homebrew/cask-versions
brew tap homebrew/cask-fonts

### Install essential fonts
brew install --cask font-jetbrains-mono
brew install --cask font-inter

### Install zsh
brew install zsh
brew install zsh-autosuggestions
brew install zsh-fast-syntax-highlighting
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/zshrc.txt -o "$HOME/.zshrc"

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
brew install --cask mos
brew install --cask c0re100-qbittorrent
brew install --cask visual-studio-code

### Install cli tools
brew install bash
brew tap oven-sh/bun
brew install bun
brew install curl
brew install deno
brew install ffmpeg
brew install gcc
brew install git
brew install git-lfs
git lfs install
brew install jq
brew install mtr
brew install nano
brew install nanorc
echo "include /opt/homebrew/share/nanorc/*.nanorc" >~/.nanorc
brew install fnm
eval "$(fnm env)"
fnm install --lts
fnm default lts-latest
printf "audit=false\nfund=false\nloglevel=error\nupdate-notifier=false\nengine-strict=true\nsave=true\n" >"$HOME/.npmrc"
brew install rsync
brew install python
python3 -m pip install --upgrade pip
brew install wget
brew install yt-dlp/taps/yt-dlp
brew install yq

### Install colima
brew install colima
brew install docker
brew install docker-compose
if [ -d "$HOME/.colima/_templates/default.yaml" ]; then
  echo "$HOME/.colima/_templates/default.yaml exist, skip template generation"
else
  colima template --editor ls
  yq -i '.cpu=8 | .memory=8 | .arch="aarch64" | .network.dns|=["8.8.8.8", "8.8.4.4"] | .vmType="vz" | .rosetta=true | .mountType="virtiofs"' "$HOME/.colima/_templates/default.yaml"
fi

### Install rust toolchain
if ! command -v rustup-init &>/dev/null; then
  brew install rustup-init
  rustup-init -y --no-modify-path
else
  echo "rustup-init exist, skip Rust installation"
fi

### Install Rosetta2
/usr/bin/pgrep -q oahd && echo "rosetta2 exist, skip installation" || /usr/sbin/softwareupdate --install-rosetta --agree-to-license

### Reset LaunchPad
defaults write com.apple.dock ResetLaunchPad -bool true
killall Dock
### Clear script
rm "$0"
