#!/bin/zsh
set -o errexit
set -o nounset
set -o pipefail

# 0. Initialize sudo timestamp database (prevents fresh-install race condition)
sudo -v

# 1. Touch ID for sudo via system template
if [[ ! -f /etc/pam.d/sudo_local ]]; then
  echo "==> Configuring Touch ID for sudo via sudo_local..."
  if [[ -f /etc/pam.d/sudo_local.template ]]; then
    sudo sh -c 'sed -e "s/^#auth/auth/" /etc/pam.d/sudo_local.template > /etc/pam.d/sudo_local'
  else
    sudo sh -c 'echo "# sudo_local: local authentication customization for sudo\nauth       sufficient     pam_tid.so" > /etc/pam.d/sudo_local'
  fi
  sudo chmod 444 /etc/pam.d/sudo_local
else
  echo "sudo_local already exists, skipping Touch ID configuration."
fi

# 2. Internal Root CAs (Private PKI for *.internal)
readonly BHPD_ROOT_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCRENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hRUkRFZU1Cd0dBMVVFQXd3VlFraFFSQ0JKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU1qRXdPVm9YRFRNMk1Ea3hOakUxTWpFd09Wb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJVUVReEhqQWNCZ05WQkFNTUZVSklVRVFnU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQk95elJsUngvMGR6SjBScDlkYTFiQmdCSmxMbFpqU0NmcFN6ZjBMcQpaeWRjeFo0c1NmWENuTyt4MUhZU1JEa3Y0RGlnYVZwckhaUE1OYldjQ1FsRnBsK2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZBZitMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQjhHQTFVZEl3UVlNQmFBRkFmKwpMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBjQU1FUUNJRmxqSXZKenIyWHJ5Y0FvYzgybVpjU2J3QzRPa1h3NExkQ3IKcU13SlpDWkRBaUJub2xGWjdLRUhtZWlUOU5xYUpmSEtSeW5rMzAwUDhSaDd1eDl2cWZIemNRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
readonly BHGS_ROOT_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCVENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hIVXpFZU1Cd0dBMVVFQXd3VlFraEhVeUJKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU5UUTBNbG9YRFRNMk1Ea3hOakUxTlRRME1sb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJUjFNeEhqQWNCZ05WQkFNTUZVSklSMU1nU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkZGOVk0d0N5TVNnbzNJSjU2QnZOaE12Mnh2a2Y4MC9id2dCOGhILwpFZHhzUktYTS91YjhBWTlldmxaR0VzQlpUZzJaS0ZIT0dMajBpNngyWldUanA3T2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZHMGU4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQjhHQTFVZEl3UVlNQmFBRkcwZQo4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBnQU1FVUNJUUNmd0JISXNaTVdHWUZEbVNFNHVuQlNlUUZidkZLMzU0NHUKQ1hadVYwRlhTd0lnR0hwRDVWMGN4RmluS2VtenJVMU1ZQklpZXB0SnVEVmFQSnVhK2Qya3JHST0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="

trust_internal_ca() {
  local ca_name="$1"
  local ca_b64="$2"
  local trust_dump

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
  cert_tmp="$(mktemp -t ca_cert.XXXXXX)"

  base64 -d <<<"$ca_b64" >"$cert_tmp"
  sudo security add-trusted-cert \
    -d \
    -r trustRoot \
    -p ssl \
    -k /Library/Keychains/System.keychain \
    "$cert_tmp"
  echo "==> $ca_name installed and trusted successfully."

  rm -f "$cert_tmp"
}

trust_internal_ca "BHPD Internal Root CA" "$BHPD_ROOT_CA_B64"
trust_internal_ca "BHGS Internal Root CA" "$BHGS_ROOT_CA_B64"

