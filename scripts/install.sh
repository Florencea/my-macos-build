#! /bin/bash
function print_step() {
  printf "\E[1;36m"
  printf "\n + %s\n\n" "$1"
  printf "\E[0m"
}

github_username="Florencea"
github_email="bearflorencea@gmail.com"
github_editor="nano"

print_step "setup SF Mono Fonts"
(
  set -x
  cp -R /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/
)

print_step "download New York Fonts"
(
  set -x
  curl -o ~/Downloads/NY-font.dmg 'https://devimages-cdn.apple.com/design/resources/download/NY-Font.dmg'
)

print_step "install homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
brew tap homebrew/core
brew tap homebrew/cask
brew tap homebrew/cask-versions
brew tap homebrew/cask-fonts
brew tap homebrew/cask-drivers

print_step "brew install istat menus"
brew install istat-menus
printf "\E[0;31m"
printf "982092332@qq.com\n"
printf "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA\n"
printf "\E[0m"

print_step "brew install cask fonts essential"
brew install font-jetbrains-mono
brew install font-inter

# # for Intel Macs
# print_step "brew install fish"
# brew install fish
# echo '/usr/local/bin/fish' | sudo tee -a /etc/shells
# chsh -s /usr/local/bin/fish
# mkdir -p ~/.config/fish
# {
#   printf "set -g -x PATH /usr/local/bin \$PATH\n"
#   printf "set -g fish_user_paths /usr/local/sbin \$fish_user_paths\n"
#   printf "set -g -x fish_greeting\n"
#   printf "alias mmb=\"code ~/GitHub/my-macos-build\"\n"
#   printf "alias mkgif=\"sh ~/GitHub/my-macos-build/scripts/make-gif.sh\"\n"
#   printf "alias ebk=\"sh ~/GitHub/my-macos-build/scripts/extension-config-backup.sh\"\n"
#   printf "alias ua=\"sh ~/GitHub/my-macos-build/scripts/update-all.sh\"\n"
#   printf "alias urb=\"sh ~/GitHub/my-macos-build/scripts/ublock-rule-backup.sh\"\n"
#   printf "alias fa=\"sh ~/GitHub/my-macos-build/scripts/git-fetch-all.sh\"\n"
# } >>~/.config/fish/config.fish

print_step "brew install fish"
brew install fish
echo '/opt/homebrew/bin/fish' | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
mkdir -p ~/.config/fish
{
  printf "set -g -x PATH /opt/homebrew/bin \$PATH\n"
  printf "set -g fish_user_paths /opt/homebrew/sbin \$fish_user_paths\n"
  printf "set -g -x fish_greeting\n"
  printf "alias mmb=\"code ~/GitHub/my-macos-build\"\n"
  printf "alias mkgif=\"sh ~/GitHub/my-macos-build/scripts/make-gif.sh\"\n"
  printf "alias ebk=\"sh ~/GitHub/my-macos-build/scripts/extension-config-backup.sh\"\n"
  printf "alias ua=\"sh ~/GitHub/my-macos-build/scripts/update-all.sh\"\n"
  printf "alias urb=\"sh ~/GitHub/my-macos-build/scripts/ublock-rule-backup.sh\"\n"
  printf "alias fa=\"sh ~/GitHub/my-macos-build/scripts/git-fetch-all.sh\"\n"
} >>~/.config/fish/config.fish

print_step "brew install cask apps"
brew install google-chrome
brew install iina
brew install keka
brew install kekaexternalhelper
brew install c0re100-qbittorrent
brew install scroll-reverser
brew install visual-studio-code

# print_step "brew install custom apps (for proper development)"
# # microsoft office
# brew install microsoft-office
# # mongodb
# brew tap mongodb/brew
# brew install mongodb-community@5.0
# brew install mongodb-compass
# # redis
# brwe install redis
# # mysql
# brew install mysql@5.7
# brew install mysqlworkbench

print_step "brew install commend line tools"
brew install annie
brew install ffmpeg
brew install gcc
brew install git
brew install git-lfs
brew install gnupg
brew install id3v2
brew install jq
brew install megatools
brew install mkcert
brew install mtr
brew install nano
brew install node
brew install nss
brew install rsync
brew install pinentry-mac
brew install python3
brew install wget
brew install yarn
brew install youtube-dl
brew install yq

print_step "git configuations"
(
  set -x
  git config --global user.name "$github_username"
  git config --global user.email "$github_email"
  git config --global core.editor "$github_editor"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
)

print_step "disable eyecandy, reset launchpad & clear scripts"
(
  set -x
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock
  rm "$0"
)
