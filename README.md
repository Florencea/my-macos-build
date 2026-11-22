# My macOS Build

## Extension Configs

- [UBoL Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/ubol-config.json)
- [Stylus Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/stylus.json)
- [Tampermonkey Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/tampermonkey.json)
- [Immersive Translate](https://github.com/Florencea/my-macos-build/raw/main/configs/immersive-translate-config.json)

## Notes

- [macOS Note](./MACOS.md)
- [Media Note](./MEDIA.md)

## Table of Contents

- [Extension Configs](#extension-configs)
- [Notes](#notes)
- [Browser & DevTools Note](#browser--devtools-note)
  - [Pagetual Rules](#pagetual-rules)
    - [`share.dmhy.org`](#sharedmhyorg)
    - [`E-Hentai / ExHentai (Gallery & List)`](#e-hentai--exhentai-gallery--list)
    - [`E-Hentai / ExHentai (Reader - Auto Preload)`](#e-hentai--exhentai-reader---auto-preload)
  - [Microsoft Edge for DevTools Device Profile](#microsoft-edge-for-devtools-device-profile)
    - [Google Pixel 10 pro XL](#google-pixel-10-pro-xl)
      - [Full](#full)
      - [High](#high)

## Browser & DevTools Note

### Pagetual Rules

#### `share.dmhy.org`

```json
{
  "name": "動漫花園",
  "author": "skofkyo",
  "example": "http://share.dmhy.org/topics/list/sort_id/2",
  "url": "^https?://(www|share|dmhy)?(\\.)?(dmhy|anoneko)\\.(org|com)",
  "action": 1,
  "nextLink": "//a[text()='下一頁']",
  "pageElement": "thead+tbody",
  "replaceElement": ".table.clear>.nav_title,script+.nav_title",
  "rate": 3,
  "pageBar": 0,
  "sideController": false
}
```

#### `E-Hentai / ExHentai (Gallery & List)`

```json
{
  "name": "E-Hentai / ExHentai (Gallery & List)",
  "author": "skofkyo",
  "example": "https://exhentai.org/g/*, https://exhentai.org/?f_search=*",
  "url": "^https?://(e-hentai|exhentai)\\.org/(?!s/).*",
  "nextLink": "//table[@class='ptt']//a[string()='>'] | id('next') | id('unext')",
  "pageElement": ".itg>div,.itg>tbody>tr:not(:first-of-type),.gl1t, #gdt>div:not(.c),#gdt>a:not(.c), #img",
  "replaceElement": ".ptt,.ptb,.sn,.searchnav",
  "css": "#img {max-width: 100% !important;height: auto !important;min-height: 400px;}",
  "pageInit": "let img=doc.getElementById('img');img&&img.setAttribute('onerror','setTimeout(()=>{this.src=this.src.replace(/(\\\\?time=.*)?$/,`?time=${Date.now()}`)},3000)');",
  "pageBar": 0,
  "sideController": false,
  "action": 0
}
```

#### `E-Hentai / ExHentai (Reader - Auto Preload)`

```json
{
  "name": "E-Hentai / ExHentai (Reader - Auto Preload)",
  "author": "skofkyo",
  "example": "https://exhentai.org/s/*",
  "url": "^https?://(e-hentai|exhentai)\\.org/s/.*",
  "nextLink": "//table[@class='ptt']//a[string()='>'] | id('next') | id('unext')",
  "pageElement": ".itg>div,.itg>tbody>tr:not(:first-of-type),.gl1t, #gdt>div:not(.c),#gdt>a:not(.c), #img",
  "replaceElement": ".ptt,.ptb,.sn,.searchnav",
  "css": "#img {max-width: 100% !important;height: auto !important;min-height: 400px;}",
  "pageInit": "let img=doc.getElementById('img');img&&img.setAttribute('onerror','setTimeout(()=>{this.src=this.src.replace(/(\\\\?time=.*)?$/,`?time=${Date.now()}`)},3000)');",
  "pageBar": 0,
  "sideController": false,
  "action": 1,
  "autoLoadNum": 9999
}
```

### Microsoft Edge for DevTools Device Profile

- Android Browser User Agent

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/VERSION.0.0.0 Mobile Safari/537.36 EdgA/VERSION.0.0.0
```

- Example

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Mobile Safari/537.36 EdgA/156.0.0.0
```

#### Google Pixel 10 pro XL

##### Full

- Screen: `448 x 998`
- DPR: `3`

##### High

- Screen: `444 x 987`
- DPR: `2.44`
