# Verified External Documentation Lookup Matrix

Verify CLI flags locally (`<tool> --help`) before fetching external documentation. For large hubs, run Stage 1 (`llms.txt` or index) first, then retrieve only the targeted path via `webread`.

## Tool & Framework Lookup Endpoints

- **Vite+**: `vp --help` / `vp <cmd> --help` | `webread https://viteplus.dev/llms.txt` -> `/guide/<topic>.md`
- **Oxc (`oxlint` / `oxfmt`)**: `vp lint --rules` / `vp lint --help` | `webread https://oxc.rs/llms.txt` -> `/docs/guide/usage/linter/rules/...md`
- **Antigravity**: — | `webread https://antigravity.google/llms.txt` -> `/docs/<topic>`
- **PowerShell**: `Get-Command <cmd> -Syntax` | `webread https://raw.githubusercontent.com/MicrosoftDocs/PowerShell-Docs/main/reference/docs-conceptual/toc.yml` + `https://raw.githubusercontent.com/PoshCode/PowerShellPracticeAndStyle/master/README.md`
- **DuckDB**: `duckdb --help` | `webread https://duckdb.org/llms.txt` -> targeted doc page
- **ast-grep**: `ast-grep --help` / `sg --help` | `webread https://ast-grep.github.io/llms.txt` -> targeted doc page
- **yt-dlp**: `yt-dlp --help` | `webread https://github.com/yt-dlp/yt-dlp#usage-and-options`
- **FFmpeg / FFprobe**: `ffmpeg -h full` / `ffprobe -h` | `webread https://ffmpeg.org/ffmpeg.html`
- **gifski**: `gifski --help` | `webread https://github.com/ImageOptim/gifski`
- **sqlite3**: `sqlite3 --help` | `webread https://www.sqlite.org/cli.html`
- **xsv**: `xsv --help` | `webread https://github.com/BurntSushi/xsv`
- **ripgrep**: `rg --help` | `webread https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md`
- **fd / bat / tokei**: `<tool> --help` | `webread https://github.com/sharkdp/fd` / `https://github.com/sharkdp/bat` / `https://github.com/XAMPPRocky/tokei`
- **sd / xh / dust**: `<tool> --help` | `webread https://github.com/chmln/sd` / `https://github.com/ducaale/xh` / `https://github.com/bootandy/dust`
- **jq / yq**: `jq --help` / `yq --help` | `webread https://jqlang.github.io/jq/manual/` / `https://mikefarah.gitbook.io/yq/`
- **shfmt**: `shfmt --help` | `webread https://github.com/mvdan/sh`
- **actionlint**: `actionlint -help` | `webread https://github.com/rhysd/actionlint/blob/main/docs/usage.md`
- **hyperfine**: `hyperfine --help` | `webread https://github.com/sharkdp/hyperfine`
- **pdftotext**: `pdftotext -h` | `webread https://linux.die.net/man/1/pdftotext`
