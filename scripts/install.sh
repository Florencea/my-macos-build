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
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# git
github_username="Florencea"
github_email="bearflorencea@gmail.com"
github_editor="nano"
# config
script_dir="~/Codespaces/my-macos-build"
script_path="$script_dir/scripts"
# brew
brew_dir="/opt/homebrew"
brew_path="$brew_dir/bin"
brew_system_path="$brew_dir/sbin"

print_step "brew install zsh"
brew install zsh
brew install zsh-autosuggestions
brew install zsh-fast-syntax-highlighting
curl -L https://raw.githubusercontent.com/Florencea/my-macos-build/main/scripts/zshrc.txt -o ~/.zshrc

print_step "brew update taps"
brew tap homebrew/cask
brew tap homebrew/cask-fonts
brew tap homebrew/cask-versions

print_step "brew install istat menus"
brew install istat-menus
printf "\E[0;31m"
printf "982092332@qq.com\n"
printf "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA\n"
printf "\E[0m"

print_step "brew install fonts essential"
brew install font-sf-pro
brew install font-new-york
cp -R /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/

print_step "brew install cask apps"
brew install --cask google-chrome
brew install --cask iina
brew install --cask keka
brew install --cask kekaexternalhelper
brew install --cask mos
brew install --cask c0re100-qbittorrent
brew install --cask visual-studio-code
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

print_step "brew install commend line tools"
brew install ffmpeg
brew install gcc
brew install git
brew install jq
brew install mtr
brew install nano
brew install nanorc
echo "include /opt/homebrew/share/nanorc/*.nanorc" >>~/.nanorc
brew install openvpn
brew install rsync
brew install python
brew install wget
brew install yt-dlp/taps/yt-dlp

print_step "setup nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
echo "lts/*" >~/.nvmrc
echo "audit=false\nfund=false\nloglevel=error\nupdate-notifier=false\nengine-strict=true" >~/.npmrc

print_step "git configuations"
(
  set -x
  git config --global user.name "$github_username"
  git config --global user.email "$github_email"
  git config --global core.editor "$github_editor"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global core.quotepath false
  git config --global core.ignorecase false
)

print_step "setup ssh key"

(
  set -x
  ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat .ssh/id_ed25519.pub
)

print_step "disable eyecandy, reset launchpad & clear scripts"
(
  set -x
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock
  rm "$0"
)
