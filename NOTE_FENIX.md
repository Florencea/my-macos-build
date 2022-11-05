# Fenix Note

## Build Guide

### 1. Install Android Studio

```bash
brew install android-studio
```

### 2. Clone Release Branch (Tag)

```bash
git clone --depth 1 --branch v106.1.0 git@github.com:mozilla-mobile/fenix.git
```

### 3. Edit Files

- Add `local.properties`

```properties
autosignReleaseWithDebugKey
```

- `app/build.gradle`
- Change Default AMO Collections and speedup build

```bash
buildConfigField "String", "AMO_COLLECTION_NAME", "\"7dfae8669acc4312a65e8ba5553036\"" -> buildConfigField "String", "AMO_COLLECTION_NAME", "\"1\""
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
- Comment this part (Line 75 ~ 85)
- see [For #23076 - Clean up unneeded FeatureFlags](https://github.com/mozilla-mobile/fenix/commit/76fb147ed87c32f37b6b92db1a0d0b3541308d86)

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

### 4. Import Project to Android Studio

### 5. Choose Build Variant: `release`

### 6. Build APK

- Wait until Gradle Sync Finished.
- `Build -> Build Bundle(s) / APK(s) -> Build APK(s)`
- Result APK in `app/build/outputs/apk/release/app-arm64-v8a-release.apk`
