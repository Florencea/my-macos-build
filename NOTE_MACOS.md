# macOS Note

- [macOS Note](#macos-note)
  - [Useful commands](#useful-commands)
    - [Install Rosetta2](#install-rosetta2)
    - [Reset LaunchPad](#reset-launchpad)
    - [Disable macOS popup showing accented characters when holding down a key](#disable-macos-popup-showing-accented-characters-when-holding-down-a-key)
    - [Disable Window Animations](#disable-window-animations)
    - [Generate SSH Key](#generate-ssh-key)
    - [Use Touch ID for sudo Commands](#use-touch-id-for-sudo-commands)
    - [Rust Installation](#rust-installation)
    - [Colima Installation](#colima-installation)
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

### Colima Installation

```sh
# Install colima, docker, docker-compose
brew install colima docker docker-compose
# Edit colima defalt config
colima template --editor code
```

```yaml
# Default: 2
cpu: 8
# Default: 2
memory: 8
# Default: host
arch: aarch64
# Default: []
  dns:
    - 8.8.8.8
    - 8.8.4.4
# Default: qemu
vmType: vz
# Default: false
rosetta: true
# Default: virtiofs (for vz), sshfs (for qemu)
mountType: virtiofs
```

```sh
# start colima
colima start
# check colima status
colima status
# stop colima
colima stop
```

### Remove Quarantine Attributes

```bash
sudo xattr -r -d com.apple.quarantine <FILE>
```
