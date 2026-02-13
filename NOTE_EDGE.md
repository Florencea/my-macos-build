# Edge Note

- [Edge Note](#edge-note)
  - [Configuration Tweaks](#configuration-tweaks)
  - [Microsoft Edge for DevTools Device Profile](#microsoft-edge-for-devtools-device-profile)
    - [Google Pixel 10 pro XL](#google-pixel-10-pro-xl)
      - [Full](#full)
      - [High](#high)

## Configuration Tweaks

```sh
# Terminal
# Disable Picture in Picture
defaults write com.microsoft.Edge PictureInPictureOverlayEnabled -bool false
# Enable Picture in Picture
defaults delete com.microsoft.Edge PictureInPictureOverlayEnabled
```

```sh
# Terminal
# Disable QUIC
defaults write com.microsoft.Edge QuicAllowed -bool false
# Enable QUIC
defaults delete com.microsoft.Edge QuicAllowed
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
