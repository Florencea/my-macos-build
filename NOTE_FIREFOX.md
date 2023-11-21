# Firefox Note

- [Firefox Note](#firefox-note)
  - [DevTools Device Profile](#devtools-device-profile)
    - [Google Pixel 7a](#google-pixel-7a)
    - [Google Pixel 4a](#google-pixel-4a)
  - [Customize Appearance](#customize-appearance)
  - [`about:config`](#aboutconfig)

## DevTools Device Profile

- Android Browser User Agent

```text
Mozilla/5.0 (Android <ANDROID_VERSION>; Mobile; rv:109.0) Gecko/<FIREFOX_MAJOR_VERSION>.0 Firefox/<FIREFOX_MAJOR_VERSION>.0
```

- Example

```text
Mozilla/5.0 (Android 13; Mobile; rv:109.0) Gecko/120.0 Firefox/120.0
```

### Google Pixel 7a

- Screen: `414 x 794`
- DPR: `2.608695652173913`

### Google Pixel 4a

- Screen: `396 x 858`
- DPR: `2.727272727272727`

## Customize Appearance

- Go to Firefox Profile Directory (`about:support` -> Profile Directory -> Show in Finder)
- In Profile Directory, Create a Directory called `chrome`
- `<Profile Directory>/chrome/userChrome.css`

```css
/* No blue swipe on tabs when loaded */
.tabbrowser-tab .tab-loading-burst {
  display: none !important;
}
```

- `about:config`

```sh
toolkit.legacyUserProfileCustomizations.stylesheets true
```

- Restart Firefox

## `about:config`

```sh
# Disable UI Animation
# Note: Could use System Settings -> Accessibility -> Reduce motion
ui.prefersReducedMotion 1
xul.panel-animations.enabled false
# DNS over HTTPS
# Note: In macOS 13, System DNS will automatically use DoH if supported, and the query follow IP Addrress Family. I recommend to use System DNS instead
network.trr.mode 3
network.trr.custom_uri https://dns.google/dns-query
network.trr.uri https://dns.google/dns-query
network.trr.disable-ECS false
network.trr.useGET true
# Use prefetch
# Note: Default value do not need to change in Stable Release
network.prefetch-next true
network.dns.disablePrefetch false
network.dns.disablePrefetchFromHTTPS false
# Disable Pocket
extensions.pocket.enabled false
# Disable Reader Mode Parsing
reader.parse-on-load.enabled false
```
