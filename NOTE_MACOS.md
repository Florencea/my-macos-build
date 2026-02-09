# macOS Note

- [macOS Note](#macos-note)
  - [Install Rosetta2](#install-rosetta2)
  - [Reset LaunchPad](#reset-launchpad)
  - [Disable macOS popup showing accented characters when holding down a key](#disable-macos-popup-showing-accented-characters-when-holding-down-a-key)
  - [Disable Window Animations](#disable-window-animations)
  - [Generate SSH Key](#generate-ssh-key)
  - [Use Touch ID for sudo Commands](#use-touch-id-for-sudo-commands)
  - [Remove Quarantine Attributes](#remove-quarantine-attributes)
  - [Set DNS Servers](#set-dns-servers)
  - [Clear DNS Cache](#clear-dns-cache)
  - [Force Homebrew use ipv4 only](#force-homebrew-use-ipv4-only)
  - [Apple CDN Alias](#apple-cdn-alias)
  - [Microsoft Edge for DevTools Device Profile](#microsoft-edge-for-devtools-device-profile)
    - [Google Pixel 10 pro XL](#google-pixel-10-pro-xl)
      - [Full](#full)
      - [High](#high)

## Install Rosetta2

```sh
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
```

## Reset LaunchPad

```sh
# macos >= 15
rm -rf /private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad;killall Dock
# macos < 15
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

## Disable macOS popup showing accented characters when holding down a key

```sh
defaults write -g ApplePressAndHoldEnabled -bool false
```

## Disable Window Animations

```sh
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```

## Generate SSH Key

```sh
ssh-keygen -t ed25519
cat .ssh/id_ed25519.pub | pbcopy
# One liner
ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519" && cat "$HOME/.ssh/id_ed25519.pub"
```

## Use Touch ID for sudo Commands

```sh
sudo nano /etc/pam.d/sudo
# Add this at line 2
auth       sufficient     pam_tid.so
```

## Remove Quarantine Attributes

```sh
sudo xattr -r -d com.apple.quarantine <FILE>
```

## Set DNS Servers

```sh
# List network interfaces
networksetup -listallnetworkservices
# Remove DNS servers by set to empty (no quote)
networksetup -setdnsservers <SERVICE> empty
networksetup -setdnsservers 'Wi-Fi' empty
# Set DNS Servers (split by space)
networksetup -setdnsservers <SERVICE> [<DNS_SERVERS>]
networksetup -setdnsservers 'Wi-Fi' '8.8.8.8' '8.8.4.4' '2001:4860:4860::8888' '2001:4860:4860::8844'
```

## Clear DNS Cache

```sh
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

## Force Homebrew use ipv4 only

```sh
# Create curl config
echo "--ipv4" > ~/.homebrew_curlrc
# Add into fish config
echo 'set -gx HOMEBREW_CURLRC "$HOME/.homebrew_curlrc"' >> ~/.config/fish/config.fish
# Reload config or open a new terminal window
source ~/.config/fish/config.fish
```

## Apple CDN Alias

```sh
is1-ssl.mzstatic.com -> CNAME mzstatic.com.edgekey.net (Fast, at Taiwan)
                     -> CANME h3.apis.apple.map.fastly.net (Slow, at JP or SG)
```

## Microsoft Edge for DevTools Device Profile

- Android Browser User Agent

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/VERSION.0.0.0 Mobile Safari/537.36 EdgA/VERSION.0.0.0
```

- Example

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36 EdgA/143.0.0.0
```

### Google Pixel 10 pro XL

#### Full

- Screen: `448 x 998`
- DPR: `3`

#### High

- Screen: `444 x 987`
- DPR: `2.4375`
