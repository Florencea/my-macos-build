# React 開發筆記

## 快速連結

- [Vite 使用筆記](vite.md)
- [Umi 使用筆記](umi.md)

## Alloy TypeScript React

- [eslint-config-alloy 官方文件](https://github.com/AlloyTeam/eslint-config-alloy/blob/master/README.zh-CN.md)
- [eslint-config-alloy 規則列表與說明](https://alloyteam.github.io/eslint-config-alloy/)

### 安裝套件

```bash
yarn add eslint typescript @typescript-eslint/parser @typescript-eslint/eslint-plugin eslint-plugin-react eslint-config-alloy --dev
```

```bash
mkdir .vscode && touch .eslintrc.js .prettierrc.js .vscode/settings.json
```

### .eslintrc.js

```js
module.exports = {
  extends: ["alloy", "alloy/react", "alloy/typescript"],
  env: {
    // 你的環境變量（包含多個預定義的全局變量）
    //
    browser: true,
    // node: true,
    // mocha: true,
    // jest: true,
    // jquery: true
  },
  globals: {
    // 你的全局變量（設置為 false 表示它不允許被重新賦值）
    //
    // myGlobal: false
    React: true,
  },
  rules: {
    // 自定義你的規則
  },
};
```

### .prettierrc.js

- 可參考[alloy 團隊的配置](https://github.com/AlloyTeam/eslint-config-alloy/blob/master/README.zh-CN.md#%E5%A6%82%E4%BD%95%E7%BB%93%E5%90%88-prettier-%E4%BD%BF%E7%94%A8)，但除了以下配置外其餘都是預設值可以不寫

```js
module.exports = {
  // 使用單引號 [預設值是 false]
  singleQuote: true,
  // 末尾需要有逗號 [預設值是 'es5']
  trailingComma: "all",
};
```

## VSCode Settings

- 挑需要的部分複製入`.vscode/settings.json`即可

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
  // shellscript
  "[shellscript]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  },
  // markdown
  "markdownlint.config": {
    "MD033": false
  }
}
```
