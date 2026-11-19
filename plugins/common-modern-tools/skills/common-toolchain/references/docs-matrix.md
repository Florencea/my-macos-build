# Verified External Documentation Lookup Matrix

Verify CLI flags locally (`<tool> --help`) before fetching external documentation. For large hubs, run Stage 1 (`llms.txt` or index) first via `curl -fsSL`, then retrieve only the targeted path.

## Tool & Framework Lookup Endpoints

- **ESLint / typescript-eslint**: `npx eslint --help` / `npx eslint --print-config <file>` | `https://eslint.org/docs/latest/rules/` / `https://typescript-eslint.io/rules/`
- **Prettier**: `npx prettier --help` | `curl -fsSL https://prettier.io/llms.txt` -> `https://prettier.io/docs/options`
- **Antigravity**: — | `curl -fsSL https://antigravity.google/llms.txt` -> `/docs/<topic>`
- **ast-grep**: `ast-grep --help` / `sg --help` | `curl -fsSL https://ast-grep.github.io/llms.txt` -> targeted doc page
- **yt-dlp**: `yt-dlp --help` | `https://github.com/yt-dlp/yt-dlp#usage-and-options`
- **FFmpeg / FFprobe**: `ffmpeg -h full` / `ffprobe -h` | `https://ffmpeg.org/ffmpeg.html`
- **gifski**: `gifski --help` | `https://github.com/ImageOptim/gifski`
- **ripgrep**: `rg --help` | `https://raw.githubusercontent.com/BurntSushi/ripgrep/master/GUIDE.md`
- **fd**: `fd --help` | `https://github.com/sharkdp/fd`
- **jq / yq**: `jq --help` / `yq --help` | `https://jqlang.github.io/jq/manual/` / `https://mikefarah.gitbook.io/yq/`
- **shfmt**: `shfmt --help` | `https://github.com/mvdan/sh`
- **actionlint**: `actionlint -help` | `https://raw.githubusercontent.com/rhysd/actionlint/main/docs/usage.md`
- **fish**: `fish --help` / `fish_indent --help` | `https://fishshell.com/docs/current/`
- **fnm**: `fnm --help` | `https://github.com/Schniz/fnm`
