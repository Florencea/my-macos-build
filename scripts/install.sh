#! /bin/bash

if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

function print_step() {
  printf "\E[1;36m"
  printf "\n + %s\n\n" "$1"
  printf "\E[0m"
}

# git
github_username="Florencea"
github_email="bearflorencea@gmail.com"
github_editor="nano"
# config
script_dir="~/GitHub/my-macos-build"
script_path="$script_dir/scripts"
# brew
brew_dir="/opt/homebrew"
brew_path="$brew_dir/bin"
brew_system_path="$brew_dir/sbin"

print_step "brew install fish"
brew install fish
echo "$brew_path/fish" | sudo tee -a /etc/shells
chsh -s $brew_path/fish
mkdir -p ~/.config/fish
{
  printf "set -g -x PATH $brew_path \$PATH\n"
  printf "set -g fish_user_paths $brew_system_path \$fish_user_paths\n"
  printf "set -g -x fish_greeting\n"
  printf "alias mmb=\"code $script_dir\"\n"
  printf "alias mkgif=\"sh $script_path/make-gif.sh\"\n"
  printf "alias ebk=\"sh $script_path/extension-config-backup.sh\"\n"
  printf "alias urb=\"sh $script_path/ublock-rule-backup.sh\"\n"
  printf "alias ua=\"sh $script_path/update-all.sh\"\n"
  printf "alias rec=\"sh $script_path/re-encode.sh\"\n"
} >>~/.config/fish/config.fish

print_step "brew install istat menus"
brew install istat-menus
printf "\E[0;31m"
printf "982092332@qq.com\n"
printf "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA\n"
printf "\E[0m"

print_step "brew install fonts essential"
brew install homebrew/cask-fonts/font-jetbrains-mono
brew install homebrew/cask-fonts/font-inter
brew install homebrew/cask-fonts/font-new-york

print_step "brew install cask apps"
brew install --cask google-chrome
brew install --cask iina
brew install --cask keka
brew install --cask kekaexternalhelper
brew install --cask mos
brew install --cask visual-studio-code

print_step "brew install commend line tools"
brew install ffmpeg
brew install gcc
brew install git
brew install jq
brew install mkcert
brew install nano
brew install node
brew install rsync
brew install python
brew install wget
brew install yarn
brew install yt-dlp/taps/yt-dlp

print_step "git configuations"
(
  set -x
  git config --global user.name "$github_username"
  git config --global user.email "$github_email"
  git config --global core.editor "$github_editor"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global core.quotepath false
)

print_step "disable eyecandy, reset launchpad & clear scripts"
(
  set -x
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock
  rm "$0"
)
