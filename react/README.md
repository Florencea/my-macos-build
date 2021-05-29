# React Note

## Quick Link

- [Vite Note](vite.md)
- [Umi Note](umi.md)

## ESLint Config Alloy TypeScript React

- <https://github.com/AlloyTeam/eslint-config-alloy>

```bash
yarn add eslint typescript @typescript-eslint/parser @typescript-eslint/eslint-plugin eslint-plugin-react eslint-config-alloy --dev
```

```bash
mkdir .vscode && touch .eslintrc.js .prettierrc.js .vscode/settings.json
```

- `.eslintrc.js`

```js
module.exports = {
  extends: ["alloy", "alloy/react", "alloy/typescript"],
  env: {
    // Your environments (which contains several predefined global variables)
    //
    browser: true,
    // node: true,
    // mocha: true,
    // jest: true,
    // jquery: true
  },
  globals: {
    // Your global variables (setting to false means it's not allowed to be reassigned)
    //
    // myGlobal: false
    React: true,
  },
  rules: {
    // Customize your rules
  },
};
```

- `.prettierrc.js`

```js
// .prettierrc.js
module.exports = {
  // max 120 characters per line
  printWidth: 120,
  // use 2 spaces for indentation
  tabWidth: 2,
  // use spaces instead of indentations
  useTabs: false,
  // semicolon at the end of the line
  semi: true,
  // use single quotes
  singleQuote: true,
  // object's key is quoted only when necessary
  quoteProps: "as-needed",
  // use double quotes instead of single quotes in jsx
  jsxSingleQuote: false,
  // no comma at the end
  trailingComma: "all",
  // spaces are required at the beginning and end of the braces
  bracketSpacing: true,
  // end tag of jsx need to wrap
  jsxBracketSameLine: false,
  // brackets are required for arrow function parameter, even when there is only one parameter
  arrowParens: "always",
  // format the entire contents of the file
  rangeStart: 0,
  rangeEnd: Infinity,
  // no need to write the beginning @prettier of the file
  requirePragma: false,
  // No need to automatically insert @prettier at the beginning of the file
  insertPragma: false,
  // use default break criteria
  proseWrap: "preserve",
  // decide whether to break the html according to the display style
  htmlWhitespaceSensitivity: "css",
  // vue files script and style tags indentation
  vueIndentScriptAndStyle: false,
  // lf for newline
  endOfLine: "lf",
  // formats quoted code embedded
  embeddedLanguageFormatting: "auto",
};
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
  },
  // Markdown
  "markdownlint.config": {
    "MD033": false
  }
}
```
