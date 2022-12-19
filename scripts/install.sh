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

print_step "brew install fish"
brew install fish
echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
mkdir -p ~/.config/fish
{
  printf "set CODE_BASE \"\$HOME/Codespaces/my-macos-build\"\n"
  printf "set SCRIPT_HOME \"\$CODE_BASE/scripts\"\n"
  printf "set SCRIPT_PRIVATE_HOME \"\$HOME/.ssh\"\n\n"
  printf "set -gx PATH /opt/homebrew/bin \$PATH\n"
  printf "set -gx fish_user_paths /opt/homebrew/sbin \$fish_user_paths\n"
  printf "set -gx fish_greeting\n\n"
  printf "alias mmb=\"code \$CODE_BASE\"\n"
  printf "alias mkgif=\"sh \$SCRIPT_HOME/make-gif.sh\"\n"
  printf "alias ebk=\"sh \$SCRIPT_HOME/extension-config-backup.sh\"\n"
  printf "alias urb=\"sh \$SCRIPT_HOME/ublock-rule-backup.sh\"\n"
  printf "alias ua=\"sh \$SCRIPT_HOME/update-all.sh\"\n"
  printf "alias rec=\"sh \$SCRIPT_HOME/re-encode.sh\"\n"
  printf "alias rsl=\"sh \$SCRIPT_PRIVATE_HOME/reset_dock.sh\"\n"
  printf "alias boxvpn=\"sh \$SCRIPT_PRIVATE_HOME/vpn.sh\"\n"
  printf "alias boxrsync=\"sh \$SCRIPT_PRIVATE_HOME/rsync.sh\"\n"
  printf "alias boxdump=\"sh \$SCRIPT_PRIVATE_HOME/sqldump.sh\"\n\n"
} >>~/.config/fish/config.fish

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
brew install font-jetbrains-mono
brew install font-inter
brew install font-new-york
cp -R /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/

print_step "brew install cask apps"
brew install --cask docker
brew install --cask google-chrome
brew install --cask iina
brew install --cask keka
brew install --cask kekaexternalhelper
brew install --cask microsoft-office
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
brew install mysql-client@5.7
echo "fish_add_path /opt/homebrew/opt/mysql-client@5.7/bin" >>~/.config/fish/config.fish
brew install nano
brew install nanorc
echo "include /opt/homebrew/share/nanorc/*.nanorc" >>~/.nanorc
brew install node@18
echo "fish_add_path /opt/homebrew/opt/node@18/bin" >>~/.config/fish/config.fish
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
  killall Dock
  rm "$0"
)