# 3. Homebrew Setup
if [ -x "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew exists, skipping Homebrew installation."
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ASK=1
export HOMEBREW_AUTO_UPDATE_QUIET=1
export HOMEBREW_CURL_RETRIES=3

# 4. System Performance & Native Defaults
echo "==> Configuring system defaults..."
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g NSWindowResizeTime -float 0.001
defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false

# Terminal configuration: prevent disk I/O freezes
defaults write com.apple.Terminal ApplePersistenceIgnoreState -bool true
defaults write com.apple.Terminal NSQuitAlwaysKeepsWindows -bool false

# Prevent .DS_Store generation on Network & USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Suppress crash reporter UI dialogs
defaults write com.apple.CrashReporter DialogType none

# Accelerate DMG mounting by skipping validation
defaults write com.apple.frameworks.diskimages skip-verify -bool true
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true

# 5. Disable Spotlight, Siri, and Background Intelligence safely & completely
disable_spotlight_and_siri() {
  echo "==> Safely and completely disabling Spotlight indexing and Siri pipelines..."

  # Turn off indexing globally
  sudo mdutil -a -i off >/dev/null
  sudo mdutil -a -E 2>/dev/null || true
  sudo defaults write /Library/Preferences/com.apple.SpotlightServer.plist ExternalVolumesIndexed -bool false

  # Place native markers to avoid indexing loops
  sudo touch /.metadata_never_index 2>/dev/null || true
  touch "$HOME/.metadata_never_index" 2>/dev/null || true

  # Disable Spotlight UI and Global Shortcuts
  /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:64:enabled false" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:65:enabled false" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || true
  defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1 2>/dev/null || true

  # Disable Siri, Intelligence, Dictation, and Diagnostic telemetry
  defaults write com.apple.assistant.support "Assistant Enabled" -bool false
  defaults write com.apple.speech.recognition.AppleSpeechRecognition.prefs DictationIMMasterDictationSwitch -bool false
  defaults write com.apple.suggestions "SuggestionsAppLibraryEnabled" -bool false
  defaults write com.apple.suggestions "SuggestionsCalendarEnabled" -bool false
  defaults write com.apple.suggestions "SuggestionsEmailEnabled" -bool false
  defaults write com.apple.assistant.backedup "Logging Enabled" -bool false
  sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit -bool false

  # Terminal-specific Siri learning exclusion
  if ! defaults read com.apple.suggestions SiriCanLearnFromAppBlacklist 2>/dev/null | grep -q 'com.apple.Terminal'; then
    defaults write com.apple.suggestions SiriCanLearnFromAppBlacklist -array-add "com.apple.Terminal"
  fi
  if ! defaults read com.apple.suggestions AppCanShowSiriSuggestionsBlacklist 2>/dev/null | grep -q 'com.apple.Terminal'; then
    defaults write com.apple.suggestions AppCanShowSiriSuggestionsBlacklist -array-add "com.apple.Terminal"
  fi

  echo "==> Spotlight and Siri safely deactivated."
}

disable_spotlight_and_siri

# 6. Git Config & HostName
git config --global user.name "Florencea"
git config --global user.email "bearflorencea@gmail.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.quotepath false

TARGET_HOSTNAME="florenceambp"
if [[ "$(scutil --get HostName 2>/dev/null || true)" != "$TARGET_HOSTNAME" ]]; then
  sudo scutil --set HostName "$TARGET_HOSTNAME"
fi

# 7. Dotfiles and Custom Configurations
SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"

fetch_file() {
  local rel_path="$1"
  local dest_path="$2"
  if [[ -n "${REPO_DIR:-}" && -f "$REPO_DIR/$rel_path" ]]; then
    cp "$REPO_DIR/$rel_path" "$dest_path"
  else
    local encoded_path="${rel_path// /%20}"
    curl -fsSL "https://raw.githubusercontent.com/Florencea/my-macos-build/main/$encoded_path" -o "$dest_path"
  fi
}

mkdir -p "$HOME/.config/git/hooks"
fetch_file "configs/git/hooks/pre-commit.sh" "$HOME/.config/git/hooks/pre-commit"
chmod +x "$HOME/.config/git/hooks/pre-commit"
git config --global core.hooksPath "$HOME/.config/git/hooks"

fetch_file "configs/bash/bash_profile" "$HOME/.bash_profile"
fetch_file "configs/bash/bashrc" "$HOME/.bashrc"

touch "$HOME/.hushlogin"
mkdir -p "$HOME/.local/share/zsh/site-functions"
mkdir -p "$HOME/.config/zsh/functions"
fetch_file "configs/zsh/zshenv" "$HOME/.zshenv"
fetch_file "configs/zsh/zprofile" "$HOME/.zprofile"
fetch_file "configs/zsh/zshrc" "$HOME/.zshrc"

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

# Antigravity Global Custom Rules & Skills
echo "==> Configuring global Antigravity rules and skills..."
mkdir -p "$HOME/.gemini/config/rules"
mkdir -p "$HOME/.gemini/config/skills/macos-toolchain"

cat <<'EOF' >"$HOME/.gemini/config/rules/macos-toolchain.md"
---
name: macos-toolchain
description: Pre-installed high-performance CLI tools and macOS BSD constraints
trigger: always_on
---

# macOS Darwin Toolchain Rules

## Pre-installed High-Performance CLI Tools
- Fast Search: ALWAYS use `rg` (ripgrep) for searching file contents. Avoid `grep -r`.
- Path Traversal: ALWAYS use `fd` for finding files and directories. Avoid raw `find`.
- Directory Inspection: ALWAYS use `tree -L 2 -I 'node_modules|.git'`.
- Structured Data: Use `jq` for JSON and `yq` for YAML (both query and in-place `-i` edits).
- Tabular / Big Data: Use `duckdb -c "<SQL>"` for direct SQL queries over CSV, Parquet, or NDJSON.
- Text Replacement: Prefer `sd 'pattern' 'replacement' <file>` for in-place replacements.
- AST / Structural Code Search: Prefer `ast-grep` (`sg`) for semantic code pattern queries over regex.
- Benchmarking: ALWAYS use `hyperfine` for timing CLI commands or scripts instead of raw `time`.
- Scripting Runtime: ALWAYS use modern Node.js (`.mjs`). NEVER use Python (to avoid venv/pip breakage) or Deno.
- HTTP Requests: `curl -fsSL` and `wget` are both available.

## Local Git & Subshell Rules
- Use native `/usr/bin/git`.
- Pure local git workflows only (commit, diff, branch, rebase).
- DO NOT use `gh` (GitHub CLI). Do not query remote issues or PRs.

## macOS BSD Compatibility Traps (Linux/GNU Forbidden)
- `head` / `tail`: Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`. For line ranges, use `sed -n '1,3p' <file>`.
- `sed`: Always use BSD syntax: `sed -i '' 's/.../.../' <file>` if `sd` is not applicable.
- `awk`: Standard POSIX awk only; do NOT use GNU extensions like 3-argument `match()`.
- `stat`: BSD syntax. Use `stat -f "%z"` (never Linux `stat -c`).
- Network: Check open ports using `lsof -i :<PORT>` (never Linux `ss`).
EOF

cp "$HOME/.gemini/config/rules/macos-toolchain.md" "$HOME/.gemini/config/skills/macos-toolchain/SKILL.md"

# 8. Setup CLI Symlinks
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

  for link in "$HOME/.local/bin"/*(-@N); do
    target="$(readlink "$link" 2>/dev/null || true)"
    if [[ "$target" == "$CLI_DIR"* ]]; then
      rm -f "$link"
    fi
  done
fi

# 9. Package Installation (Casks & Formulas)
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

# Install all casks in one batch for better resolution speed
install_casks \
  font-jetbrains-mono \
  font-inter \
  istat-menus@6 \
  logi-options+ \
  1password \
  google-chrome \
  keka \
  iina \
  transmission \
  visual-studio-code \
  cloudflare-warp

echo "==> Configuring application defaults..."

# iStat Menus 6 License
defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"

# Keka configuration
defaults write com.aone.keka SetAsDefaultApp -bool true
defaults write com.aone.keka UseGrowl -bool false
defaults write com.aone.keka SelectedTab -string "TAR"

# IINA configuration
defaults write com.colliderli.iina actionAfterLaunch -int 2
defaults write com.colliderli.iina quitWhenNoOpenedWindow -bool true
defaults write com.colliderli.iina recordPlaybackHistory -bool false
defaults write com.colliderli.iina recordRecentFiles -bool false
defaults write com.colliderli.iina resumeLastPosition -int 0
defaults write com.colliderli.iina arrowBtnAction -int 1
defaults write com.colliderli.iina displayInLetterBox -bool false
defaults write com.colliderli.iina horizontalScrollAction -int 2
defaults write com.colliderli.iina verticalScrollAction -int 2
defaults write com.colliderli.iina pinchAction -int 2

# IINA toolbar buttons array using PlistBuddy for strict integer types
IINA_PREF="$HOME/Library/Preferences/com.colliderli.iina.plist"
/usr/libexec/PlistBuddy -c "Delete :controlBarToolbarButtons" "$IINA_PREF" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :controlBarToolbarButtons array" "$IINA_PREF" 2>/dev/null || true
for btn_val in 2 1 5 0; do
  /usr/libexec/PlistBuddy -c "Add :controlBarToolbarButtons: integer $btn_val" "$IINA_PREF" 2>/dev/null || true
done

# Transmission configuration
defaults write org.m0k.transmission BindPort -int 51247
defaults write org.m0k.transmission PeersTorrent -int 200
defaults write org.m0k.transmission PeersTotal -int 1000
defaults write org.m0k.transmission LocalPeerDiscoveryGlobal -bool true
defaults write org.m0k.transmission DownloadAsk -bool false
defaults write org.m0k.transmission MagnetOpenAsk -bool false
defaults write org.m0k.transmission DownloadLocationConstant -bool true
defaults write org.m0k.transmission DisplayPeerProgressBarNumber -bool true
defaults write org.m0k.transmission FilterSearchType -string "Name"
defaults write org.m0k.transmission AutoSize -bool true

# Register default file associations directly to LaunchServices (no UI confirmation dialogs)
LS_SECURE_PLIST="$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"

# Keka default associations
local -a keka_utis=(
  "public.zip-archive"
  "public.tar-archive"
  "public.tar-bzip2-archive"
  "public.bzip2-archive"
  "public.cpio-archive"
  "public.z-archive"
  "org.7-zip.7-zip-archive"
  "org.gnu.gnu-zip-archive"
  "org.gnu.gnu-zip-tar-archive"
  "org.tukaani.xz-archive"
  "org.tukaani.tar-xz-archive"
  "com.apple.archive"
  "com.apple.bom-compressed-cpio"
  "com.microsoft.cab"
)
for uti in "${keka_utis[@]}"; do
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentType string $uti" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string com.aone.keka" "$LS_SECURE_PLIST" 2>/dev/null || true
done

local -a keka_exts=(7z rar zip tar gz tgz bz2 tbz2 xz txz iso dmg)
for ext in "${keka_exts[@]}"; do
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTag string $ext" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTagClass string public.filename-extension" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string com.aone.keka" "$LS_SECURE_PLIST" 2>/dev/null || true
done

# IINA default associations
local -a iina_utis=(
  "public.mpeg-4"
  "public.avi"
  "public.mpeg"
  "public.mpeg-2-video"
  "public.dv-movie"
  "com.apple.quicktime-movie"
  "com.apple.m4v-video"
  "public.3gpp"
  "public.3gpp2"
  "public.mp3"
  "public.mp2"
  "public.mpeg-4-audio"
  "public.aac-audio"
  "public.aiff-audio"
  "public.ac3-audio"
  "com.microsoft.waveform-audio"
  "com.apple.m4a-audio"
  "com.apple.music.mp2"
  "com.apple.music.m3u-playlist"
  "public.m3u-playlist"
)
for uti in "${iina_utis[@]}"; do
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentType string $uti" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string com.colliderli.iina" "$LS_SECURE_PLIST" 2>/dev/null || true
done

local -a iina_exts=(mkv flv webm wmv rmvb vob mov ts m4v avi mp4 mp3 flac wav aac ogg ape opus)
for ext in "${iina_exts[@]}"; do
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTag string $ext" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTagClass string public.filename-extension" "$LS_SECURE_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string com.colliderli.iina" "$LS_SECURE_PLIST" 2>/dev/null || true
done

# CLI tools
install_formulas \
  actionlint \
  ast-grep \
  duckdb \
  fd \
  ffmpeg \
  gifski \
  hyperfine \
  jq \
  mtr \
  ripgrep \
  sd \
  shfmt \
  tree \
  wget \
  yq \
  yt-dlp \
  zsh-autosuggestions \
  zsh-syntax-highlighting

# 10. Flush preferences cache before reboot
killall cfprefsd 2>/dev/null || true

echo ""
echo "========================================================================"
echo "==> Installation complete."
echo "==> Please REBOOT your Mac manually to finalize macOS 27 FontRegistry,"
echo "    kernel extensions, and launchd process deactivations."
echo "========================================================================"
