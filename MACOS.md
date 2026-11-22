# macOS Note

## Table of Contents

- [Clear DNS Cache](#clear-dns-cache)
- [Set DNS Servers with CLI](#set-dns-servers-with-cli)
- [Remove Quarantine Attributes](#remove-quarantine-attributes)
- [CDN Alias](#cdn-alias)
- [Generate SSH Key](#generate-ssh-key)
- [Use Touch ID for sudo Commands](#use-touch-id-for-sudo-commands)
- [Disable macOS popup showing accented characters when holding down a key](#disable-macos-popup-showing-accented-characters-when-holding-down-a-key)
- [Disable Window Animations](#disable-window-animations)

## Clear DNS Cache

```sh
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

## Set DNS Servers with CLI

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

## Remove Quarantine Attributes

```sh
sudo xattr -r -d com.apple.quarantine <FILE>
```

## CDN Alias

```sh
# Apple CDN
is1-ssl.mzstatic.com -> CNAME mzstatic.com.edgekey.net (Fast, at Taiwan)
                     -> CNAME h3.apis.apple.map.fastly.net (Slow, at JP or SG)
# X CDN
abs.twimg.com -> CNAME abs.twimg.com.cdn.cloudflare.net (Fast, at Taiwan)
              -> CNAME twimg.twitter.map.fastly.net (Slow, at SG)
pbs.twimg.com -> CNAME pbs.twimg.com.cdn.cloudflare.net (Fast, at Taiwan)
              -> CNAME dualstack.twimg.twitter.map.fastly.net  (Slow, at SG)
```

## Generate SSH Key

```sh
ssh-keygen -t ed25519
cat "$HOME/.ssh/id_ed25519.pub" | pbcopy
# One liner
ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519" && pbcopy < "$HOME/.ssh/id_ed25519.pub"
```

## Use Touch ID for sudo Commands

```sh
sudo nano /etc/pam.d/sudo_local
# Add this
auth       sufficient     pam_tid.so
```

## Disable macOS popup showing accented characters when holding down a key

```sh
defaults write -g ApplePressAndHoldEnabled -bool false
```

## Disable Window Animations

```sh
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```
