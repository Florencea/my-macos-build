# macOS Note

- [macOS Note](#macos-note)
  - [Useful commands](#useful-commands)
    - [Install Rosetta2](#install-rosetta2)
    - [Reset LaunchPad](#reset-launchpad)
    - [Disable Window Animations](#disable-window-animations)
    - [Generate SSH Key](#generate-ssh-key)
    - [Use Touch ID for sudo Commands](#use-touch-id-for-sudo-commands)
    - [Rust Installation](#rust-installation)
    - [Remove Quarantine Attributes](#remove-quarantine-attributes)

## Useful commands

### Install Rosetta2

```sh
softwareupdate --install-rosetta
```

### Reset LaunchPad

```sh
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

### Disable Window Animations

```sh
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```

### Generate SSH Key

```sh
ssh-keygen -t ed25519
cat .ssh/id_ed25519.pub | pbcopy
```

### Use Touch ID for sudo Commands

```sh
sudo nano /etc/pam.d/sudo
# Add this at line 2
auth       sufficient     pam_tid.so
```

### Rust Installation

```sh
# For fish shell
curl https://sh.rustup.rs | sh
set -U fish_user_paths $HOME/.cargo/bin $fish_user_paths
mkdir -p ~/.config/fish/completions
# Open new shell
rustup completions fish > ~/.config/fish/completions/rustup.fish
```

### Remove Quarantine Attributes

```bash
sudo xattr -r -d com.apple.quarantine <FILE>
```