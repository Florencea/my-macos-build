# Firefox Note

- [Firefox Note](#firefox-note)
  - [Configuration Tweaks](#configuration-tweaks)
  - [Custom CSS](#custom-css)
    - [Fix GitHub icon issue in Dark mode](#fix-github-icon-issue-in-dark-mode)
  - [Firefox DevTools Device Profile](#firefox-devtools-device-profile)
    - [Google Pixel 10 pro XL](#google-pixel-10-pro-xl)
      - [Full](#full)
      - [High](#high)

## Configuration Tweaks

```sh
# about:config
# Disable translation
browser.translations.enable false
# Enable Custom CSS
toolkit.legacyUserProfileCustomizations.stylesheets true
```

## Custom CSS

### Fix GitHub icon issue in Dark mode

- Open Profile Folder
- mkdir `chrome`

```css
@media (prefers-color-scheme: dark) {
  .bookmark-item[label="GitHub"] .toolbarbutton-icon {
    filter: invert(100%);
  }
}
```

## Firefox DevTools Device Profile

- Android Browser User Agent

```text
Mozilla/5.0 (Android 16; Mobile; rv:VERSION.0) Gecko/VERSION.0 Firefox/VERSION.0
```

- Example

```text
Mozilla/5.0 (Android 16; Mobile; rv:146.0) Gecko/146.0 Firefox/146.0
```

### Google Pixel 10 pro XL

#### Full

- Screen: `448 x 998`
- DPR: `3`

#### High

- Screen: `450 x 853`
- DPR: `2.4`
