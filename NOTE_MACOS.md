# macOS Note

- [macOS Note](#macos-note)
  - [Useful commands](#useful-commands)
    - [Install Rosetta2](#install-rosetta2)
    - [Reset LaunchPad](#reset-launchpad)
    - [Disable macOS popup showing accented characters when holding down a key](#disable-macos-popup-showing-accented-characters-when-holding-down-a-key)
    - [Disable Window Animations](#disable-window-animations)
    - [Generate SSH Key](#generate-ssh-key)
    - [Use Touch ID for sudo Commands](#use-touch-id-for-sudo-commands)
    - [Remove Quarantine Attributes](#remove-quarantine-attributes)

## Useful commands

### Install Rosetta2

```sh
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
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

### Remove Quarantine Attributes

```bash
sudo xattr -r -d com.apple.quarantine <FILE>
```
