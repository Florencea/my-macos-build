#!/bin/zsh
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

# Internal Root CAs (Private PKI for *.internal)
readonly BHPD_ROOT_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCRENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hRUkRFZU1Cd0dBMVVFQXd3VlFraFFSQ0JKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU1qRXdPVm9YRFRNMk1Ea3hOakUxTWpFd09Wb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJVUVReEhqQWNCZ05WQkFNTUZVSklVRVFnU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQk95elJsUngvMGR6SjBScDlkYTFiQmdCSmxMbFpqU0NmcFN6ZjBMcQpaeWRjeFo0c1NmWENuTyt4MUhZU1JEa3Y0RGlnYVZwckhaUE1OYldjQ1FsRnBsK2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZBZitMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQjhHQTFVZEl3UVlNQmFBRkFmKwpMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBjQU1FUUNJRmxqSXZKenIyWHJ5Y0FvYzgybVpjU2J3QzRPa1h3NExkQ3IKcU13SlpDWkRBaUJub2xGWjdLRUhtZWlUOU5xYUpmSEtSeW5rMzAwUDhSaDd1eDl2cWZIemNRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
readonly BHGS_ROOT_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCVENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hIVXpFZU1Cd0dBMVVFQXd3VlFraEhVeUJKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU5UUTBNbG9YRFRNMk1Ea3hOakUxTlRRME1sb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJUjFNeEhqQWNCZ05WQkFNTUZVSklSMU1nU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkZGOVk0d0N5TVNnbzNJSjU2QnZOaE12Mnh2a2Y4MC9id2dCOGhILwpFZHhzUktYTS91YjhBWTlldmxaR0VzQlpUZzJaS0ZIT0dMajBpNngyWldUanA3T2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZHMGU4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQjhHQTFVZEl3UVlNQmFBRkcwZQo4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBnQU1FVUNJUUNmd0JISXNaTVdHWUZEbVNFNHVuQlNlUUZidkZLMzU0NHUKQ1hadVYwRlhTd0lnR0hwRDVWMGN4RmluS2VtenJVMU1ZQklpZXB0SnVEVmFQSnVhK2Qya3JHST0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="

trust_internal_ca() {
  local ca_name="$1"
  local ca_b64="$2"
  local trust_dump

  # Check Admin Trust Settings before running any sudo commands
  trust_dump="$(security dump-trust-settings -d 2>/dev/null || true)"
  if [[ -n "$trust_dump" ]] && awk -v cn="$ca_name" '
    $0 ~ ("Cert [0-9]+:.*" cn) { in_cert=1; next }
    /^Cert [0-9]+:/ { in_cert=0 }
    in_cert && /Trust Setting/ { trusted=1 }
    END { exit !trusted }
  ' <<<"$trust_dump"; then
    echo "$ca_name is already trusted in admin domain, skipping"
    return 0
  fi

  echo "==> Installing and trusting $ca_name..."
  local cert_tmp
  cert_tmp="$(mktemp -t ca_cert)"
  trap 'rm -f "$cert_tmp"' EXIT INT TERM HUP

  base64 -d <<<"$ca_b64" >"$cert_tmp"

  sudo security add-trusted-cert \
    -d \
    -r trustRoot \
    -p ssl \
    -k /Library/Keychains/System.keychain \
    "$cert_tmp"

  rm -f "$cert_tmp"
  trap - EXIT INT TERM HUP
  echo "==> $ca_name installed and trusted successfully."
}

trust_internal_ca "BHPD Internal Root CA" "$BHPD_ROOT_CA_B64"
trust_internal_ca "BHGS Internal Root CA" "$BHGS_ROOT_CA_B64"

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

# Safely disable Spotlight indexing to prevent CPU spikes and IPC deadlocks (e.g. mdfind / Homebrew cask).
disable_spotlight_safely() {
  echo "==> Safely disabling Spotlight indexing (kMDConfigSearchLevelFSSearchOnly)..."

  local sudo_cmd=""
  if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo &>/dev/null; then
      echo "Error: sudo is required to configure Spotlight settings." >&2
      return 1
    fi
    sudo -v
    sudo_cmd="sudo"
  fi

  # 1. Globally disable indexing across all volumes
  echo "--> Disabling indexing on all volumes..."
  $sudo_cmd mdutil -a -i off

  # 2. Erase existing indexing databases (suppress expected CoreSpotlight reset errors / Code=-1 under set -e)
  echo "--> Erasing existing Spotlight index databases..."
  $sudo_cmd mdutil -a -E || true

  # 3. Terminate lingering metadata worker processes consuming resources
  echo "--> Terminating lingering metadata worker processes..."
  $sudo_cmd killall -9 mdworker mdworker_shared mds_stores 2>/dev/null || true

  # 4. Prevent external volumes from being automatically indexed after system updates
  echo "--> Disabling automatic indexing for external volumes..."
  $sudo_cmd defaults write /Library/Preferences/com.apple.SpotlightServer.plist ExternalVolumesIndexed -bool false

  # 5. Verify status across all volumes
  echo "--> Verifying Spotlight indexing status:"
  $sudo_cmd mdutil -a -s
  echo "==> Spotlight indexing safely disabled."
}

