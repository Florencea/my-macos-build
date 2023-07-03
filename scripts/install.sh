#! /bin/bash

function print_step() {
  printf "\033[1m"
  printf "\n%s\n\n" "$1"
  printf "\033[0m"
}

print_step "set touch id for sudo commands"
sudo sed -i '' '2i\
auth       sufficient     pam_tid.so\
' /etc/pam.d/sudo

if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

print_step "system config"
(
  set -x
  cp -R /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
  defaults write -g ApplePressAndHoldEnabled -bool false
  git config --global user.name "Florencea"
  git config --global user.email "bearflorencea@gmail.com"
  git config --global core.editor "nano"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global core.quotepath false
  git config --global core.ignorecase false
)

if [ -d "$HOME/.ssh" ]; then
  print_step "$HOME/.ssh exist, skip ssh key generation"
else
  print_step "setup ssh key"
  (
    set -x
    cd "$HOME"
    ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519" && cat "$HOME/.ssh/id_ed25519.pub"
  )
fi

print_step "brew update taps"
brew tap homebrew/cask-versions
brew tap homebrew/cask-fonts

print_step "brew install fonts essential"
brew install font-jetbrains-mono
brew install font-inter

print_step "brew install zsh"
brew install zsh
brew install zsh-autosuggestions
brew install zsh-fast-syntax-highlighting
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/zshrc.txt -o "$HOME/.zshrc"

print_step "brew install fish"
brew install fish
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
mkdir -p "$HOME/.config/fish"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/config.fish.txt -o "$HOME/.config/fish/config.fish"

print_step "brew install istat menus"
brew install istat-menus
defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"

print_step "brew install cask apps"
brew install --cask google-chrome
brew install --cask iina
brew install --cask keka
brew install --cask kekaexternalhelper
brew install --cask mos
brew install --cask c0re100-qbittorrent
brew install --cask visual-studio-code

print_step "brew install commend line tools"
brew install bash
brew install curl
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
brew install node@20
printf "audit=false\nfund=false\nloglevel=error\nupdate-notifier=false\nengine-strict=true" >~/.npmrc
brew install rsync
brew install rust
brew install rustfmt
brew install python
python3 -m pip install --upgrade pip
pip3 install black
brew install wget
brew install yt-dlp/taps/yt-dlp

print_step "done, reset launchpad & clear scripts"
(
  set -x
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock
  rm "$0"
)
