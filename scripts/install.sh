#!/usr/bin/env bash
set -euo pipefail

readonly BHPD_ROOT_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCRENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hRUkRFZU1Cd0dBMVVFQXd3VlFraFFSQ0JKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU1qRXdPVm9YRFRNMk1Ea3hOakUxTWpFd09Wb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJVUVReEhqQWNCZ05WQkFNTUZVSklVRVFnU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQk95elJsUngvMGR6SjBScDlkYTFiQmdCSmxMbFpqU0NmcFN6ZjBMcQpaeWRjeFo0c1NmWENuTyt4MUhZU1JEa3Y0RGlnYVZwckhaUE1OYldjQ1FsRnBsK2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZBZitMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQjhHQTFVZEl3UVlNQmFBRkFmKwpMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBjQU1FUUNJRmxqSXZKenIyWHJ5Y0FvYzgybVpjU2J3QzRPa1h3NExkQ3IKcU13SlpDWkRBaUJub2xGWjdLRUhtZWlUOU5xYUpmSEtSeW5rMzAwUDhSaDd1eDl2cWZIemNRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
readonly BHGS_ROOT_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCVENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hIVXpFZU1Cd0dBMVVFQXd3VlFraEhVeUJKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU5UUTBNbG9YRFRNMk1Ea3hOakUxTlRRME1sb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJUjFNeEhqQWNCZ05WQkFNTUZVSklSMU1nU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkZGOVk0d0N5TVNnbzNJSjU2QnZOaE12Mnh2a2Y4MC9id2dCOGhILwpFZHhzUktYTS91YjhBWTlldmxaR0VzQlpUZzJaS0ZIT0dMajBpNngyWldUanA3T2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZHMGU4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQjhHQTFVZEl3UVlNQmFBRkcwZQo4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBnQU1FVUNJUUNmd0JISXNaTVdHWUZEbVNFNHVuQlNlUUZidkZLMzU0NHUKQ1hadVYwRlhTd0lnR0hwRDVWMGN4RmluS2VtenJVMU1ZQklpZXB0SnVEVmFQSnVhK2Qya3JHST0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="

init_sudo_touchid() {
  # Initialize sudo timestamp database to avoid fresh-install prompt races
  sudo -v

  if ! grep -Eq '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' /etc/pam.d/sudo_local 2>/dev/null; then
    if [[ -f /etc/pam.d/sudo_local.template ]]; then
      sudo sh -c 'awk "{sub(/^#auth/, \"auth\"); print}" /etc/pam.d/sudo_local.template > /etc/pam.d/sudo_local'
    else
      sudo sh -c 'printf "# sudo_local: local authentication customization for sudo\nauth       sufficient     pam_tid.so\n" > /etc/pam.d/sudo_local'
    fi
    sudo chmod 444 /etc/pam.d/sudo_local
  fi
}

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
    return 0
  fi

  local cert_tmp
  cert_tmp="$(mktemp -t ca_cert.XXXXXX)"

  base64 -d <<<"$ca_b64" >"$cert_tmp"
  sudo security add-trusted-cert \
    -d \
    -r trustRoot \
    -p ssl \
    -k /Library/Keychains/System.keychain \
    "$cert_tmp" >/dev/null 2>&1 || true

  rm -f "$cert_tmp"
}

install_internal_cas() {
  trust_internal_ca "BHPD Internal Root CA" "$BHPD_ROOT_CA_B64"
  trust_internal_ca "BHGS Internal Root CA" "$BHGS_ROOT_CA_B64"
}

setup_homebrew() {
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  export HOMEBREW_NO_AUTO_UPDATE=1
  export HOMEBREW_NO_ENV_HINTS=1
  export HOMEBREW_NO_ASK=1
  export HOMEBREW_AUTO_UPDATE_QUIET=1
  export HOMEBREW_CURL_RETRIES=3
}

