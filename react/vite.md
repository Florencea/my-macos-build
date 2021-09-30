# Vite 開發筆記

- <https://cn.vitejs.dev/>

## 注意事項

- Vite 生態系跟功能變化非常快，用於生產環境一定要鎖版本！
- 因為其特性，在 React 方面與基礎庫較友好，越重型的組件庫或生態系，出 bug 的機會越多
- 與 PWA 生態出奇友好，適合做沒有路由的單頁 PWA

## Vite

```bash
yarn create vite vite-project --template react-ts
```

```bash
cd vite-project && yarn
```

- `package.json`

```json
{
  "license": "ISC",
  "private": true
}
```

- `vite.config.ts`

```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: 500,
    rollupOptions: {
      output: {
        manualChunks: {
          antd: ["antd"],
        },
      },
    },
  },
  server: {
    proxy: {
      "/api": "http://localhost:4000/",
    },
  },
});
```

## ESLint Config Alloy TypeScript React

- 此為針對 Vite 編碼習慣特化的版本

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
    "spaced-comment": ["error", "always", { markers: ["/"] }],
  },
};
```

- `.prettierrc.js`

```js
module.exports = {
  // 行尾不需分號
  semi: false,
  // 使用單引號
  singleQuote: true,
  // 末尾不需逗號
  trailingComma: "none",
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

## mkcert + HTTP2

```bash
yarn add vite-plugin-mkcert --dev
```

- `vite.config.ts`

```ts
import { defineConfig } from "vite";
import mkcert from "vite-plugin-mkcert";

export default defineConfig({
  server: {
    https: true,
  },
  plugins: [mkcert()],
});
```

## Ant Design

- 注意：存在很多隱藏的坑，重度依賴 Antd 的話，還是去用 Umi 比較保險

```bash
yarn add antd @ant-design/icons
```

```bash
yarn add less vite-plugin-imp --dev
```

- `vite.config.ts`

```ts
import { defineConfig } from "vite";
import imp from "vite-plugin-imp";

export default defineConfig({
  plugins: [
    imp({
      libList: [
        {
          libName: "antd",
          style: (name) =>
            name === "col" || name === "row"
              ? "antd/lib/style/index.less"
              : `antd/es/${name}/style/index.less`,
        },
      ],
    }),
  ],
  css: {
    preprocessorOptions: {
      less: {
        javascriptEnabled: true,
      },
    },
  },
});
```

## Tailwind CSS

- 注意：與 Antd 一起使用會覆蓋其樣式(因為 Antd 竟然有全域 css 導入)
- `svg { vertical-align: unset; }`就是拿來治 Antd Icon 對齊的
- 與 Material-ui 或 Chakra 等封裝過樣式的組件庫較友好

```bash
yarn add tailwindcss@latest postcss@latest autoprefixer@latest --dev
```

```bash
npx tailwindcss init -p
```

```bash
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n\nsvg{vertical-align: unset;}\n' >> src/_tailwind.css
```

- `tailwind.config.js`

```js
module.exports = {
  purge: ["./src/**/*.tsx"],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {},
  },
  variants: {
    extend: {},
  },
  plugins: [],
};
```

- In `src/main.tsx`

```tsx
import "./_tailwind.css";
```

## Jest

- 初步嘗試可以跑起來，有隱藏的坑未可知

```bash
yarn add \
@babel/core \
babel-jest \
babel-preset-react-app \
@testing-library/dom \
@testing-library/jest-dom \
@testing-library/react \
@testing-library/user-event \
jest \
jest-circus \
jest-scss-transform \
jest-watch-typeahead \
identity-obj-proxy \
svg-jest \
--dev
```

```bash
touch \
.babelrc.json \
jest.config.js \
jest.css.mock.js \
jest.setup.js
```

- `.babelrc.json`

```json
{
  "env": {
    "test": {
      "presets": ["react-app"]
    }
  }
}
```

- `jest.config.js`

```js
module.exports = {
  roots: ["<rootDir>/src"],
  setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
  collectCoverageFrom: [
    "src/**/*.{js,jsx,ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/main.tsx",
  ],
  testMatch: [
    "<rootDir>/src/**/__tests__/**/*.{js,jsx,ts,tsx}",
    "<rootDir>/src/**/*.{spec,test}.{js,jsx,ts,tsx}",
  ],
  testEnvironment: "jsdom",
  transform: {
    "^.+\\.(js|jsx|mjs|cjs|ts|tsx)$": "<rootDir>/node_modules/babel-jest",
    "^.+\\.scss$": "jest-scss-transform",
    "^.+\\.css$": "<rootDir>/jest.css.mock.js",
    "\\.svg$": "svg-jest",
  },
  transformIgnorePatterns: [
    "[/\\\\]node_modules[/\\\\].+\\.(js|jsx|mjs|cjs|ts|tsx)$",
    "^.+\\.module\\.(css|sass|scss)$",
  ],
  moduleNameMapper: {
    "^.+\\.module\\.(css|sass|scss)$": "identity-obj-proxy",
  },
  watchPlugins: [
    "jest-watch-typeahead/filename",
    "jest-watch-typeahead/testname",
  ],
  resetMocks: true,
};
```

- `jest.css.mock.js`

```js
module.exports = {
  process() {
    return "module.exports = {};";
  },
  getCacheKey() {
    return "cssTransform";
  },
};
```

- `jest.setup.js`

```js
import "@testing-library/jest-dom";
```

- `package.json`

```json
{
  "scripts": {
    "test": "yarn run jest --passWithNoTests --silent --coverage --verbose --watchAll=false"
  }
}
```

- `src/App.test.tsx`

```tsx
import { render, screen } from "@testing-library/react";
import React from "react";
import App from "./App";

it("should properly rendered when routing to /", async () => {
  render(<App />);
  expect(screen.getAllByText(/Vite/)[0]).toBeInTheDocument();
});
```
