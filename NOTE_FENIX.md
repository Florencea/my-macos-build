# Fenix Note

- [Fenix Note](#fenix-note)
  - [1. Fork Repository](#1-fork-repository)
  - [2. Clone Release Tag](#2-clone-release-tag)
  - [3. Edit Files](#3-edit-files)
    - [3-1. Change Default AMO Collections and speedup build](#3-1-change-default-amo-collections-and-speedup-build)
    - [3-2. Disable features in FeatureFlag](#3-2-disable-features-in-featureflag)
    - [3-3. Remove Home Button, Reader Button](#3-3-remove-home-button-reader-button)
    - [3-4. Change Default Settings](#3-4-change-default-settings)
    - [3-5. Enable config, Disable Safe Browsing](#3-5-enable-config-disable-safe-browsing)
    - [3-6. Disable Progress Bar](#3-6-disable-progress-bar)
    - [3-7. Customize Deafult Search Engine](#3-7-customize-deafult-search-engine)
    - [3-8. Disable Useless Settings](#3-8-disable-useless-settings)
  - [4-A. Use GitHub Actions to Build](#4-a-use-github-actions-to-build)
    - [4-A-1. Use GitHub Actions to Build: Add Repository Secrets](#4-a-1-use-github-actions-to-build-add-repository-secrets)
    - [4-A-2. Use GitHub Actions to Build: Add Build Actions and Scripts](#4-a-2-use-github-actions-to-build-add-build-actions-and-scripts)
    - [4-A-3. Use GitHub Actions to Build: Force push to `main` branch](#4-a-3-use-github-actions-to-build-force-push-to-main-branch)
  - [4-B. Build on macOS](#4-b-build-on-macos)
    - [4-B-1. Build on macOS: Add Build script](#4-b-1-build-on-macos-add-build-script)
    - [4-B-2. Build on macOS: Build App](#4-b-2-build-on-macos-build-app)
  - [4-C. Build on Docker](#4-c-build-on-docker)
    - [4-C-1. Build on Docker: Add Build script](#4-c-1-build-on-docker-add-build-script)
    - [4-C-2. Build on Docker: Build App](#4-c-2-build-on-docker-build-app)

## 1. Fork Repository

- [FORK HERE](https://github.com/mozilla-mobile/firefox-android/fork)
- <https://github.com/mozilla-mobile/firefox-android>

## 2. Clone Release Tag

```sh
git clone --depth 1 --branch fenix-v119.0 git@github.com:Florencea/firefox-android.git
```

## 3. Edit Files

### 3-1. Change Default AMO Collections and speedup build

- `fenix/app/build.gradle`

```bash
buildConfigField "String", "AMO_COLLECTION_USER", "\"mozilla\"" -> buildConfigField "String", "AMO_COLLECTION_USER", "\"17496363\""
applicationIdSuffix ".firefox" -> applicationIdSuffix ".firefox_custom"
include "x86", "armeabi-v7a", "arm64-v8a", "x86_64" -> include "arm64-v8a"
```

### 3-2. Disable features in FeatureFlag

- `fenix/app/src/main/java/org/mozilla/fenix/FeatureFlags.kt`

```kotlin
const val pullToRefreshEnabled = false
return listOf("en-US", "en-CA").contains(langTag) -> return listOf("nothing").contains(langTag)
```

### 3-3. Remove Home Button, Reader Button

- `fenix/app/src/main/java/org/mozilla/fenix/browser/BrowserFragment.kt`

- Comment this part (Line 100 ~ 123)

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

- Comment this part (Line 127 ~ 149)

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

- Change Line 436

```kotlin
return readerViewFeature.onBackPressed() || super.onBackPressed()
->
return super.onBackPressed()
```

### 3-4. Change Default Settings

- `fenix/app/src/main/java/org/mozilla/fenix/utils/Settings.kt`

- Change Line 380 `default = false`
- Disable History Suggestions

```kotlin
val shouldShowHistorySuggestions by booleanPreference(
    appContext.getPreferenceKey(R.string.pref_key_search_browsing_history),
    default = false,
)
```

- Change Line 390 `default = false`
- Disable SyncedTabs Suggestions

```kotlin
val shouldShowSyncedTabsSuggestions by booleanPreference(
    appContext.getPreferenceKey(R.string.pref_key_search_synced_tabs),
    default = false,
)
```

- Change Line 395 `default = false`
- Disable Clipboard Suggestions

```kotlin
val shouldShowClipboardSuggestions by booleanPreference(
    appContext.getPreferenceKey(R.string.pref_key_show_clipboard_suggestions),
    default = false,
)
```

- Change Line 989 `default = false`
- Disable Search Suggestions

```kotlin
val shouldShowSearchSuggestions by booleanPreference(
    appContext.getPreferenceKey(R.string.pref_key_show_search_suggestions),
    default = false,
)
```

- Change Line 994 `default = false`
- Disable Autocomplete In Awesomebar

```kotlin
val shouldAutocompleteInAwesomebar by booleanPreference(
    appContext.getPreferenceKey(R.string.pref_key_enable_autocomplete_urls),
    default = false,
)
```

- Change Line 1183 `featureFlag = false`
- Disable Voice Search

```kotlin
var shouldShowVoiceSearch by booleanPreference(
    appContext.getPreferenceKey(R.string.pref_key_show_voice_search),
    default = false,
)
```

- Change Line 1655 `featureFlag = false`
- Disable Unified Search

```kotlin
var showUnifiedSearchFeature by lazyFeatureFlagPreference(
    key = appContext.getPreferenceKey(R.string.pref_key_show_unified_search_2),
    default = { FxNimbus.features.unifiedSearch.value().enabled },
    featureFlag = false,
)
```

### 3-5. Enable config, Disable Safe Browsing

- `fenix/app/src/main/java/org/mozilla/fenix/gecko/GeckoProvider.kt`

- Enable `about:config` (Line 116)

```kotlin
.aboutConfigEnabled(true)
```

- Disable Safebrowsing, Replace whole `if` block under comments

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

### 3-6. Disable Progress Bar

- `fenix/app/src/main/res/drawable/progress_gradient.xml`

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

### 3-7. Customize Deafult Search Engine

- `android-components/components/feature/search/src/main/assets/searchplugins/google-b-m.xml`

```xml
<!-- This Source Code Form is subject to the terms of the Mozilla Public
   - License, v. 2.0. If a copy of the MPL was not distributed with this
   - file, You can obtain one at http://mozilla.org/MPL/2.0/. -->

<SearchPlugin xmlns="http://www.mozilla.org/2006/browser/search/">
<ShortName>Google</ShortName>
<InputEncoding>UTF-8</InputEncoding>
<Image width="16" height="16">data:image/png;base64,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</Image>
<!-- <Url type="application/x-suggestions+json" method="GET" template="https://www.google.com/complete/search?client=firefox&amp;q={searchTerms}"/> -->
<Url type="text/html" method="GET" template="https://www.google.com/search">
  <Param name="q" value="{searchTerms}"/>
  <!-- <Param name="ie" value="utf-8"/> -->
  <!-- <Param name="oe" value="utf-8"/> -->
  <!-- <Param name="client" value="firefox-b-m"/> -->
</Url>
<SearchForm>https://www.google.com</SearchForm>
</SearchPlugin>
```

- `android-components/components/feature/search/src/main/java/mozilla/components/feature/search/storage/SearchEngineReader.kt`
- Make Custom Google Search External (line 26)

```kotlin
internal const val GOOGLE_ID = "not-google"
```

- `android-components/components/feature/search/src/main/assets/search/list.json`
- Make Search Engine List only Google (line 918)

```json
{
  "zh-TW": {
    "default": {
      "visibleDefaultEngines": ["google-b-m"]
    }
  }
}
```

### 3-8. Disable Useless Settings

- `fenix/app/src/main/res/xml/preferences.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- This Source Code Form is subject to the terms of the Mozilla Public
   - License, v. 2.0. If a copy of the MPL was not distributed with this
   - file, You can obtain one at http://mozilla.org/MPL/2.0/. -->

<androidx.preference.PreferenceScreen xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto">

    <androidx.preference.Preference
        android:key="@string/pref_key_sign_in"
        android:layout="@layout/sign_in_preference"
        android:summary="@string/preferences_sign_in_description_2"
        android:title="@string/preferences_sync_2"
        app:allowDividerBelow="false" />

    <androidx.preference.SwitchPreference
        android:key="@string/pref_key_allow_domestic_china_fxa_server"
        android:title="@string/preferences_allow_domestic_china_fxa_server"
        android:defaultValue="true"/>

    <androidx.preference.PreferenceCategory
        android:key="@string/pref_key_account_category"
        android:title="@string/preferences_category_account"
        app:isPreferenceVisible="false"
        android:layout="@layout/preference_category_no_icon_style">

        <org.mozilla.fenix.settings.account.AccountPreference
            android:icon="@drawable/ic_account"
            android:key="@string/pref_key_account" />

        <org.mozilla.fenix.settings.account.AccountAuthErrorPreference
            android:icon="@drawable/ic_account_warning"
            android:key="@string/pref_key_account_auth_error" />
    </androidx.preference.PreferenceCategory>

    <androidx.preference.Preference
        app:iconSpaceReserved="false"
        android:key="@string/pref_key_sync_debug"
        android:title="@string/preferences_sync_debug"
        app:isPreferenceVisible="false" />

    <androidx.preference.PreferenceCategory
        android:title="@string/preferences_category_general"
        android:layout="@layout/preference_category_no_icon_style">
        <androidx.preference.Preference
            app:isPreferenceVisible="false"
            app:iconSpaceReserved="false"
            android:key="@string/pref_key_search_settings"
            android:title="@string/preferences_search" />

        <androidx.preference.Preference
            app:iconSpaceReserved="false"
            android:key="@string/pref_key_tabs"
            android:title="@string/preferences_tabs" />

        <androidx.preference.Preference
            app:iconSpaceReserved="false"
            android:key="@string/pref_key_home"
            android:title="@string/preferences_home_2" />

        <androidx.preference.Preference
            android:key="@string/pref_key_customize"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_customize" />

        <androidx.preference.Preference
            android:key="@string/pref_key_passwords"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_passwords_logins_and_passwords" />

        <androidx.preference.Preference
            app:iconSpaceReserved="false"
            android:key="@string/pref_key_credit_cards"
            android:title="@string/preferences_credit_cards" />

        <androidx.preference.Preference
            android:key="@string/pref_key_accessibility"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_accessibility" />

        <androidx.preference.Preference
            android:key="@string/pref_key_language"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_language" />

        <org.mozilla.fenix.settings.DefaultBrowserPreference
            android:key="@string/pref_key_make_default_browser"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_set_as_default_browser" />
    </androidx.preference.PreferenceCategory>

    <androidx.preference.PreferenceCategory
        android:title="@string/preferences_category_privacy_security"
        android:layout="@layout/preference_category_no_icon_style">

        <androidx.preference.Preference
            android:key="@string/pref_key_private_browsing"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_private_browsing_options" />

        <androidx.preference.Preference
            android:key="@string/pref_key_https_only_settings"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_https_only_title" />

        <androidx.preference.Preference
            android:key="@string/pref_key_cookie_banner_settings"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_cookie_banner_reduction"
            app:isPreferenceVisible="false" />

        <androidx.preference.Preference
            android:key="@string/pref_key_tracking_protection_settings"
            app:iconSpaceReserved="false"
            android:title="@string/preference_enhanced_tracking_protection" />

        <androidx.preference.Preference
            android:key="@string/pref_key_site_permissions"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_site_permissions" />

        <androidx.preference.Preference
            android:key="@string/pref_key_delete_browsing_data"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_delete_browsing_data" />

        <androidx.preference.Preference
            android:key="@string/pref_key_delete_browsing_data_on_quit_preference"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_delete_browsing_data_on_quit" />

        <androidx.preference.Preference
            android:key="@string/pref_key_notifications"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_notifications" />

        <androidx.preference.Preference
            android:key="@string/pref_key_data_choices"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_data_collection" />

    </androidx.preference.PreferenceCategory>

    <PreferenceCategory
        android:title="@string/preferences_category_advanced"
        android:key="@string/pref_key_advanced"
        android:layout="@layout/preference_category_no_icon_style">
        <androidx.preference.Preference
            android:key="@string/pref_key_addons"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_addons" />

        <androidx.preference.Preference
            android:key="@string/pref_key_override_amo_collection"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_customize_amo_collection" />

        <androidx.preference.Preference
            android:key="@string/pref_key_open_links_in_apps"
            android:title="@string/preferences_open_links_in_apps"
            app:iconSpaceReserved="false" />

        <androidx.preference.SwitchPreference
            android:defaultValue="false"
            android:key="@string/pref_key_external_download_manager"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_external_download_manager" />

        <androidx.preference.SwitchPreference
            android:defaultValue="true"
            android:key="@string/pref_key_leakcanary"
            android:title="@string/preference_leakcanary"
            app:iconSpaceReserved="false"
            app:isPreferenceVisible="@bool/IS_DEBUG" />

        <androidx.preference.SwitchPreference
            android:key="@string/pref_key_remote_debugging"
            android:title="@string/preferences_remote_debugging"
            app:iconSpaceReserved="false"
            android:defaultValue="false" />

        <androidx.preference.SwitchPreference
            android:defaultValue="false"
            android:key="@string/pref_key_enable_gecko_logs"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_enable_gecko_logs" />
    </PreferenceCategory>

    <androidx.preference.PreferenceCategory
        android:title="@string/preferences_category_about"
        app:iconSpaceReserved="false"
        android:layout="@layout/preference_category_no_icon_style">
        <androidx.preference.Preference
            android:key="@string/pref_key_rate"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_rate" />

        <androidx.preference.Preference
            android:key="@string/pref_key_about"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_about" />

        <androidx.preference.Preference
            android:key="@string/pref_key_debug_settings"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_debug_settings"
            app:isPreferenceVisible="false" />
        <androidx.preference.Preference
            android:key="@string/pref_key_secret_debug_info"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_debug_info"
            app:isPreferenceVisible="false" />
        <androidx.preference.Preference
            android:key="@string/pref_key_nimbus_experiments"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_nimbus_experiments"
            app:isPreferenceVisible="false" />
        <androidx.preference.Preference
            android:key="@string/pref_key_start_profiler"
            app:iconSpaceReserved="false"
            android:title="@string/preferences_start_profiler"
            app:isPreferenceVisible="false" />
    </androidx.preference.PreferenceCategory>
</androidx.preference.PreferenceScreen>
```

## 4-A. Use GitHub Actions to Build

### 4-A-1. Use GitHub Actions to Build: Add Repository Secrets

- **Note: Only for personal use, this key is different from upstream!**
- `ANDROID_SIGNING_KEY`

```sh
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
```

- `ANDROID_KEY_ALIAS`

```sh
key0
```

- `ANDROID_KEY_PASSWORD`

```sh
123456
```

- `ANDROID_KEYSTORE_PASSWORD`

```sh
123456
```

### 4-A-2. Use GitHub Actions to Build: Add Build Actions and Scripts

- `rm .github/workflows/*.yml`
- `touch .github/workflows/release.yml`

```yml
name: Release Automation
on:
  push:
    branches:
      - "main"
  workflow_dispatch:
jobs:
  release-automation:
    name: Build App
    runs-on: ubuntu-latest
    container: mingc/android-build-box:latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 1
      - name: Create version name
        run: echo "VERSION_NAME=$(cat version.txt)" >> $GITHUB_ENV
      - name: Setup release directory
        run: echo "RELEASE_DIR=fenix/app/build/outputs/apk/fenix/release/" >> $GITHUB_ENV
      - name: Build release variant of app
        run: |
          cd fenix
          git config --global --add safe.directory /__w/firefox-android/firefox-android
          free -m
          ./gradlew app:assembleRelease -Dorg.gradle.jvmargs="-XX:MaxMetaspaceSize=2g -Xms1g -Xmx3g -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/dev/stderr" -x app:lintVitalAnalyzeFenixRelease -x app:lintVitalReportFenixRelease -x app:lintVitalFenixRelease -PversionName=${{ env.VERSION_NAME }} --stacktrace
      - name: Create signed APKs
        uses: ilharp/sign-android-release@v1
        with:
          releaseDir: ${{ env.RELEASE_DIR }}
          signingKey: ${{ secrets.ANDROID_SIGNING_KEY }}
          keyAlias: ${{ secrets.ANDROID_KEY_ALIAS }}
          keyStorePassword: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          keyPassword: ${{ secrets.ANDROID_KEY_PASSWORD }}
          buildToolsVersion: 33.0.0
      - name: Rename APKs
        run: |
          if [ -f "${{ env.RELEASE_DIR }}app-fenix-arm64-v8a-release-unsigned-signed.apk" ]; then mv ${{ env.RELEASE_DIR }}app-fenix-arm64-v8a-release-unsigned-signed.apk ${{ env.RELEASE_DIR }}/fenix-custom-arm64-v8a-v${{ env.VERSION_NAME }}.apk; else echo "not find arm64-v8a release"; fi
      - name: Archive arm64-v8a apk
        uses: actions/upload-artifact@v3
        with:
          name: fenix-custom-arm64-v8a-v${{ env.VERSION_NAME }}.apk
          path: ${{ env.RELEASE_DIR }}fenix-custom-arm64-v8a-v${{ env.VERSION_NAME }}.apk
          if-no-files-found: ignore
```

### 4-A-3. Use GitHub Actions to Build: Force push to `main` branch

```bash
git push -uf origin HEAD:main
```

## 4-B. Build on macOS

- Require: [Homebrew](https://brew.sh/), [Node.js](https://nodejs.org/), [Keka](https://www.keka.io/) cli

### 4-B-1. Build on macOS: Add Build script

- `cd fenix`
- `touch build.sh`
- `chmod 755 build.sh`

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

printf "import { writeFileSync } from 'node:fs';\nwriteFileSync('$KEY_PATH', 'MIIJVwIBAzCCCRAGCSqGSIb3DQEHAaCCCQEEggj9MIII+TCCBWUGCSqGSIb3DQEHAaCCBVYEggVSMIIFTjCCBUoGCyqGSIb3DQEMCgECoIIE+zCCBPcwKQYKKoZIhvcNAQwBAzAbBBTcwuQLrkYDCcheTdlRWtnxa+66DgIDAMNQBIIEyK4j97fBaE9nghCOwGszC6/BJY06Bqyj+5Vi4V6Hps7agruO7bRtndXNUBsvfGRyzPc16TBINRk4xqGGsBxxpiJ+SgW4tho7P1mCCNa/1VaJmRfAiztKKJotBvmysQN5RXKZi8tO7U4CVxi5ZR66rwBohwKGA+zvV3UHhq4ELN13FHAKcLoA0Y/k3X8Jg8HntxWvuy7vpKj1ehPbbs7tb2K+2m5MO8tmZzOixdd6XmGCyq427t98yFHZCeuC13uKns8XsyWG9XRgzmuBqyerCq8s/M1uG+DOzR0KxBaPf0uA3XYs9xgUqa5nu+ylANox9yWYwtiamhlkjzMRNJ4RW4cHBfHhywv0ufLU2PE68LYeT/hqnbpNLJgZdTnWMhXHh6CuZJqkEmOxfhduMh5h7X8c/MjrhdzkF5ppEtz20+2JqxqaZoyt1Dv/tjB0JMDy9RXXJ54c5P2DCRfFWMXS4V6sg6KKBCo0zjCe2/QcGk3Z94k7ivkWxYpT/A7tggKbtAwW+oziwRL9o1726BSe+4itdRedBlv/is3kf3Ve/Ewv/4Q0a8JMYk6wDWsVzgcKY4AbPdfHkt3Qj/qJTRzSBLrVbZYCFcgwL1FCxb1x5KZ7Rh701Ot6/q8y/jvmarKPgVOefFSV1b/K0/BH2ZC3iRUz6GD+kjtB20ZL9MczNzeVkFkMABHAaFEMkmgM2WwWduSTcwpTWfhivYBMdAaa48hQqTOodrl+l5Old4KIcUY9oFiNt1qWpuMqAzP9wsx9UKTWvQSokhabccpOe12YlBEQuzKbUz9PnGW4GfYaiv4qiFqip5G0txArk9kmUESSBB3WXFRL1kb3Rolg5rPmFwc5ukWilW7qpAaY2lJpxbi+xOSk/gMNvatrykOyV0IANGCMVyE81fnamLMU9oW+76KCv/nDogepfeFn2xwJqI8h+xYC8foBAHuTlUaqr9Z8kBoQimiNnRZ8NjoheMS3/CBNsGOMCmcinX+sjxTc/XNgk9d1UyLN2PLnw8040hAxpLZ2kSqcmBczhSWSIclYOKPNM/xrP20b3O+r6vu0C35ZOp4eNtN0cs9Y+FP6lbW+sPtG1NCqHeRyzNSV78PCfNfQXWmYmbYP2hvCJ4XJ+e2Awv03qBtKS/CSAL+ZOPUZ6zsFX4027GIbuS3iIusXI5rXft9lEjLnN59mVwhay46PuHLXwavAUPaaJJ+ZmvHoIv3u0uwuTQ2gln4TB7mzo1fcdryRLcyEzLKzSl0z8WLtTCjtNJf7KMfNRIb/HzR0ny4hboPSOlPOmSzNX3FXUcjvDSyAEpPSPeHBCUG2+jVbG8H4vv7w7NT4ZNo+mYIXrJYKszyFTpIUt+7Bl/1KDrxTL3GKW++ktXxTwQyEEI0f89ej7B2RXWYgETsnF7uz/oQ+qbTkOj9rVqABhFxMwAK4zTelqif9YK3v8mqEVBer55ssYRdtqXO5yPEkqosSTADMelGf1OPKPoUSFSzT8QMJbsCE1OSBEZf2xOaiPLamks9XdPgT7hathQxFGNPq7ZeKITR7z+13+K7d5xKkg4p/C+0rejg1FKHOKgiIdWLERoWhDjg43iv94OFmOODq9Z5XQtreGsbQoCy9oEVvl2DgFb7BoFePLDE8MBcGCSqGSIb3DQEJFDEKHggAawBlAHkAMDAhBgkqhkiG9w0BCRUxFAQSVGltZSAxNjQxMDA1NjcyMTQ1MIIDjAYJKoZIhvcNAQcGoIIDfTCCA3kCAQAwggNyBgkqhkiG9w0BBwEwKQYKKoZIhvcNAQwBBjAbBBTg3nHiz0894xJ4XDsNkHaGgPRQTgIDAMNQgIIDOJCLq1yitB/sNzrrEx7YOV9pgSzKleF251cFjZ1Y4q/BgKBVpfWlHoKqouchAbygNd2w7z1JkcBQ+QzFNKsMEVGhVJv5BlwwzJn38U90hzA5pwgu/XGAxLK6aK7gt7Nf6yiPve9iV8C/9wcwiHQAWB8cjfRlxzsBwsVN0BCFxZ4Ty9XQAFEqLdnGfKGMGWQCcDXz7vztpqJNt2DWt27OuWdEL+lIolsu/3ouDd7c5+Zu1rY/v5uuI3af9TAvEmyJoyywLtKnpb5JqZWjx5+9ST6FY5zZzSMcpH9/x/zsLqxmieFcjtVwigMj/nkKibFzEB1mAOHEBO9OgaF1/tzj8LxevhyLNIMMY/5oa/bjB/nZ1bNCYbr9SmnlGs45VMwxM0sZt5LN4Ma8EgJhnXbWMFxZ7sW9hPR4Htw5WBOfNjWL7ZZNw8536yR7lK+PmD0DBWTAa43sVPUCq7JriheCiBhHhAuXxztqZTvfIuBoqilsaE0/apR/uFf96GzrssmKuElOH2HZNZ6x4LY0gyThAhgHUep9N5hSaAQD24iruUndef28xi6oHs5VXhEghQ8N44DeJu56R5kzLgr/MXM5zhTS8s+9C3KK318MF+bqMCBdclsnWX5QfQnZC2+5AjvVReCdvR0EmLVOk/qDYZVFeQIA3MKvW1Xz8GRUoQhlc8vkdQMGyexsY/MIV3qzIaqhvV4EQ+2+lWSG0WqY/al8uTILlIc5lEiq5RDzvsGqFILb4HAeC4sEyEHvrbVr3wlkhSy4LaTt1w2qjdQOj82UD7oDEezTnoU7PVmQTLe4eLbY5e/0RPJJCYuv3Xf2QztHOyznireoMXNvYGnGZbu85r9eXV2KSLVb5fBbBXbPdGCOFnqixNpdih5nF5XLNBeDcjX1hfaWfXHhttdeiZZ09Siy/EKClNmIa2VdFn4XhogkJQKyQn2hl+h1cQjq1Zrg12k2fM5ib1Avidy+wptXnXzIY5frN4nPiqiZjeZ9WsDJNQjqwJCEUxEgfvw7GZ7W0CA50sYRw4pQQ37RF3WRlZ8/xxgHsEtwinfQ4lFZtfSPsDeZEKbLWCU2Xui66LUsMCxwoVNbNbXJMD4wITAJBgUrDgMCGgUABBRTCJ2NA6WSxQuE4LLvPmUfFuv6pgQUj2vVQfU6PkRBmp4E1vpeVmnLXvMCAwGGoA==', 'base64');\n" >"$KEY_JS"

node "$KEY_JS"

/opt/homebrew/share/android-commandlinetools/build-tools/30.0.3/apksigner sign --ks "$KEY_PATH" --ks-key-alias key0 --ks-pass pass:123456 --key-pass pass:123456 --out "$SIGNED_APK_PATH" "$APK_PATH"

cp "$SIGNED_APK_PATH" "$DOWNLOAD_DIR/$RELEASE_APK_NAME"

cd "$RELEASE_DIR"

keka 7z a "$DOWNLOAD_DIR/$RELEASE_ZIP_NAME" "$RELEASE_APK_NAME"
```

### 4-B-2. Build on macOS: Build App

- `./build.sh`
- Signed App will name `fenix-custom-v{VERSION}.apk` in `~/Downloads`

## 4-C. Build on Docker

### 4-C-1. Build on Docker: Add Build script

- `touch docker-compose.yml`

```yml
version: "3.3"
services:
  build:
    image: mingc/android-build-box:latest
    container_name: fenix-build
    platform: linux/amd64
    volumes:
      - ./:/app
    working_dir: /app/fenix
    command: sh build.sh
```

- `touch fenix/build.sh`

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

./gradlew app:assembleRelease -Dorg.gradle.jvmargs="-XX:MaxMetaspaceSize=2g -Xms1g -Xmx3g -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/dev/stderr" -x app:lintVitalAnalyzeFenixRelease -x app:lintVitalReportFenixRelease -x app:lintVitalFenixRelease -PversionName="$VERSION" --stacktrace

printf "import { writeFileSync } from 'node:fs';\nwriteFileSync('$KEY_PATH', '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', 'base64');\n" >"$KEY_JS"

node "$KEY_JS"

/opt/android-sdk/build-tools/33.0.0/apksigner sign --ks "$KEY_PATH" --ks-key-alias key0 --ks-pass pass:123456 --key-pass pass:123456 --out "$SIGNED_APK_PATH" "$APK_PATH"

echo "Signed apk in fenix/$APK_PATH"
```

### 4-C-2. Build on Docker: Build App

- `docker-compose up`
- Signed App will name `fenix-custom-v{VERSION}.apk` in `fenix/app/build/outputs/apk/fenix/release`