configure_key_remapping() {
  # Disable CursorUIViewService floating indicator & Caps Lock delay
  defaults write kCFPreferencesAnyApplication TSMLanguageIndicatorEnabled -int 0
  defaults write com.apple.HIToolbox AppleCapsLockPressAndHoldToggleOff -int 1
  hidutil property --set '{"CapsLockDelayOverride":0}' >/dev/null 2>&1 || true

  mkdir -p "$HOME/Library/LaunchAgents"
  local key_remap_plist="$HOME/Library/LaunchAgents/com.local.KeyRemapping.plist"
  local key_remap_content='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.local.KeyRemapping</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/hidutil</string>
    <string>property</string>
    <string>--set</string>
    <string>{"CapsLockDelayOverride":0}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>'

  if [[ ! -f "$key_remap_plist" ]] || ! printf '%s\n' "$key_remap_content" | cmp -s - "$key_remap_plist"; then
    printf '%s\n' "$key_remap_content" >"$key_remap_plist"
    chmod 644 "$key_remap_plist"
    launchctl bootout "gui/$(id -u)/com.local.KeyRemapping" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$key_remap_plist" 2>/dev/null || true
  elif ! launchctl print "gui/$(id -u)/com.local.KeyRemapping" >/dev/null 2>&1; then
    launchctl bootstrap "gui/$(id -u)" "$key_remap_plist" 2>/dev/null || true
  fi

  if [[ "$(defaults read /Library/Preferences/FeatureFlags/Domain/UIKit.plist redesigned_text_cursor 2>/dev/null || true)" != *"Enabled = 0"* ]]; then
    sudo mkdir -p /Library/Preferences/FeatureFlags/Domain
    sudo defaults write /Library/Preferences/FeatureFlags/Domain/UIKit.plist redesigned_text_cursor -dict Enabled -bool false
  fi
}

configure_macos_defaults() {
  defaults write -g ApplePressAndHoldEnabled -bool false
  defaults write -g InitialKeyRepeat -int 12
  defaults write -g KeyRepeat -int 1
  defaults write -g NSAutomaticCapitalizationEnabled -bool false
  defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
  defaults write -g NSAutomaticInlinePredictionEnabled -bool false
  defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write -g NSAutomaticTextCompletionEnabled -bool false
  defaults write -g UIKitRedesignedTextCursorEnabled -bool false
  defaults write -g WebAutomaticSpellingCorrectionEnabled -bool false
  defaults write -g NSWindowResizeTime -float 0.001
  defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false

  configure_key_remapping

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
}

disable_spotlight_and_siri() {
  if ! mdutil -s / 2>/dev/null | grep -q "Indexing disabled"; then
    sudo mdutil -a -i off >/dev/null 2>&1 || true
    sudo mdutil -a -E >/dev/null 2>&1 || true
  fi
  sudo defaults write /Library/Preferences/com.apple.SpotlightServer.plist ExternalVolumesIndexed -bool false

  [[ -f "$HOME/.metadata_never_index" ]] || touch "$HOME/.metadata_never_index" 2>/dev/null || true

  /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:64:enabled false" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:65:enabled false" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || true
  defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1 2>/dev/null || true

  defaults write com.apple.assistant.support "Assistant Enabled" -bool false
  defaults write com.apple.speech.recognition.AppleSpeechRecognition.prefs DictationIMMasterDictationSwitch -bool false
  defaults write com.apple.suggestions "SuggestionsAppLibraryEnabled" -bool false
  defaults write com.apple.suggestions "SuggestionsCalendarEnabled" -bool false
  defaults write com.apple.suggestions "SuggestionsEmailEnabled" -bool false
  defaults write com.apple.assistant.backedup "Logging Enabled" -bool false
  sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit -bool false

  if ! defaults read com.apple.suggestions SiriCanLearnFromAppBlacklist 2>/dev/null | grep -q 'com.apple.Terminal'; then
    defaults write com.apple.suggestions SiriCanLearnFromAppBlacklist -array-add "com.apple.Terminal"
  fi
  if ! defaults read com.apple.suggestions AppCanShowSiriSuggestionsBlacklist 2>/dev/null | grep -q 'com.apple.Terminal'; then
    defaults write com.apple.suggestions AppCanShowSiriSuggestionsBlacklist -array-add "com.apple.Terminal"
  fi
}

