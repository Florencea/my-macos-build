# React 開發筆記

- [React 開發筆記](#react-開發筆記)
  - [快速連結](#快速連結)
  - [Alloy TypeScript React](#alloy-typescript-react)
    - [安裝套件](#安裝套件)
    - [.eslintrc.js](#eslintrcjs)
    - [.prettierrc.js](#prettierrcjs)
  - [VSCode Settings](#vscode-settings)

## 快速連結

- [Vite 使用筆記](vite.md)
- [Umi 使用筆記](umi.md)

## Alloy TypeScript React

- [eslint-config-alloy 官方文件](https://github.com/AlloyTeam/eslint-config-alloy/blob/master/README.zh-CN.md)
- [eslint-config-alloy 規則列表與說明](https://alloyteam.github.io/eslint-config-alloy/)

### 安裝套件

```bash
yarn add eslint typescript @typescript-eslint/parser @typescript-eslint/eslint-plugin eslint-plugin-react eslint-config-alloy --dev
mkdir .vscode
touch .eslintrc.js .prettierrc.js .vscode/settings.json
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

```js
module.exports = {
  // 一行最多 120 字符
  printWidth: 120,
  // 使用 2 個空格縮進
  tabWidth: 2,
  // 不使用縮進符，而使用空格
  useTabs: false,
  // 行尾需要有分號
  semi: true,
  // 使用單引號
  singleQuote: true,
  // 對象的 key 僅在必要時用引號
  quoteProps: "as-needed",
  // jsx 不使用單引號，而使用雙引號
  jsxSingleQuote: false,
  // 末尾需要有逗號
  trailingComma: "all",
  // 大括號內的首尾需要空格
  bracketSpacing: true,
  // jsx 標簽的反尖括號需要換行
  jsxBracketSameLine: false,
  // 箭頭函數，只有一個參數的時候，也需要括號
  arrowParens: "always",
  // 每個文件格式化的范圍是文件的全部內容
  rangeStart: 0,
  rangeEnd: Infinity,
  // 不需要寫文件開頭的 @prettier
  requirePragma: false,
  // 不需要自動在文件開頭插入 @prettier
  insertPragma: false,
  // 使用默認的折行標准
  proseWrap: "preserve",
  // 根據顯示樣式決定 html 要不要折行
  htmlWhitespaceSensitivity: "css",
  // vue 文件中的 script 和 style 內不用縮進
  vueIndentScriptAndStyle: false,
  // 換行符使用 lf
  endOfLine: "lf",
  // 格式化嵌入的內容
  embeddedLanguageFormatting: "auto",
};
```

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
