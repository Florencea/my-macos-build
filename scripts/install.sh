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
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

print_step "brew install zsh"
brew install zsh
brew install zsh-autosuggestions
brew install zsh-fast-syntax-highlighting
curl -L https://raw.githubusercontent.com/Florencea/my-macos-build/main/scripts/zshrc.txt -o ~/.zshrc

print_step "brew update taps"
brew tap --custom-remote --force-auto-update homebrew/cask https://mirrors.ustc.edu.cn/homebrew-cask.git
brew tap --custom-remote --force-auto-update homebrew/cask https://github.com/Homebrew/homebrew-cask
brew tap --custom-remote --force-auto-update homebrew/cask-versions https://mirrors.ustc.edu.cn/homebrew-cask-versions.git
brew tap --custom-remote --force-auto-update homebrew/cask-versions https://github.com/Homebrew/homebrew-cask-versions
brew tap --custom-remote --force-auto-update homebrew/cask-fonts https://mirrors.sustech.edu.cn/homebrew/homebrew-cask-fonts.git
brew tap --custom-remote --force-auto-update homebrew/cask-fonts https://github.com/Homebrew/homebrew-cask-fonts

print_step "brew install istat menus"
brew install istat-menus
printf "\E[0;31m"
printf "982092332@qq.com\n"
printf "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA\n"
printf "\E[0m"

print_step "brew install fonts essential"
brew install font-jetbrains-mono
brew install font-inter
cp -R /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/

print_step "brew install cask apps"
brew install --cask google-chrome
brew install --cask iina
brew install --cask keka
brew install --cask kekaexternalhelper
brew install --cask mos
brew install --cask c0re100-qbittorrent
brew install --cask visual-studio-code

print_step "brew install commend line tools"
brew install ffmpeg
brew install gcc
brew install git
brew install jq
brew install mtr
brew install mysql-client@5.7
brew install nano
brew install nanorc
echo "include /opt/homebrew/share/nanorc/*.nanorc" >>~/.nanorc
brew install node@18
printf "audit=false\nfund=false\nloglevel=error\nupdate-notifier=false\nengine-strict=true" >~/.npmrc
brew install openvpn
brew install rsync
brew install python
brew install wget
brew install yt-dlp/taps/yt-dlp

print_step "git configuations"
(
  set -x
  git config --global user.name "Florencea"
  git config --global user.email "bearflorencea@gmail.com"
  git config --global core.editor "nano"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global core.quotepath false
  git config --global core.ignorecase false
)

if [ -d "$HOME/.ssh" ]; then
  print_step "$HOME.ssh exist, skip ssh key generation"
else
  print_step "setup ssh key"
  (
    set -x
    ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat .ssh/id_ed25519.pub
  )
fi

print_step "disable eyecandy, reset launchpad & clear scripts"
(
  set -x
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
  defaults write com.apple.dock ResetLaunchPad -bool true
  defaults write -g ApplePressAndHoldEnabled -bool false
  killall Dock
  rm "$0"
)
