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
if [ -x "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew exist, skip Homebrew installation"
fi

# Disable auto-updates, env hints, and auto-confirm (Ask mode) for Homebrew
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ASK=1
export HOMEBREW_AUTO_UPDATE_QUIET=1

# Disable key-repeat popup
defaults write -g ApplePressAndHoldEnabled -bool false

# Git config
git config --global user.name "Florencea"
git config --global user.email "bearflorencea@gmail.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.quotepath false

# Helper to copy from local repo if available, or fetch via curl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)"

fetch_file() {
  local rel_path="$1"
  local dest_path="$2"
  if [[ -n "${REPO_DIR:-}" && -f "$REPO_DIR/$rel_path" ]]; then
    cp "$REPO_DIR/$rel_path" "$dest_path"
  else
    curl -fsSL "https://raw.githubusercontent.com/Florencea/my-macos-build/main/$rel_path" -o "$dest_path"
  fi
}

install_casks() {
  local installed
  installed="$(brew list --cask -1 2>/dev/null || true)"
  local to_install=()
  for cask in "$@"; do
    if ! grep -Fxq "$cask" <<<"$installed"; then
      to_install+=("$cask")
    fi
  done
  if [[ ${#to_install[@]} -gt 0 ]]; then
    brew install --cask "${to_install[@]}" || true
  fi
}

install_formulas() {
  local brew_opt="${HOMEBREW_PREFIX:-/opt/homebrew}/opt"
  local installed
  installed="$(brew list --formula -1 2>/dev/null || true)"
  local to_install=()
  for formula in "$@"; do
    if ! grep -Fxq "$formula" <<<"$installed" && [[ ! -d "$brew_opt/$formula" ]]; then
      to_install+=("$formula")
    fi
  done
  if [[ ${#to_install[@]} -gt 0 ]]; then
    brew install --formula "${to_install[@]}" || true
  fi
}

# Global Git Hooks setup for AI agents restriction
mkdir -p "$HOME/.config/git/hooks"
fetch_file "configs/git/hooks/pre-commit.sh" "$HOME/.config/git/hooks/pre-commit"
chmod +x "$HOME/.config/git/hooks/pre-commit"
git config --global core.hooksPath "$HOME/.config/git/hooks"

# Bash shell
fetch_file "configs/bash/bash_profile" "$HOME/.bash_profile"
fetch_file "configs/bash/bashrc" "$HOME/.bashrc"

# Zsh shell
fetch_file "configs/zsh/zshenv" "$HOME/.zshenv"
fetch_file "configs/zsh/zprofile" "$HOME/.zprofile"
fetch_file "configs/zsh/zshrc" "$HOME/.zshrc"

# Fish shell
install_formulas fish
if ! grep -q '/opt/homebrew/bin/fish' /etc/shells; then
  echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
fi
if [ "$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')" != "/opt/homebrew/bin/fish" ]; then
  sudo dscl . -create "/Users/$USER" UserShell /opt/homebrew/bin/fish
fi

mkdir -p "$HOME/.config/fish"
mkdir -p "$HOME/.config/fish/conf.d"
mkdir -p "$HOME/.config/fish/functions"
mkdir -p "$HOME/.config/fish/completions"
fetch_file "configs/fish/conf.d/00-paths.fish" "$HOME/.config/fish/conf.d/00-paths.fish"
fetch_file "configs/fish/conf.d/fnm.fish" "$HOME/.config/fish/conf.d/fnm.fish"
fetch_file "configs/fish/functions/fish_prompt.fish" "$HOME/.config/fish/functions/fish_prompt.fish"
fetch_file "configs/fish/config.fish" "$HOME/.config/fish/config.fish"

for comp in clall ebk mdig mkclp mkgif mmb rea ua unodev up; do
  fetch_file "configs/fish/completions/$comp.fish" "$HOME/.config/fish/completions/$comp.fish" &
done
wait

# Setup CLI symlinks to ~/.local/bin
CLI_DIR=""
if [[ -n "${REPO_DIR:-}" && -d "$REPO_DIR/cli" ]]; then
  CLI_DIR="$REPO_DIR/cli"
elif [[ -d "$HOME/Developer/my-macos-build/cli" ]]; then
  CLI_DIR="$HOME/Developer/my-macos-build/cli"
fi

if [[ -n "$CLI_DIR" ]]; then
  mkdir -p "$HOME/.local/bin"
  for script in "$CLI_DIR"/*.sh; do
    [[ -f "$script" ]] || continue
    cmd_name="$(basename "$script" .sh)"
    ln -sf "$script" "$HOME/.local/bin/$cmd_name"
  done

  # Clean dangling symlinks originating from CLI_DIR
  for link in "$HOME/.local/bin"/*; do
    if [[ -L "$link" && ! -e "$link" ]]; then
      target="$(readlink "$link" 2>/dev/null || true)"
      if [[ "$target" == "$CLI_DIR"* ]]; then
        rm -f "$link"
      fi
    fi
  done
fi

# Essential casks
install_casks font-jetbrains-mono font-inter istat-menus@6

defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"

# Other casks
install_casks \
  logi-options+ \
  1password \
  google-chrome \
  keka \
  kekaexternalhelper \
  iina \
  visual-studio-code \
  cloudflare-warp

# CLI tools
install_formulas \
  actionlint \
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
if ! fnm list 2>/dev/null | grep -q 'lts-latest'; then
  fnm install --lts
  fnm default lts-latest
  fnm exec --using=default npm config set audit false engine-strict true fund false ignore-scripts true install-strategy linked save-exact true strict-peer-deps true
fi

# Nano config
echo "include ${HOMEBREW_PREFIX:-/opt/homebrew}/share/nanorc/*.nanorc" >~/.nanorc

# Restart Dock
killall Dock
