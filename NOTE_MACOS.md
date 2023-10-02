# macOS Note

- [macOS Note](#macos-note)
  - [Installations](#installations)
    - [Rosetta2](#rosetta2)
    - [Bun](#bun)
    - [Deno](#deno)
    - [Colima](#colima)
    - [Rust](#rust)
    - [fnm](#fnm)
  - [Useful commands](#useful-commands)
    - [Reset LaunchPad](#reset-launchpad)
    - [Disable macOS popup showing accented characters when holding down a key](#disable-macos-popup-showing-accented-characters-when-holding-down-a-key)
    - [Disable Window Animations](#disable-window-animations)
    - [Generate SSH Key](#generate-ssh-key)
    - [Use Touch ID for sudo Commands](#use-touch-id-for-sudo-commands)
    - [Remove Quarantine Attributes](#remove-quarantine-attributes)

## Installations

### Rosetta2

```sh
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
```

### Bun

- <https://bun.sh/>

```sh
# Installation
brew tap oven-sh/bun
brew install bun
# VSCode
code --install-extension oven.bun-vscode
# git
git config --global diff.lockb.textconv bun
git config --global diff.lockb.binary true
```

```sh
# Uninstallation
git config --global --unset diff.lockb.textconv
git config --global --unset diff.lockb.binary
code --uninstall-extension oven.bun-vscode
brew uninstall --zap bun
brew untap oven-sh/bun
brew autoremove
```

### Deno

- <https://deno.com/>

```sh
# Installation
brew install deno
# VSCode
code --install-extension denoland.vscode-deno
```

```sh
# Uninstallation
code --uninstall-extension denoland.vscode-deno
brew uninstall --zap deno
brew autoremove
```

### Colima

- <https://github.com/abiosoft/colima>

```sh
# Installation
brew install colima
brew install docker
brew install docker-compose
colima template --editor ls
yq -i '.cpu=8 | .memory=8 | .arch="aarch64" | .network.dns|=["8.8.8.8", "8.8.4.4"] | .vmType="vz" | .rosetta=true | .mountType="virtiofs"' "$HOME/.colima/_templates/default.yaml"
```

```sh
# Uninstallation
brew uninstall --zap colima
brew autoremove
rm -rf .colima .docker .lima
```

### Rust

- <https://www.rust-lang.org/zh-TW/>

```sh
# Installation
brew install rustup-init
rustup-init -y --no-modify-path
# Add fish shell config
printf "# rustup\nfish_add_path \"\$HOME/.cargo/bin\"\n" >> $HOME/.config/fish/config.fish
# Add zsh config
printf "# rustup\nexport PATH=\"\$HOME/.cargo/bin:\$PATH\"\n" >> $HOME/.zshrc
# VSCode
code --install-extension rust-lang.rust-analyzer
code --install-extension tamasfe.even-better-toml
# VSCode Config
{
  "[rust]": {
    "editor.defaultFormatter": "rust-lang.rust-analyzer"
  },
  "[toml]": {
    "editor.defaultFormatter": "tamasfe.even-better-toml"
  }
}
```

```sh
# Uninstallation
# Remove VSCode Config
{
  "[rust]": {
    "editor.defaultFormatter": "rust-lang.rust-analyzer"
  },
  "[toml]": {
    "editor.defaultFormatter": "tamasfe.even-better-toml"
  }
}
code --uninstall-extension rust-lang.rust-analyzer
code --uninstall-extension tamasfe.even-better-toml
# Remove fish shell config
# rustup
fish_add_path "$HOME/.cargo/bin"
# Remove zsh config
# rustup
export PATH="$HOME/.cargo/bin:$PATH"
# Remove all rust toolchain
rm -rf .cargo .rustup
brew uninstall --zap rustup-init
brew autoremove
```

### fnm

- <https://github.com/Schniz/fnm>

```sh
# Installation
brew install fnm
# Add fish shell config
printf "# fnm\nfnm env | source\nfish_add_path \"\$(npm config get prefix)/bin\"\n" >> $HOME/.config/fish/config.fish
# Add zsh config
printf "# fnm\neval \"\$(fnm env)\"\nexport PATH=\"\$(npm config get prefix)/bin:\$PATH\"\n" >> $HOME/.zshrc
```

```sh
# Uninstallation
# Remove fish shell config
# fnm
fnm env | source
fish_add_path "$(npm config get prefix)/bin"
# Remove zsh config
# fnm
eval "$(fnm env)"
export PATH="$(npm config get prefix)/bin:$PATH"
# Remove fnm
brew uninstall --zap fnm
brew autoremove
rm -rf "$HOME/Library/Application Support/fnm" "$HOME/Library/Caches/fnm_multishells"
```

## Useful commands

### Reset LaunchPad

```sh
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

### Disable macOS popup showing accented characters when holding down a key

```sh
defaults write -g ApplePressAndHoldEnabled -bool false
```

### Disable Window Animations

```sh
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```

### Generate SSH Key

```sh
ssh-keygen -t ed25519
cat .ssh/id_ed25519.pub | pbcopy
# One liner
ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519" && cat "$HOME/.ssh/id_ed25519.pub"
```

### Use Touch ID for sudo Commands

```sh
sudo nano /etc/pam.d/sudo
# Add this at line 2
auth       sufficient     pam_tid.so
```

### Remove Quarantine Attributes

```bash
sudo xattr -r -d com.apple.quarantine <FILE>
```
