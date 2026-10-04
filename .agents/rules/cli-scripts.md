---
trigger: glob
globs: "cli/*.sh"
description: Rules for managing, authoring, and formatting executable CLI scripts in cli/.
---

# CLI Script Management Rules

## 1. Naming, Permissions & Strict Header

- Store executable shell scripts under `cli/<command>.sh`.
- Use the standard shebang and strict execution headers:
  ```zsh
  #!/bin/zsh
  emulate -L zsh
  set -euo pipefail
  ```
- Ensure scripts have executable permissions: `chmod +x cli/<command>.sh`.

---

## 2. Mandatory `--help` & `-h` Support (Black-Box Rule)

- All CLI scripts under `cli/<command>.sh` MUST implement `-h` and `--help` option parsing at the beginning of the script.
- When invoked with `-h` or `--help`, the script must output Description, Usage, Options (if applicable), and Examples, and cleanly exit with code 0 (`exit 0`).
- This ensures agents and users can safely inspect usage without triggering unintended executions or mutations.

---

## 3. System Symlinks in `~/.local/bin`

- All CLI scripts are exposed system-wide without the `.sh` extension via `$HOME/.local/bin`.
- **Adding**: Create a symlink without extension:
  ```bash
  ln -sf "$PWD/cli/<command>.sh" "$HOME/.local/bin/<command>"
  ```
- **Removing / Renaming**: Delete the corresponding symlink:
  ```bash
  rm -f "$HOME/.local/bin/<command>"
  ```

---

## 4. Code Formatting

- Formatter: `shfmt`
- Command: `shfmt -i 2 -ci -w cli/*.sh`
- Indentation: 2 spaces.
