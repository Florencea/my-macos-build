# React 開發筆記

- [Vite 使用筆記](vite.md)
- [Umi 使用筆記](umi.md)

## VSCode Settings

```jsonc
{
  // Typescript
  "typescript.tsdk": "node_modules/typescript/lib",
  // TailWindCSS
  "css.validate": false,
  "editor.quickSuggestions": {
    "strings": true
  },
  "tailwindCSS.emmetCompletions": true,
  "tailwindCSS.includeLanguages": {
    "plaintext": "html"
  },
  // ESLint
  "eslint.validate": ["javascript", "javascriptreact", "vue", "typescript", "typescriptreact"],
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  // Prettier
  "files.eol": "\n",
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  // shellscript
  "[shellscript]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  },
  // markdown
  "markdownlint.config": {
    "MD033": false
  }
  // python
  "[python]": {
    "editor.defaultFormatter": "ms-python.python",
    "editor.formatOnSave": true
  },
  "python.formatting.autopep8Args": ["--ignore", "E24,E501"],
  "python.languageServer": "Pylance",
  "python.linting.pycodestyleArgs": [
    "--ignore=E121,E123,E126,E226,E24,E704,W503,E501"
  ],
  "python.linting.pycodestyleEnabled": true,
}
```
