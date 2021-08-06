# Rust 開發筆記

## VSCode Config

```bash
mkdir .vscode && touch .vscode/settings.json
```

- `.vscode/settings.json`

```jsonc
{
  // Prettier
  "files.eol": "\n",
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  // Shell Script
  "[shellscript]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  },
  // Markdown
  "markdownlint.config": {
    "MD033": false
  },
  // Rust
  "[rust]": {
    "editor.defaultFormatter": "rust-lang.rust"
  }
}
```