configure_git_and_hostname() {
  git config --global user.name "Florencea"
  git config --global user.email "bearflorencea@gmail.com"
  git config --global core.editor "nano"
  git config --global init.defaultBranch main
  git config --global push.autoSetupRemote true
  git config --global pull.rebase false
  git config --global core.quotepath false

  local target_hostname="florenceambp"
  if [[ "$(scutil --get HostName 2>/dev/null || true)" != "$target_hostname" ]]; then
    sudo scutil --set HostName "$target_hostname"
  fi
}

resolve_repo_dir() {
  local script_path script_dir repo_dir=""
  if [[ -f "$0" ]]; then
    script_path="$(realpath "$0" 2>/dev/null || printf '%s' "$0")"
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    repo_dir="$(dirname "$script_dir")"
  fi
  if [[ ! -d "${repo_dir:-}/configs" ]]; then
    if [[ -d "$HOME/Developer/my-machine-build/configs" ]]; then
      repo_dir="$HOME/Developer/my-machine-build"
    else
      repo_dir=""
    fi
  fi
  printf '%s' "$repo_dir"
}

fetch_file() {
  local repo_dir="$1"
  local rel_path="$2"
  local dest_path="$3"
  local src_path="${repo_dir:-}/$rel_path"

  mkdir -p "$(dirname "$dest_path")"

  if [[ -n "${repo_dir:-}" && -f "$src_path" ]]; then
    if [[ -L "$dest_path" ]]; then
      rm -f "$dest_path"
    fi
    if [[ ! -f "$dest_path" ]] || ! cmp -s "$src_path" "$dest_path"; then
      cp -f "$src_path" "$dest_path"
    fi
  else
    local encoded_path="${rel_path// /%20}"
    local tmp_file
    tmp_file="$(mktemp -t mmb_fetch.XXXXXX)"
    if curl -fsSL "https://raw.githubusercontent.com/Florencea/my-machine-build/main/$encoded_path" -o "$tmp_file"; then
      if [[ -L "$dest_path" ]]; then
        rm -f "$dest_path"
      fi
      if [[ ! -f "$dest_path" ]] || ! cmp -s "$tmp_file" "$dest_path"; then
        cp -f "$tmp_file" "$dest_path"
      fi
      rm -f "$tmp_file"
    else
      rm -f "$tmp_file"
      return 1
    fi
  fi
}

deploy_dotfiles() {
  local repo_dir="$1"

  mkdir -p "$HOME/.config/git/hooks"
  fetch_file "$repo_dir" "configs/git/hooks/pre-commit.sh" "$HOME/.config/git/hooks/pre-commit"
  chmod +x "$HOME/.config/git/hooks/pre-commit"
  git config --global core.hooksPath "$HOME/.config/git/hooks"

  fetch_file "$repo_dir" "configs/bash/bash_profile" "$HOME/.bash_profile"
  fetch_file "$repo_dir" "configs/bash/bashrc" "$HOME/.bashrc"

  [[ -f "$HOME/.hushlogin" ]] || touch "$HOME/.hushlogin"
  fetch_file "$repo_dir" "configs/zsh/zshenv" "$HOME/.zshenv"
  fetch_file "$repo_dir" "configs/zsh/zprofile" "$HOME/.zprofile"
  fetch_file "$repo_dir" "configs/zsh/zshrc" "$HOME/.zshrc"

  mkdir -p "$HOME/.config/fish/conf.d" "$HOME/.config/fish/functions" "$HOME/.config/fish/completions"
  fetch_file "$repo_dir" "configs/fish/config.fish" "$HOME/.config/fish/config.fish"
  fetch_file "$repo_dir" "configs/fish/conf.d/00-paths.fish" "$HOME/.config/fish/conf.d/00-paths.fish"
  fetch_file "$repo_dir" "configs/fish/conf.d/fnm.fish" "$HOME/.config/fish/conf.d/fnm.fish"
  fetch_file "$repo_dir" "configs/fish/functions/fish_prompt.fish" "$HOME/.config/fish/functions/fish_prompt.fish"

  local -a fish_completions=(clall ebk mkclp mkgif mmb rea ua)
  local comp
  for comp in "${fish_completions[@]}"; do
    fetch_file "$repo_dir" "configs/fish/completions/$comp.fish" "$HOME/.config/fish/completions/$comp.fish"
  done

  # Clean up legacy Zsh completions and removed command completions
  local -a legacy_cmds=(clall ebk mdig mkclp mkgif mmb rea ua unodev up upnpmv webread)
  for comp in "${legacy_cmds[@]}"; do
    rm -f "$HOME/.local/share/zsh/site-functions/_$comp"
  done
  rmdir "$HOME/.local/share/zsh/site-functions" 2>/dev/null || true
  rmdir "$HOME/.config/zsh/functions" 2>/dev/null || true

  local -a removed_fish_completions=(mdig unodev up upnpmv webread)
  for comp in "${removed_fish_completions[@]}"; do
    rm -f "$HOME/.config/fish/completions/$comp.fish"
  done
}

