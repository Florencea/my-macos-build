#! /bin/bash
function print_step(){
  printf "\E[1;36m"
  printf "\n + %s\n\n" "$1"
  printf "\E[0m"
}

github_username="Florencea"
github_email="bearflorencea@gmail.com"
github_editor="nano"

print_step "install homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

print_step "brew install fish"
brew install fish
echo '/usr/local/bin/fish' | sudo tee -a /etc/shells
chsh -s /usr/local/bin/fish
mkdir -p ~/.config/fish
printf "set -g -x PATH /usr/local/bin \$PATH\n" >> ~/.config/fish/config.fish
printf "set -g fish_user_paths /usr/local/sbin \$fish_user_paths\n" >> ~/.config/fish/config.fish
printf "set -g fish_user_paths /usr/local/opt/curl/bin \$fish_user_paths\n" >> ~/.config/fish/config.fish
printf "set -g -x fish_greeting\n" >> ~/.config/fish/config.fish
printf "alias mmb=\"atom ~/GitHub/my-macos-build\"\n" >> ~/.config/fish/config.fish
printf "alias mkgif=\"sh ~/GitHub/my-macos-build/scripts/make-gif.sh\"\n" >> ~/.config/fish/config.fish
printf "alias ubk=\"sh ~/GitHub/my-macos-build/scripts/ublock-backup.sh\"\n" >> ~/.config/fish/config.fish
printf "alias al=\"sh ~/GitHub/my-macos-build/al/al.sh\"\n" >> ~/.config/fish/config.fish
printf "alias gd=\"sh ~/GitHub/my-macos-build/scripts/gdrive-download.sh\"\n" >> ~/.config/fish/config.fish
printf "alias ua=\"sh ~/GitHub/my-macos-build/scripts/update-all.sh\"\n" >> ~/.config/fish/config.fish
printf "alias urb=\"sh ~/GitHub/my-macos-build/scripts/ublock-rule-backup.sh\"\n" >> ~/.config/fish/config.fish
printf "alias afx=\"sh ~/GitHub/my-macos-build/scripts/atom-package-fix.sh\"\n" >> ~/.config/fish/config.fish

print_step "brew install cask fonts essential"
brew tap homebrew/cask-fonts
brew cask install font-fira-code
brew cask install font-inter

print_step "brew install cask apps"
brew tap homebrew/cask-versions
brew cask install atom
brew cask install firefox --language=zh-TW
brew cask install iina
brew cask install intel-power-gadget
brew cask install istat-menus
brew cask install keka
brew cask install kekadefaultapp
brew cask install c0re100-qbittorrent
brew cask install scroll-reverser

print_step "brew install commend line tools"
brew install clang-format
brew install curl
brew install ffmpeg
brew install gcc
brew install git
brew install git-lfs
brew install gnupg
brew install id3v2
brew install jq
brew install megatools
brew install nano
brew install node
brew install pinentry-mac
brew install python@3.8
brew install wget
brew install youtube-dl

print_step "brew install cask fonts"
brew cask install font-jf-open-huninn
brew cask install font-genyomin
brew cask install font-genryumin
brew cask install font-genwanmin
brew cask install font-genyogothic
brew cask install font-gensekigothic
brew cask install font-gensenrounded

print_step "npm install global packages"
npm install -g http-server
npm install -g eslint
npm install -g bash-language-server

print_step "python3 install global packages"
pip3 install autopep8
pip3 install beautysh
pip3 install flake8
pip3 install isort
pip3 install 'python-language-server[all]'

print_step "disable eyecandy"
(set -x; defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO)

print_step "setup SF Mono Fonts"
(set -x; cp -R /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/)

print_step "git configuations"
(set -x; git config --global user.name "$github_username")
(set -x; git config --global user.email "$github_email")
(set -x; git config --global core.editor "$github_editor")
(set -x; git config --global pull.rebase false)

print_step "reset launchpad"
(set -x; defaults write com.apple.dock ResetLaunchPad -bool true)
(set -x; killall Dock)

print_step "istat-menus licence"
printf "\E[0;31m"
printf "982092332@qq.com\n"
printf "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA\n"
printf "\E[0m"

print_step "clear scripts"
(set -x; rm "$0")
