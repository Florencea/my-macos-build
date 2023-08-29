# Fenix Note

- [Fenix Note](#fenix-note)
  - [Cloud Build Guide](#cloud-build-guide)
    - [1. Fork Repository](#1-fork-repository)
    - [2. Add Repository Secrets](#2-add-repository-secrets)
    - [3. Clone Release Tag](#3-clone-release-tag)
    - [4. Edit Files](#4-edit-files)
    - [5. Force push to `main` branch](#5-force-push-to-main-branch)
    - [6. Use GitHub Actions to Build](#6-use-github-actions-to-build)

## Cloud Build Guide

### 1. Fork Repository

- <https://github.com/mozilla-mobile/firefox-android>

### 2. Add Repository Secrets

- **Note: Only for personal use, this key is different from upstream!**
- `DEBUG_SIGNING_KEY`

```sh
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
```

- `DEBUG_ALIAS`

```sh
key0
```

- `DEBUG_KEY_PASSWORD`

```sh
123456
```

- `DEBUG_KEY_STORE_PASSWORD`

```sh
123456
```

### 3. Clone Release Tag

```sh
git clone --depth 1 --branch fenix-v117.0 git@github.com:Florencea/firefox-android.git
```

### 4. Edit Files

- Add GitHub Action script
- `rm .github/workflows/*.yml`
- `touch .github/workflows/release.yml`
- Could delete all other actions in `.github/workflows`

```yml
name: Release Automation
on:
  workflow_dispatch:
jobs:
  release-automation:
    name: Build App
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2
        with:
          fetch-depth: 1
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          java-version: 17
          distribution: temurin
      - name: Install Android SDK with pieces Gradle skips
        run: ./automation/install-sdk.sh
      - name: Inspect memory
        run: free -m
      - name: Create version name
        run: echo "VERSION_NAME=$(cat version.txt)" >> $GITHUB_ENV
      - name: Build release variant of app
        uses: gradle/gradle-build-action@v2
        env:
          GRADLE_OPTS: -Dorg.gradle.jvmargs="-XX:MaxMetaspaceSize=1g -Xms2g -Xmx4g -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/dev/stderr"
        with:
          gradle-home-cache-cleanup: true
          build-root-directory: fenix
          arguments: app:assembleRelease -x app:lintVitalAnalyzeFenixRelease -x app:lintVitalReportFenixRelease -x app:lintVitalFenixRelease -PdisableOptimization -PversionName=${{ env.VERSION_NAME }} --stacktrace --no-daemon
      - name: Create signed APKs
        uses: abhijitvalluri/sign-apks@v0.8
        with:
          releaseDirectory: fenix/app/build/outputs/apk/fenix/release/
          signingKeyBase64: ${{ secrets.DEBUG_SIGNING_KEY }}
          alias: ${{ secrets.DEBUG_ALIAS }}
          keyStorePassword: ${{ secrets.DEBUG_KEY_STORE_PASSWORD }}
          keyPassword: ${{ secrets.DEBUG_KEY_PASSWORD }}
      - name: Archive arm64 apk
        uses: actions/upload-artifact@v2
        with:
          name: app-fenix-arm64-v8a-release.apk
          path: fenix/app/build/outputs/apk/fenix/release/app-fenix-arm64-v8a-release.apk
```

- Add Android SDK installaton script from iceraven
- `mkdir automation`
- `touch automation/install-sdk.sh`
- `chmod 755 automation/install-sdk.sh`

```sh
#!/usr/bin/env bash
# Install the Android SDK and all the parts Gradle doesn't figure out to install itself

# Install the SDK
mkdir -p $HOME/android-sdk/android-sdk-linux
pushd $HOME/android-sdk/android-sdk-linux
mkdir -p licenses
echo "8933bad161af4178b1185d1a37fbf41ea5269c55" >> licenses/android-sdk-license
echo "d56f5187479451eabf01fb78af6dfcb131a6481e" >> licenses/android-sdk-license
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" >> licenses/android-sdk-license
if [ ! -e cmdline-tools ] ; then
    mkdir -p cmdline-tools
    pushd cmdline-tools
    wget --quiet "$(curl -s https://developer.android.com/studio | grep -oP "https://dl.google.com/android/repository/commandlinetools-linux-[0-9]+_latest.zip")"
    unzip commandlinetools-linux-*_latest.zip
    mv cmdline-tools tools
    popd
fi
popd
export ANDROID_SDK_ROOT=$HOME/android-sdk/android-sdk-linux

# Install the weirdly missing NDK
${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin/sdkmanager "ndk;21.0.6113669"

# Point the build at the tools
echo "sdk.dir=${ANDROID_SDK_ROOT}" >> local.properties
```

- `app/build.gradle`
- Change Default AMO Collections and speedup build

```bash
buildConfigField "String", "AMO_COLLECTION_USER", "\"mozilla\"" -> buildConfigField "String", "AMO_COLLECTION_USER", "\"17496363\""
applicationIdSuffix ".firefox" -> applicationIdSuffix ".firefox_custom"
include "x86", "armeabi-v7a", "arm64-v8a", "x86_64" -> include "arm64-v8a"
```

- `app/src/main/java/org/mozilla/fenix/FeatureFlags.kt`
- Disable features (as needed)

```kotlin
const val pullToRefreshEnabled = false
return listOf("en-US", "en-CA").contains(langTag) -> return listOf("nothing").contains(langTag)
```

- `app/src/main/java/org/mozilla/fenix/browser/BrowserFragment.kt`
- Comment this part (Line 96 ~ 106)
- see [For #23076 - Clean up unneeded FeatureFlags](https://github.com/Florencea/firefox-android/commit/76fb147ed87c32f37b6b92db1a0d0b3541308d86)

```kotlin
val homeAction = BrowserToolbar.Button(
    imageDrawable = AppCompatResources.getDrawable(
        context,
        R.drawable.mozac_ic_home
    )!!,
    contentDescription = context.getString(R.string.browser_toolbar_home),
    iconTintColorResource = ThemeManager.resolveAttribute(R.attr.primaryText, context),
    listener = browserToolbarInteractor::onHomeButtonClicked
)

browserToolbarView.view.addNavigationAction(homeAction)
```

- `fenix/app/src/main/java/org/mozilla/fenix/utils/Settings.kt`
- Change Line 1631 `featureFlag = false`
- see [Bug 1816004 - Remove unused unifiedSearchFeature and notificationPrePermissionPromptEnabled feature flags](https://github.com/Florencea/firefox-android/commit/2dee46be18d91da5697e51516ad38efc2643c678)

```kotlin
/**
  * Indicates if the Unified Search feature should be visible.
  */
var showUnifiedSearchFeature by lazyFeatureFlagPreference(
    key = appContext.getPreferenceKey(R.string.pref_key_show_unified_search_2),
    default = { FxNimbus.features.unifiedSearch.value().enabled },
    featureFlag = false,
)
```

- `app/src/main/java/org/mozilla/fenix/gecko/GeckoProvider.kt`

- Enable `about:config` (Line 60)

```kotlin
.aboutConfigEnabled(true)
```

- Disable safebrowsing, Replace whole `if` block under comments

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

- `app/src/main/res/drawable/progress_gradient.xml`
- Disable progress bar by set color to transparent

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- This Source Code Form is subject to the terms of the Mozilla Public
   - License, v. 2.0. If a copy of the MPL was not distributed with this
   - file, You can obtain one at http://mozilla.org/MPL/2.0/. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background">
        <shape>
            <solid android:color="#002b2a32" />
        </shape>
    </item>

    <item android:id="@android:id/progress">
        <scale android:scaleWidth="100%">
            <shape>
                <corners
                    android:bottomLeftRadius="0dp"
                    android:bottomRightRadius="8dp"
                    android:topLeftRadius="0dp"
                    android:topRightRadius="8dp"/>
                <gradient
                    android:angle="45"
                    android:centerColor="#002b2a32"
                    android:endColor="#002b2a32"
                    android:startColor="#002b2a32" />
            </shape>
        </scale>
    </item>
</layer-list>
```

### 5. Force push to `main` branch

```bash
git push -uf origin HEAD:main
```

### 6. Use GitHub Actions to Build