sync_plugin_dir() {
  local repo_dir="$1"
  local plugin_name="$2"
  local src_dir="$repo_dir/plugins/$plugin_name"
  local dest_dir="$HOME/.gemini/config/plugins/$plugin_name"

  mkdir -p "$dest_dir"
  if [[ -n "${repo_dir:-}" && -d "$src_dir" ]]; then
    if ! diff -qr -x '.DS_Store' "$src_dir" "$dest_dir" >/dev/null 2>&1; then
      if [[ -n "$dest_dir" && -d "$dest_dir" ]]; then
        rm -rf "${dest_dir:?}"
      fi
      mkdir -p "$dest_dir"
      cp -R -c "$src_dir/." "$dest_dir/"
      find "$dest_dir" -name '.DS_Store' -delete 2>/dev/null || true
    fi
  else
    fetch_file "$repo_dir" "plugins/$plugin_name/plugin.json" "$dest_dir/plugin.json"
    if [[ "$plugin_name" == "modern-web-stack" ]]; then
      local -a web_rules=(ci-workflows.md node-ts.md react-ui.md)
      local rule_file
      for rule_file in "${web_rules[@]}"; do
        fetch_file "$repo_dir" "plugins/$plugin_name/rules/$rule_file" "$dest_dir/rules/$rule_file"
      done
      rm -f "$dest_dir/rules/AGENTS.md" "$dest_dir/rules/modern-web-stack.md"
    else
      fetch_file "$repo_dir" "plugins/$plugin_name/rules/AGENTS.md" "$dest_dir/rules/AGENTS.md"
    fi
  fi
}

deploy_antigravity_plugins() {
  local repo_dir="$1"

  sync_plugin_dir "$repo_dir" "common-modern-tools"
  sync_plugin_dir "$repo_dir" "macos-modern-tools"
  sync_plugin_dir "$repo_dir" "modern-web-stack"

  if [[ ! -d "$repo_dir/plugins" ]]; then
    fetch_file "$repo_dir" "plugins/common-modern-tools/skills/common-toolchain/SKILL.md" "$HOME/.gemini/config/plugins/common-modern-tools/skills/common-toolchain/SKILL.md"
    fetch_file "$repo_dir" "plugins/common-modern-tools/skills/common-toolchain/references/docs-matrix.md" "$HOME/.gemini/config/plugins/common-modern-tools/skills/common-toolchain/references/docs-matrix.md"
    fetch_file "$repo_dir" "plugins/macos-modern-tools/skills/macos-toolchain/SKILL.md" "$HOME/.gemini/config/plugins/macos-modern-tools/skills/macos-toolchain/SKILL.md"
    local -a web_skills=(modern-hono-drizzle modern-nodejs modern-react-tailwind modern-typescript modern-web-guidance node-project-architecture tanstack-router)
    local skill
    for skill in "${web_skills[@]}"; do
      fetch_file "$repo_dir" "plugins/modern-web-stack/skills/$skill/SKILL.md" "$HOME/.gemini/config/plugins/modern-web-stack/skills/$skill/SKILL.md"
    done
    local -a arch_resources=(
      ci-workflow-template.yml
      ci-workflows-rule-template.md
      lean-agents-template.md
      lint-tailwind-template.ts
      npmrc-template
      package-json-template.json
      vite-config-template.ts
      vscode-extensions-template.json
      vscode-settings-template.json
    )
    local res
    for res in "${arch_resources[@]}"; do
      fetch_file "$repo_dir" "plugins/modern-web-stack/skills/node-project-architecture/resources/$res" "$HOME/.gemini/config/plugins/modern-web-stack/skills/node-project-architecture/resources/$res"
    done
  fi

  local win_plugin_dir="$HOME/.gemini/config/plugins/windows-modern-tools"
  if [[ -n "$win_plugin_dir" && -d "$win_plugin_dir" ]]; then
    rm -rf "${win_plugin_dir:?}"
  fi

  # Clean up legacy standalone rules and skills migrated into plugins
  local -a legacy_rules=(ci-workflows macos-execution modern-nodejs modern-react-tailwind modern-testing modern-typescript)
  local rule
  for rule in "${legacy_rules[@]}"; do
    rm -f "$HOME/.gemini/config/rules/$rule.md"
  done
  rmdir "$HOME/.gemini/config/rules" 2>/dev/null || true

  local -a legacy_skills=(macos-toolchain modern-nodejs modern-react-tailwind modern-typescript node-project-architecture tanstack-router)
  local skill_dir
  for skill in "${legacy_skills[@]}"; do
    skill_dir="$HOME/.gemini/config/skills/$skill"
    if [[ -n "$skill_dir" && -d "$skill_dir" ]]; then
      rm -rf "${skill_dir:?}"
    fi
  done
  rmdir "$HOME/.gemini/config/skills" 2>/dev/null || true
}