disable_spotlight_safely

# Git config
git config --global user.name "Florencea"
git config --global user.email "bearflorencea@gmail.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.quotepath false

# HostName setup (prevents mDNS / DNS resolution timeouts on terminal launch)
TARGET_HOSTNAME="florenceambp"
if [[ "$(scutil --get HostName 2>/dev/null || true)" != "$TARGET_HOSTNAME" ]]; then
  sudo scutil --set HostName "$TARGET_HOSTNAME"
fi

# Helper to copy from local repo if available, or fetch via curl
SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"

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
  local -a to_install=()
  for cask in "$@"; do
    if ! grep -Fxq "$cask" <<<"$installed"; then
      to_install+=("$cask")
    fi
  done
  if (($#to_install > 0)); then
    brew install --cask "${to_install[@]}" || true
  fi
}

install_formulas() {
  local brew_opt="${HOMEBREW_PREFIX:-/opt/homebrew}/opt"
  local installed
  installed="$(brew list --formula -1 2>/dev/null || true)"
  local -a to_install=()
  for formula in "$@"; do
    if ! grep -Fxq "$formula" <<<"$installed" && [[ ! -d "$brew_opt/$formula" ]]; then
      to_install+=("$formula")
    fi
  done
  if (($#to_install > 0)); then
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

# Zsh shell & Custom Completions
touch "$HOME/.hushlogin"
mkdir -p "$HOME/.local/share/zsh/site-functions"
mkdir -p "$HOME/.config/zsh/functions"
fetch_file "configs/zsh/zshenv" "$HOME/.zshenv"
fetch_file "configs/zsh/zprofile" "$HOME/.zprofile"
fetch_file "configs/zsh/zshrc" "$HOME/.zshrc"

# Copy custom Zsh completions to site-functions
if [[ -d "$REPO_DIR/configs/zsh/completions" ]]; then
  for comp in "$REPO_DIR/configs/zsh/completions"/_*(N); do
    cp -f "$comp" "$HOME/.local/share/zsh/site-functions/${comp:t}"
    chmod 644 "$HOME/.local/share/zsh/site-functions/${comp:t}"
  done
else
  local -a completions=(clall ebk mdig mkclp mkgif mmb rea ua unodev up)
  for comp in "${completions[@]}"; do
    fetch_file "configs/zsh/completions/_$comp" "$HOME/.local/share/zsh/site-functions/_$comp"
    chmod 644 "$HOME/.local/share/zsh/site-functions/_$comp"
  done
fi

# Setup CLI symlinks to ~/.local/bin
CLI_DIR=""
if [[ -n "${REPO_DIR:-}" && -d "$REPO_DIR/cli" ]]; then
  CLI_DIR="$REPO_DIR/cli"
elif [[ -d "$HOME/Developer/my-macos-build/cli" ]]; then
  CLI_DIR="$HOME/Developer/my-macos-build/cli"
fi

if [[ -n "$CLI_DIR" ]]; then
  mkdir -p "$HOME/.local/bin"
  for script in "$CLI_DIR"/*.sh(N); do
    cmd_name="${script:t:r}"
    ln -sf "$script" "$HOME/.local/bin/$cmd_name"
  done

  # Clean dangling symlinks originating from CLI_DIR
  for link in "$HOME/.local/bin"/*(-@N); do
    target="$(readlink "$link" 2>/dev/null || true)"
    if [[ "$target" == "$CLI_DIR"* ]]; then
      rm -f "$link"
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
  iina \
  transmission \
  visual-studio-code \
  cloudflare-warp

# CLI tools
install_formulas \
  actionlint \
  ffmpeg \
  gifski \
  jq \
  mtr \
  shfmt \
  yt-dlp \
  zsh-autosuggestions \
  zsh-syntax-highlighting

# Restart Dock
killall Dock
