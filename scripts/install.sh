#! /bin/bash

function print_step() {
  NOW="$(date +"%Y-%m-%d %H:%M:%S")"
  printf "\033[1m"
  printf "\n[$NOW] %s\n\n" "$1"
  printf "\033[0m"
}

if ! (cat /etc/pam.d/sudo | grep 'pam_tid.so'); then
  print_step "Set TouchID for sudo commands"
  sudo sed -i '' '2i\
auth       sufficient     pam_tid.so\
' /etc/pam.d/sudo
else
  print_step "File modefied, skip Set TouchID for sudo commands"
fi

if ! command -v brew &>/dev/null; then
  print_step "Install Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  print_step "Homebrew exist, skip Homebrew installation"
fi

print_step "Setup SFMono Fonts"
(
  set -x
  cp -R /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/
)

print_step "Disable window animation"
(
  set -x
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
)

print_step "Disable press and hold"
(
  set -x
  defaults write -g ApplePressAndHoldEnabled -bool false
)

print_step "Write git config"
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
  print_step "$HOME/.ssh exist, skip ssh key generation"
else
  print_step "Setup ssh key"
  (
    set -x
    cd "$HOME"
    ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519" && cat "$HOME/.ssh/id_ed25519.pub"
  )
fi

print_step "Brew update taps: homebrew/cask-versions"
brew tap homebrew/cask-versions

print_step "Brew update taps: homebrew/cask-fonts"
brew tap homebrew/cask-fonts

print_step "Brew install fonts: font-sf-mono-for-powerline"
brew install --cask font-sf-mono-for-powerline

print_step "Brew install fonts: font-inter"
brew install --cask font-inter

print_step "Brew install shell: zsh"
brew install zsh
print_step "Brew install shell: zsh-autosuggestions"
brew install zsh-autosuggestions
print_step "Brew install shell: zsh-fast-syntax-highlighting"
brew install zsh-fast-syntax-highlighting
print_step "Write .zshrc"
(
  set -x
  curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/zshrc.txt -o "$HOME/.zshrc"
)

print_step "Brew install shell: fish"
brew install fish
print_step "Brew install shell: add fish to shell list"
(
  set -x
  echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
)
print_step "Brew install shell: set fish as default shell"
(
  set -x
  chsh -s /opt/homebrew/bin/fish
)
print_step "Write $HOME/.config/fish/config.fish"
(
  set -x
  mkdir -p "$HOME/.config/fish"
  curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/config.fish.txt -o "$HOME/.config/fish/config.fish"
)

print_step "Brew install cask apps: istat-menus"
brew install --cask istat-menus
defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"

print_step "Brew install cask apps: google-chrome"
brew install --cask google-chrome
print_step "Brew install cask apps: iina"
brew install --cask iina
print_step "Brew install cask apps: keka"
brew install --cask keka
print_step "Brew install cask apps: kekaexternalhelper"
brew install --cask kekaexternalhelper
print_step "Brew install cask apps: mos"
brew install --cask mos
print_step "Brew install cask apps: c0re100-qbittorrent"
brew install --cask c0re100-qbittorrent
print_step "Brew install cask apps: visual-studio-code"
brew install --cask visual-studio-code

print_step "Brew install cli tools: bash"
brew install bash
print_step "Brew install cli tools: curl"
brew install curl
print_step "Brew install cli tools: ffmpeg"
brew install ffmpeg
print_step "Brew install cli tools: gcc"
brew install gcc
print_step "Brew install cli tools: git"
brew install git
print_step "Brew install cli tools: git-lfs"
brew install git-lfs
git lfs install
print_step "Brew install cli tools: jq"
brew install jq
print_step "Brew install cli tools: mtr"
brew install mtr
print_step "Brew install cli tools: nano"
brew install nano
print_step "Brew install cli tools: nanorc"
brew install nanorc
echo "include /opt/homebrew/share/nanorc/*.nanorc" >~/.nanorc
print_step "Brew install cli tools: node@18"
brew install node@18
printf "audit=false\nfund=false\nloglevel=error\nupdate-notifier=false\nengine-strict=true" >~/.npmrc
print_step "Brew install cli tools: rsync"
brew install rsync
print_step "Brew install cli tools: python"
brew install python
python3 -m pip install --upgrade pip
print_step "Brew install cli tools: wget"
brew install wget
print_step "Brew install cli tools: yt-dlp"
brew install yt-dlp/taps/yt-dlp

print_step "Reset launchpad"
(
  set -x
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock
)

print_step "fish: update completion"
printf "Please execute commands below:\n"
printf "\nfish_update_completions\n"

print_step "Clear Install Script"
(
  set -x
  rm "$0"
)
