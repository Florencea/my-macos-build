# React Note

## Quick Links

- [Vite Note](vite.md)
- [UmiJS Note](umi.md)

## ESLint Config Alloy TypeScript React

- <https://github.com/AlloyTeam/eslint-config-alloy/blob/master/README.zh-CN.md>

```bash
yarn add -D \
eslint \
typescript \
@typescript-eslint/parser \
@typescript-eslint/eslint-plugin \
eslint-plugin-react \
eslint-config-alloy
```

```bash
mkdir .vscode && touch .eslintrc.js .prettierrc.js .vscode/settings.json
```

- `.eslintrc.js`

```js
module.exports = {
  extends: ['alloy', 'alloy/react', 'alloy/typescript'],
  env: {
    browser: true,
  },
  globals: {
    React: true,
  },
  rules: {},
}
```

- `.prettierrc.js`

```js
module.exports = {
  singleQuote: true,
  trailingComma: 'all',
}
```

- `.vscode/settings.json`

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
  "eslint.validate": [
    "javascript",
    "javascriptreact",
    "vue",
    "typescript",
    "typescriptreact"
  ],
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  // Prettier
  "files.eol": "\n",
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  // Shell Script
  "[shellscript]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  }
}
```
