# Fenix Note

- **_Not update frequently_**
- Last update: Fenix v123.0

- [Fenix Note](#fenix-note)
  - [1. Fork Repository](#1-fork-repository)
  - [2. Clone Release Tag](#2-clone-release-tag)
  - [3. Edit Files](#3-edit-files)
    - [3-1. Change Default AMO Collections and speedup build](#3-1-change-default-amo-collections-and-speedup-build)
    - [3-2. Remove Home Button and Reader Button](#3-2-remove-home-button-and-reader-button)
  - [4 Build on macOS](#4-build-on-macos)
    - [4-1. Build on macOS: Add Build script](#4-1-build-on-macos-add-build-script)
    - [4-2. Build on macOS: Build App](#4-2-build-on-macos-build-app)

## 1. Fork Repository

- [FORK HERE](https://github.com/mozilla-mobile/firefox-android/fork)
- <https://github.com/mozilla-mobile/firefox-android>

## 2. Clone Release Tag

```sh
git clone --depth 1 --branch fenix-v123.0 git@github.com:Florencea/firefox-android.git
```

## 3. Edit Files

### 3-1. Change Default AMO Collections and speedup build

- `fenix/app/build.gradle`

```bash
buildConfigField "String", "AMO_COLLECTION_USER", "\"mozilla\"" -> buildConfigField "String", "AMO_COLLECTION_USER", "\"17496363\""
include "x86", "armeabi-v7a", "arm64-v8a", "x86_64" -> include "arm64-v8a"
```

### 3-2. Remove Home Button and Reader Button

- `fenix/app/src/main/java/org/mozilla/fenix/browser/BrowserFragment.kt`

- Comment this part (Line 99 ~ 122)

```kotlin
val isPrivate = (activity as HomeActivity).browsingModeManager.mode.isPrivate
val leadingAction = if (isPrivate && context.settings().feltPrivateBrowsingEnabled) {
    BrowserToolbar.Button(
        imageDrawable = AppCompatResources.getDrawable(
            context,
            R.drawable.mozac_ic_data_clearance_24,
        )!!,
        contentDescription = context.getString(R.string.browser_toolbar_erase),
        iconTintColorResource = ThemeManager.resolveAttribute(R.attr.textPrimary, context),
        listener = browserToolbarInteractor::onEraseButtonClicked,
    )
} else {
    BrowserToolbar.Button(
        imageDrawable = AppCompatResources.getDrawable(
            context,
            R.drawable.mozac_ic_home_24,
        )!!,
        contentDescription = context.getString(R.string.browser_toolbar_home),
        iconTintColorResource = ThemeManager.resolveAttribute(R.attr.textPrimary, context),
        listener = browserToolbarInteractor::onHomeButtonClicked,
    )
}

browserToolbarView.view.addNavigationAction(leadingAction)
```

- Comment this part (Line 126 ~ 148)

```kotlin
val readerModeAction =
    BrowserToolbar.ToggleButton(
        image = AppCompatResources.getDrawable(
            context,
            R.drawable.ic_readermode,
        )!!,
        imageSelected =
        AppCompatResources.getDrawable(
            context,
            R.drawable.ic_readermode_selected,
        )!!,
        contentDescription = context.getString(R.string.browser_menu_read),
        contentDescriptionSelected = context.getString(R.string.browser_menu_read_close),
        visible = {
            readerModeAvailable && !reviewQualityCheckAvailable
        },
        selected = getCurrentTab()?.let {
            activity?.components?.core?.store?.state?.findTab(it.id)?.readerState?.active
        } ?: false,
        listener = browserToolbarInteractor::onReaderModePressed,
    )

browserToolbarView.view.addPageAction(readerModeAction)
```

- Comment this part (Line 159 ~ 178)

```kotlin
readerViewFeature.set(
    feature = components.strictMode.resetAfter(StrictMode.allowThreadDiskReads()) {
        ReaderViewFeature(
            context,
            components.core.engine,
            components.core.store,
            binding.readerViewControlsBar,
        ) { available, active ->
            if (available) {
                ReaderMode.available.record(NoExtras())
            }

            readerModeAvailable = available
            readerModeAction.setSelected(active)
            safeInvalidateBrowserToolbarView()
        }
    },
    owner = this,
    view = view,
)
```

- Change Line 490

```kotlin
return readerViewFeature.onBackPressed() || super.onBackPressed()
->
return super.onBackPressed()
```

- `fenix/app/src/main/java/org/mozilla/fenix/search/SearchDialogFragment.kt`

- Prevent QR Search Button disappear, change Line 835

```kotlin
searchEngine?.isGeneral == true || searchEngine?.type == SearchEngine.Type.CUSTOM
->
searchEngine?.isGeneral == true || searchEngine?.type == SearchEngine.Type.CUSTOM || true
```

## 4 Build on macOS

- Require: [Homebrew](https://brew.sh/), [Node.js](https://nodejs.org/), [Keka](https://www.keka.io/) cli

### 4-1. Build on macOS: Add Build script

- `cd fenix && touch build.sh && chmod 755 build.sh`

```sh
#! /usr/bin/env bash
set -o errexit
set -o nounset

### Args
VERSION="$(cat ../version.txt)"
RELEASE_DIR="app/build/outputs/apk/fenix/release"
KEY_JS="$RELEASE_DIR/makekey.mjs"
KEY_PATH="$RELEASE_DIR/key.jks"
APK_PATH="$RELEASE_DIR/app-fenix-arm64-v8a-release-unsigned.apk"
RELEASE_APK_NAME="fenix-custom-v$VERSION.apk"
RELEASE_ZIP_NAME="fenix-custom-v$VERSION.zip"
SIGNED_APK_PATH="$RELEASE_DIR/$RELEASE_APK_NAME"
DOWNLOAD_DIR="$HOME/Downloads"

brew install zulu17 android-commandlinetools

echo "sdk.dir=/opt/homebrew/share/android-commandlinetools" >local.properties

chkcmd "sdkmanager"

yes | sdkmanager --licenses

./gradlew app:assembleRelease -x app:lintVitalAnalyzeFenixRelease -x app:lintVitalReportFenixRelease -x app:lintVitalFenixRelease -PversionName="$VERSION" --stacktrace

printf "import { writeFileSync } from 'node:fs';\nwriteFileSync('$KEY_PATH', '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', 'base64');\n" >"$KEY_JS"

node "$KEY_JS"

/opt/homebrew/share/android-commandlinetools/build-tools/30.0.3/apksigner sign --ks "$KEY_PATH" --ks-key-alias key0 --ks-pass pass:123456 --key-pass pass:123456 --out "$SIGNED_APK_PATH" "$APK_PATH"

cp "$SIGNED_APK_PATH" "$DOWNLOAD_DIR/$RELEASE_APK_NAME"

cd "$RELEASE_DIR"

keka 7z a "$DOWNLOAD_DIR/$RELEASE_ZIP_NAME" "$RELEASE_APK_NAME"
```

### 4-2. Build on macOS: Build App

- `./build.sh`
- Signed App will name `fenix-custom-v{VERSION}.apk` in `~/Downloads`