link_cli_scripts() {
  local repo_dir="$1"
  local cli_dir=""

  if [[ -n "${repo_dir:-}" && -d "$repo_dir/cli" ]]; then
    cli_dir="$repo_dir/cli"
  elif [[ -d "$HOME/Developer/my-machine-build/cli" ]]; then
    cli_dir="$HOME/Developer/my-machine-build/cli"
  fi

  if [[ -z "$cli_dir" ]]; then
    return 0
  fi

  mkdir -p "$HOME/.local/bin"

  local -a scripts=()
  local script base cmd_name link_path
  shopt -s nullglob
  scripts=("$cli_dir"/*.sh)
  shopt -u nullglob

  if [[ ${#scripts[@]} -gt 0 ]]; then
    for script in "${scripts[@]}"; do
      [[ -f "$script" ]] || continue
      [[ -x "$script" ]] || chmod +x "$script"
      base="$(basename "$script")"
      cmd_name="${base%.sh}"
      link_path="$HOME/.local/bin/$cmd_name"
      if [[ "$(readlink "$link_path" 2>/dev/null || true)" != "$script" ]]; then
        ln -sfn "$script" "$link_path"
      fi
    done
  fi

  # Prune broken symlinks whose target pointed into $cli_dir (including legacy cli/bin/*)
  local -a bin_entries=()
  local link target
  shopt -s nullglob
  bin_entries=("$HOME/.local/bin"/*)
  shopt -u nullglob

  if [[ ${#bin_entries[@]} -gt 0 ]]; then
    for link in "${bin_entries[@]}"; do
      if [[ -L "$link" && ! -e "$link" ]]; then
        target="$(readlink "$link" 2>/dev/null || true)"
        if [[ "$target" == "$cli_dir"* ]]; then
          rm -f "$link"
        fi
      fi
    done
  fi
}

install_casks() {
  local installed
  installed="$(brew list --cask -1 2>/dev/null || true)"
  local -a to_install=()
  local cask
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
  local -a to_install=()
  local formula
  for formula in "$@"; do
    if ! grep -Fxq "$formula" <<<"$installed" && [[ ! -d "$brew_opt/$formula" ]]; then
      to_install+=("$formula")
    fi
  done
  if [[ ${#to_install[@]} -gt 0 ]]; then
    brew install --formula "${to_install[@]}" || true
  fi
}

install_packages() {
  install_casks \
    1password-cli \
    font-jetbrains-mono \
    font-inter \
    istat-menus@6 \
    logi-options+ \
    1password \
    microsoft-edge \
    keka \
    iina \
    visual-studio-code \
    cloudflare-warp

  install_formulas \
    actionlint \
    ast-grep \
    fd \
    ffmpeg \
    fish \
    fnm \
    gifski \
    jq \
    mtr \
    ripgrep \
    shfmt \
    yq \
    yt-dlp
}

configure_fish_shell() {
  local fish_bin="${HOMEBREW_PREFIX:-/opt/homebrew}/bin/fish"
  if [[ ! -x "$fish_bin" ]]; then
    return 0
  fi

  if ! grep -Fxq "$fish_bin" /etc/shells; then
    printf '%s\n' "$fish_bin" | sudo tee -a /etc/shells >/dev/null
  fi

  local user_shell
  user_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}' || true)"
  if [[ "$user_shell" != "$fish_bin" ]]; then
    sudo dscl . -create "/Users/$USER" UserShell "$fish_bin"
  fi
}

configure_apps() {
  # iStat Menus 6 License
  defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"

  # Keka configuration
  defaults write com.aone.keka SetAsDefaultApp -bool true 2>/dev/null || true
  defaults write com.aone.keka UseGrowl -bool false 2>/dev/null || true
  defaults write com.aone.keka SelectedTab -string "TAR" 2>/dev/null || true

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
  local iina_pref="$HOME/Library/Preferences/com.colliderli.iina.plist"
  if [[ "$(/usr/libexec/PlistBuddy -c "Print :controlBarToolbarButtons" "$iina_pref" 2>/dev/null | awk '/^[[:space:]]+[0-9]+$/ {printf "%s ", $1}')" != "2 1 5 0 " ]]; then
    /usr/libexec/PlistBuddy -c "Delete :controlBarToolbarButtons" "$iina_pref" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :controlBarToolbarButtons array" "$iina_pref" 2>/dev/null || true
    local btn_val
    for btn_val in 2 1 5 0; do
      /usr/libexec/PlistBuddy -c "Add :controlBarToolbarButtons: integer $btn_val" "$iina_pref" 2>/dev/null || true
    done
  fi

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
}

has_ls_uti() {
  local dump="$1" uti="$2" role="$3"
  awk -v uti="$uti" -v role="$role" '
    /^    Dict \{/ { in_dict=1; has_uti=0; has_role=0 }
    in_dict && $1 == "LSHandlerContentType" && $3 == uti { has_uti=1 }
    in_dict && $1 == "LSHandlerRoleAll" && $3 == role { has_role=1 }
    in_dict && /^    \}/ { if (has_uti && has_role) { found=1; exit 0 }; in_dict=0 }
    END { exit !found }
  ' <<<"$dump"
}

has_ls_ext() {
  local dump="$1" ext="$2" role="$3"
  awk -v ext="$ext" -v role="$role" '
    /^    Dict \{/ { in_dict=1; has_ext=0; has_class=0; has_role=0 }
    in_dict && $1 == "LSHandlerContentTag" && $3 == ext { has_ext=1 }
    in_dict && $1 == "LSHandlerContentTagClass" && $3 == "public.filename-extension" { has_class=1 }
    in_dict && $1 == "LSHandlerRoleAll" && $3 == role { has_role=1 }
    in_dict && /^    \}/ { if (has_ext && has_class && has_role) { found=1; exit 0 }; in_dict=0 }
    END { exit !found }
  ' <<<"$dump"
}

register_ls_uti() {
  local plist="$1" dump="$2" role="$3"
  shift 3
  local uti
  for uti in "$@"; do
    if ! has_ls_uti "$dump" "$uti" "$role"; then
      /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentType string $uti" "$plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string $role" "$plist" 2>/dev/null || true
    fi
  done
}

register_ls_ext() {
  local plist="$1" dump="$2" role="$3"
  shift 3
  local ext
  for ext in "$@"; do
    if ! has_ls_ext "$dump" "$ext" "$role"; then
      /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTag string $ext" "$plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTagClass string public.filename-extension" "$plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string $role" "$plist" 2>/dev/null || true
    fi
  done
}

configure_launch_services() {
  local ls_plist="$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
  mkdir -p "$(dirname "$ls_plist")"
  if ! /usr/libexec/PlistBuddy -c "Print :LSHandlers" "$ls_plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Add :LSHandlers array" "$ls_plist" 2>/dev/null || true
  fi
  local ls_dump
  ls_dump="$(/usr/libexec/PlistBuddy -c "Print :LSHandlers" "$ls_plist" 2>/dev/null || true)"

  local -a keka_utis=(
    "public.zip-archive" "public.tar-archive" "public.tar-bzip2-archive"
    "public.bzip2-archive" "public.cpio-archive" "public.z-archive"
    "org.7-zip.7-zip-archive" "org.gnu.gnu-zip-archive" "org.gnu.gnu-zip-tar-archive"
    "org.tukaani.xz-archive" "org.tukaani.tar-xz-archive" "com.apple.archive"
    "com.apple.bom-compressed-cpio" "com.microsoft.cab"
  )
  local -a keka_exts=(7z rar zip tar gz tgz bz2 tbz2 xz txz iso dmg)
  register_ls_uti "$ls_plist" "$ls_dump" "com.aone.keka" "${keka_utis[@]}"
  register_ls_ext "$ls_plist" "$ls_dump" "com.aone.keka" "${keka_exts[@]}"

  local -a iina_utis=(
    "public.mpeg-4" "public.avi" "public.mpeg" "public.mpeg-2-video"
    "public.dv-movie" "com.apple.quicktime-movie" "com.apple.m4v-video"
    "public.3gpp" "public.3gpp2" "public.mp3" "public.mp2"
    "public.mpeg-4-audio" "public.aac-audio" "public.aiff-audio"
    "public.ac3-audio" "com.microsoft.waveform-audio" "com.apple.m4a-audio"
    "com.apple.music.mp2" "com.apple.music.m3u-playlist" "public.m3u-playlist"
  )
  local -a iina_exts=(mkv flv webm wmv rmvb vob mov ts m4v avi mp4 mp3 flac wav aac ogg ape opus)
  register_ls_uti "$ls_plist" "$ls_dump" "com.colliderli.iina" "${iina_utis[@]}"
  register_ls_ext "$ls_plist" "$ls_dump" "com.colliderli.iina" "${iina_exts[@]}"
}

setup_node_fnm() {
  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --shell bash)"
    if ! fnm list 2>/dev/null | grep -q 'lts-latest'; then
      fnm install --lts
      fnm default lts-latest
    fi
    fnm exec --using=default npm config set \
      audit false \
      engine-strict true \
      fund false \
      ignore-scripts true \
      install-strategy linked \
      save-exact true \
      strict-peer-deps true
  fi

  local legacy_opt="$HOME/.local/opt"
  if [[ -d "$legacy_opt" ]]; then
    local -a legacy_dirs=()
    local legacy_node_dir
    shopt -s nullglob
    legacy_dirs=("$legacy_opt"/node*)
    shopt -u nullglob
    if [[ ${#legacy_dirs[@]} -gt 0 ]]; then
      for legacy_node_dir in "${legacy_dirs[@]}"; do
        if [[ -n "$legacy_node_dir" && -d "$legacy_node_dir" ]]; then
          rm -rf "${legacy_node_dir:?}"
        fi
      done
    fi
    rmdir "$legacy_opt" 2>/dev/null || true
  fi
}

restart_input_services() {
  killall cfprefsd 2>/dev/null || true
  killall CursorUIViewService 2>/dev/null || true
  pkill -HUP -f "/System/Library/Input Methods/TCIM.app" 2>/dev/null || true
}

main() {
  init_sudo_touchid
  install_internal_cas
  setup_homebrew
  configure_macos_defaults
  disable_spotlight_and_siri
  configure_git_and_hostname

  local repo_dir
  repo_dir="$(resolve_repo_dir)"

  deploy_dotfiles "$repo_dir"
  deploy_antigravity_plugins "$repo_dir"
  link_cli_scripts "$repo_dir"
  install_packages
  configure_fish_shell
  configure_apps
  configure_launch_services
  setup_node_fnm
  restart_input_services
}

main "$@"
