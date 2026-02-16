# Edge Note

- [Edge Note](#edge-note)
  - [Configuration Tweaks (Use terminal)](#configuration-tweaks-use-terminal)
    - [Picture in Picture](#picture-in-picture)
    - [QUIC](#quic)
  - [Configuration Tweaks (Use .mobileconfig)](#configuration-tweaks-use-mobileconfig)
    - [DNS over HTTPS](#dns-over-https)
  - [Microsoft Edge for DevTools Device Profile](#microsoft-edge-for-devtools-device-profile)
    - [Google Pixel 10 pro XL](#google-pixel-10-pro-xl)
      - [Full](#full)
      - [High](#high)

## Configuration Tweaks (Use terminal)

### Picture in Picture

- <https://learn.microsoft.com/zh-tw/deployedge/microsoft-edge-browser-policies/pictureinpictureoverlayenabled>

```sh
# Disable Picture in Picture
defaults write com.microsoft.Edge PictureInPictureOverlayEnabled -bool false
# Enable Picture in Picture
defaults delete com.microsoft.Edge PictureInPictureOverlayEnabled
```

### QUIC

- <https://learn.microsoft.com/zh-tw/deployedge/microsoft-edge-browser-policies/quicallowed>

```sh
# Disable QUIC
defaults write com.microsoft.Edge QuicAllowed -bool false
# Enable QUIC
defaults delete com.microsoft.Edge QuicAllowed
```

## Configuration Tweaks (Use .mobileconfig)

### DNS over HTTPS

- <https://learn.microsoft.com/zh-tw/DeployEdge/microsoft-edge-browser-policies/dnsoverhttpsmode>
- <https://learn.microsoft.com/zh-tw/DeployEdge/microsoft-edge-browser-policies/dnsoverhttpstemplates>
- Save as `Edge_Mandatory_Policies.mobileconfig`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>DnsOverHttpsMode</key>
            <string>secure</string>
            <key>DnsOverHttpsTemplates</key>
            <string>https://dns.google/dns-query{?dns}</string>
            <key>PictureInPictureOverlayEnabled</key>
            <false/>
            <key>PayloadDisplayName</key>
            <string>Microsoft Edge Policies</string>
            <key>PayloadIdentifier</key>
            <string>com.microsoft.Edge.policies</string>
            <key>PayloadType</key>
            <string>com.microsoft.Edge</string>
            <key>PayloadUUID</key>
            <string>A1B2C3D4-E5F6-7890-1234-567890ABCDEF</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>Edge Mandatory Policies (DoH &amp; PiP)</string>
    <key>PayloadIdentifier</key>
    <string>com.custom.edgepolicies</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>09876543-210F-E5F6-7890-1234567890AB</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
```

## Microsoft Edge for DevTools Device Profile

- Android Browser User Agent

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/VERSION.0.0.0 Mobile Safari/537.36 EdgA/VERSION.0.0.0
```

- Example

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Mobile Safari/537.36 EdgA/144.0.0.0
```

### Google Pixel 10 pro XL

#### Full

- Screen: `448 x 998`
- DPR: `3`

#### High

- Screen: `444 x 987`
- DPR: `2.44`
