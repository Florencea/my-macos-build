#! /usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Touch ID for sudo
if [ ! -f /etc/pam.d/sudo_local ]; then
  echo "Set TouchID for sudo commands via sudo_local"
  echo "# sudo_local: local authentication customization for sudo
auth       sufficient     pam_tid.so" | sudo tee /etc/pam.d/sudo_local >/dev/null
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

# Disable auto-updates, env hints, and auto-confirm (Ask mode) for Homebrew
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ASK=1

# Disable key-repeat popup
defaults write -g ApplePressAndHoldEnabled -bool false

# Git config
git config --global user.name "Florencea"
git config --global user.email "bearflorencea@gmail.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.quotepath false

# Global Git Hooks setup for AI agents restriction
mkdir -p "$HOME/.config/git/hooks"
curl -fsSL "https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/git/hooks/pre-commit" -o "$HOME/.config/git/hooks/pre-commit"
chmod +x "$HOME/.config/git/hooks/pre-commit"
git config --global core.hooksPath "$HOME/.config/git/hooks"

# Fish shell
brew install --formula fish
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

for comp in clall ebk mdig mkclp mkgif mmb rea rsl ua unodev up; do
  curl -fsSL "https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/fish/completions/$comp.fish" -o "$HOME/.config/fish/completions/$comp.fish" &
done
wait

# Essential casks
brew install --cask istat-menus@6 || true

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
brew install --formula \
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

# Antigravity IDE Configuration
echo "Configuring Antigravity IDE..."

# Create configuration and extensions directories
mkdir -p "$HOME/Library/Application Support/Antigravity IDE/User"
mkdir -p "$HOME/.antigravity-ide/extensions"

# Download settings and extensions list directly via curl
curl -fsSL "https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/antigravity-ide/settings.json" -o "$HOME/Library/Application Support/Antigravity IDE/User/settings.json"
curl -fsSL "https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/antigravity-ide/extensions.json" -o "$HOME/.antigravity-ide/extensions/extensions.json"

AG_CLI=""
if command -v agy-ide &>/dev/null; then
  AG_CLI="agy-ide"
elif command -v antigravity-ide &>/dev/null; then
  AG_CLI="antigravity-ide"
elif [ -x "/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide" ]; then
  AG_CLI="/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide"
fi

if [ -n "$AG_CLI" ]; then
  echo "Installing extensions from extensions.json..."
  if [ -f "$HOME/.antigravity-ide/extensions/extensions.json" ] && command -v jq &>/dev/null; then
    jq -r '.[] | .identifier.id' "$HOME/.antigravity-ide/extensions/extensions.json" | while read -r ext_id; do
      if [ -n "$ext_id" ]; then
        echo "Installing extension: $ext_id"
        "$AG_CLI" --install-extension "$ext_id" 2>&1 | grep -v "depends on antigravityAnalytics" || true
      fi
    done
  else
    echo "Warning: extensions.json or jq not found, skipping extension installation."
  fi
else
  echo "Warning: Antigravity IDE CLI not found, skipping extension installation."
fi

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
