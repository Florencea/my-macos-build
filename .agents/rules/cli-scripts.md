---
trigger: glob
globs: "cli/*.sh"
description: Rules for authoring, linking, and verifying macOS Bash 3.2 CLI scripts under cli/*.sh.
---

# macOS Bash 3.2 CLI Script Rules

## 1. Portability & Fail-Fast Execution

- **Shebang & Strict Mode**: Start every command script with `#!/usr/bin/env bash` and `set -euo pipefail`. Keep executable permissions (`chmod 755 cli/<cmd>.sh`).
- **macOS Bash 3.2 Compatibility**: Avoid Bash 4+ features (`readarray`, `mapfile`, `declare -A`, `${var,,}`, `|&`, `&>>`). Always use `while IFS= read -r` for line iteration, `realpath "$0"` for physical paths, `mktemp -t <prefix>.XXXXXX` for temporary paths, and guard empty arrays before expansion (`if [[ ${#arr[@]} -gt 0 ]]`).
- **Fail-Fast & Concise Style**: Document summary and usage in top header comments; omit `--help` flags and verbose argument validation. Rely on `set -euo pipefail` and native error output from underlying binaries (`ffmpeg`, `ffprobe`, `gifski`, `yt-dlp`, `git`, `curl`, `jq`, `brew`, `fnm`, `code`), keeping minimal guards only before destructive deletions (`rm -rf` in `rea.sh`).

---

## 2. System Exposure & Fish Completion Parity

- **Symlinks (`~/.local/bin/`)**: `scripts/install.sh` symlinks `cli/*.sh` to `~/.local/bin/<cmd>` without `.sh` and prunes broken symlinks pointing into `cli/`.
- **Fish Completions**: Maintain matching flag and positional completions under `configs/fish/completions/<cmd>.fish`.
- **Verification**: Validate every edit with `bash -n`, `shellcheck`, `shfmt -i 2 -ci -w`, and `fish_indent -w`.
