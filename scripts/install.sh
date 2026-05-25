#! /usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Touch ID for sudo
if [ ! -f /etc/pam.d/sudo_local ]; then
  echo "Set TouchID for sudo commands via sudo_local"
  echo -e "# sudo_local: local authentication customization for sudo\nauth       sufficient     pam_tid.so" | sudo tee /etc/pam.d/sudo_local >/dev/null
else
  echo "sudo_local already exists, skip Set Touch ID"
fi

# Homebrew
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
else
  echo "Homebrew exist, skip Homebrew installation"
fi

# Disable auto-updates
export HOMEBREW_NO_AUTO_UPDATE=1

# Disable key-repeat popup
defaults write -g ApplePressAndHoldEnabled -bool false

# Git config
git config --global user.name "Florencea"
git config --global user.email "bearflorencea@gmail.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.quotepath false

# Fish shell
brew install fish
if ! grep -q '/opt/homebrew/bin/fish' /etc/shells; then
  echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
fi
if [ "$SHELL" != "/opt/homebrew/bin/fish" ]; then
  chsh -s /opt/homebrew/bin/fish
fi

mkdir -p "$HOME/.config/fish"
mkdir -p "$HOME/.config/fish/conf.d"
mkdir -p "$HOME/.config/fish/functions"
mkdir -p "$HOME/.config/fish/completions"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/conf.d/00-paths.fish.txt -o "$HOME/.config/fish/conf.d/00-paths.fish"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/conf.d/fnm.fish.txt -o "$HOME/.config/fish/conf.d/fnm.fish"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/functions/fish_prompt.fish.txt -o "$HOME/.config/fish/functions/fish_prompt.fish"
curl -fsSL https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/config.fish.txt -o "$HOME/.config/fish/config.fish"

for comp in clall ebk mdig mdig6 mkclp mkgif mkgifv mmb rea rec rsl ua unodev up upp ytalb ytclp ytgif ytgifv ytmus ytmusfull; do
  curl -fsSL "https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/completions/$comp.fish" -o "$HOME/.config/fish/completions/$comp.fish" &
done
wait

# Essential casks
brew install --cask font-jetbrains-mono istat-menus@6 || true

defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"

# Other casks
brew install --cask \
  1password \
  antigravity-ide \
  c0re100-qbittorrent \
  cloudflare-warp \
  google-chrome \
  logi-options+ || true

# CLI tools
brew install \
  bash \
  curl \
  ffmpeg \
  fnm \
  gcc \
  gifski \
  git \
  jq \
  mtr \
  nano \
  nanorc \
  python \
  rsync \
  shfmt \
  wget \
  yt-dlp \
  yq \
  zsh

# Node.js config
fnm install --lts
fnm default lts-latest
fnm exec --using=lts-latest npm config set audit false engine-strict true fund false ignore-scripts true save-exact true

# Nano config
echo "include /opt/homebrew/share/nanorc/*.nanorc" >~/.nanorc

# Reset LaunchPad
rm -rf /private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad
killall Dock

# Self-deletion
if [[ -f "$0" ]]; then
  rm "$0"
fi
