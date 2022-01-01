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

## Firefox

### Fenix Build

```bash
brew install android-studio
```

```bash
softwareupdate --install-rosetta
```

- Download [current Fenix release](https://github.com/mozilla-mobile/fenix/releases/latest) codes and import to Android Studio

- Use Custom Add-ons: `app/build.gradle`

```bash
# AMO_COLLECTION_USER
buildConfigField "String", "AMO_COLLECTION_USER", "\"mozilla\""
-> buildConfigField "String", "AMO_COLLECTION_USER", "\"16366570\""
# AMO_COLLECTION_NAME
buildConfigField "String", "AMO_COLLECTION_NAME", "\"7dfae8669acc4312a65e8ba5553036\""
-> buildConfigField "String", "AMO_COLLECTION_NAME", "\"addons-mobile\""
# versionName
def versionName = variant.buildType.name == 'nightly' ? Config.nightlyVersionName() : Config.releaseVersionName(project)
-> def versionName = "YOUR_VERSION"
# AppId
applicationIdSuffix ".firefox"
-> applicationIdSuffix ".firefoxCustom"
# protobuf
artifact = Deps.protobuf_compiler
-> artifact = "${Deps.protobuf_compiler}:osx-x86_64"
# build type
include "x86", "armeabi-v7a", "arm64-v8a", "x86_64"
-> include "arm64-v8a"
# disable CRASH_REPORTING (Replace if-else block)
buildConfigField 'boolean', 'CRASH_REPORTING', 'false'
# disable TELEMETRY (Replace if-else block)
buildConfigField 'boolean', 'TELEMETRY', 'false'
# ADJUST_TOKEN (Replace if-else block)
buildConfigField 'String', 'ADJUST_TOKEN', 'null'
println("--")
# disable NIMBUS (Replace if-else block)
buildConfigField 'String', 'NIMBUS_ENDPOINT', 'null'
println("--")
```

- Disable Home Button in BrowserBar: `app/src/main/java/org/mozilla/fenix/FeatureFlags.kt`

```kotlin
// flags
const val pullToRefreshEnabled = false
const val addressesFeature = false
const val showHomeButtonFeature = false
const val showHomeBehindSearch = false
const val showStartOnHomeSettings = false
const val showRecentTabsFeature = false
const val recentBookmarksFeature = false
const val inactiveTabs = false
const val customizeHome = false
const val tabGroupFeature = false
// disable pockets
return listOf("en-US", "en-CA").contains(langTag)
-> return listOf("nothing").contains(langTag)
```

- Disable Google SafeBrowsing: `app/src/main/java/org/mozilla/fenix/gecko/GeckoProvider.kt`

```kotlin
// Add safebrowsing providers for China
val o = SafeBrowsingProvider
  .from(ContentBlocking.GOOGLE_SAFE_BROWSING_PROVIDER)
  .getHashUrl("")
  .updateUrl("")
  .build()
runtimeSettings.contentBlocking.setSafeBrowsingProviders(o)
runtimeSettings.contentBlocking.setSafeBrowsingPhishingTable("goog-phish-proto")
```

- Fix App Crash When Click "What's New": `app/src/main/java/org/mozilla/fenix/home/HomeFragment.kt`

```kotlin
searchTermOrURL = SupportUtils.getWhatsNewUrl(context),
-> searchTermOrURL = "https://github.com/mozilla-mobile/fenix",
```

- Build signed apk use `configs/key0`

```text
key0
123456
```

- APKs in `app/release`

### Firefox Desktop

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
Mozilla/5.0 (Android 12; Mobile; rv:95.0) Gecko/95.0 Firefox/95.0
```

```text
396 x 858
```

```text
2.727272727272727
```
