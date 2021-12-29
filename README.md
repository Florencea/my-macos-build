# My macOS Build

## Quick Links

- [React Note](react/README.md)
- [FFmpeg Note](ffmpeg/README.md)

## Extenstion Configs

- [uBlock Origin Configs](https://raw.githubusercontent.com/Florencea/my-macos-build/main/configs/ublock-advanced.txt)
- [Violentmonkey Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/violentmonkey-backup.zip)
- [TWP Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/twp-backup.txt)

## macOS Commands

### Reset LaunchPad

```bash
defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock
```

### Use Touch ID for sudo Commands

```bash
sudo sed -i '' '2i\
auth       sufficient     pam_tid.so\
' /etc/pam.d/sudo
```

### Remove Quarantine Attributes

```bash
sudo xattr -r -d com.apple.quarantine <FILE>
```

## macOS Setup

- For Apple Silicon and macOS 12

### 1. Logout Browsers and Reinstall macOS

- <https://support.apple.com/zh-tw/HT212749>

### 2. System Performance

- Privacy -> Full Disk Access, Add "Terminal.app"

### 3. Finder and Dock

### 4. Data Recovery from Backup

- Setup "Music.app"
- Import media files to "Music.app"
- Copy data to ~/

### 5. Install Apps from App Store

### 6. Execute install.sh

### 7. Setup Apps

### 8. Setup Developer tools

- Setup SSH Key

```bash
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat .ssh/id_ed25519.pub | pbcopy
```

- Setup "Visual Studio Code.app"

## Firefox Setup

### Build

- `app/build.gradle`

```text
16201230 -> 16366570
What-I-want-on-Fenix -> addons-mobile
```

- `app/src/main/java/org/mozilla/fenix/FeatureFlags.kt`

```kotlin
const val showHomeButtonFeature = false
const val showHomeBehindSearch = false
const val showStartOnHomeSettings = false
const val showRecentTabsFeature = false
const val recentBookmarksFeature = false
const val customizeHome = false
val tabGroupFeature = false
```

- `app/src/main/java/org/mozilla/fenix/gecko/GeckoProvider.kt`

```kotlin
// Add safebrowsing providers for China
if (true) {
  val o = SafeBrowsingProvider
    .from(ContentBlocking.GOOGLE_SAFE_BROWSING_PROVIDER)
    .getHashUrl("")
    .updateUrl("")
    .build()
  runtimeSettings.contentBlocking.setSafeBrowsingProviders(o)
  runtimeSettings.contentBlocking.setSafeBrowsingPhishingTable("goog-phish-proto")
}
```

### Settings

- Set DNS over HTTPS

```text
https://dns.google/dns-query
```

- Set ECS to `false`

```text
network.trr.disable-ECS
```

- Set all prefetch configs to default

```text
prefetch
```

- Devtools

```text
Mozilla/5.0 (Android 12; Mobile; rv:94.0) Gecko/94.0 Firefox/94.0
```

```text
396 x 858
```

```text
2.727272727272727
```
