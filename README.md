# My macOS Build

## Quick Links

- [Media Note](NOTE_MEDIA.md)
- [Fenix Note](NOTE_FENIX.md)
- [Firefox Note](NOTE_FIREFOX.md)
- [macOS Note](NOTE_MACOS.md)

## Execute Media Scripts (vv) from remote

- **Note:** [`ffmpeg`](https://ffmpeg.org) and [`yt-dlp`](https://github.com/yt-dlp/yt-dlp) required in PATH.
- Use [Node.js](https://nodejs.org/en)

```sh
npx -y github:Florencea/my-macos-build
```

- Use [deno](https://deno.com/)

```sh
deno run -A 'https://raw.githubusercontent.com/Florencea/my-macos-build/main/scripts/vv.mjs'
```

## Extension Configs

- [uBlock Origin Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/ubo-config.txt)
- [Tampermonkey Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/userscript.zip)
