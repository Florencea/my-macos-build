# Vite 開發筆記

- <https://cn.vitejs.dev/>

## 注意事項

- Vite 生態系跟功能變化非常快，用於生產環境一定要鎖版本！
- 因為其特性，在 React 方面與基礎庫較友好，越重型的組件庫或生態系，出 bug 的機會越多
- 與 PWA 生態出奇友好，適合做沒有路由的單頁 PWA

## Vite

```bash
npm init vite@latest vite-project -- --template react-ts
```

```bash
cd vite-project && npm install
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

- 此為針對 Vite 特化的版本

```bash
npm install \
eslint \
typescript \
@typescript-eslint/parser \
@typescript-eslint/eslint-plugin \
eslint-plugin-react \
eslint-config-alloy \
--save-dev
```

```bash
mkdir .vscode && touch .eslintrc.js .prettierrc.js .vscode/settings.json
```

- `.eslintrc.js`

```js
module.exports = {
  extends: ["alloy", "alloy/react", "alloy/typescript"],
  env: {
    browser: true,
  },
  globals: {
    React: "readonly",
  },
  rules: {
    "spaced-comment": ["error", "always", { markers: ["/"] }],
    "@typescript-eslint/no-require-imports": 0,
  },
};
```

- `.prettierrc.js`

```js
module.exports = {
  singleQuote: true,
  trailingComma: "all",
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
  }
}
```

## mkcert + HTTP2

```bash
npm install vite-plugin-mkcert --save-dev
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

- 注意：存在隱藏的坑未可知，需要不斷修正

```bash
npm install antd @ant-design/icons
```

```bash
npm install less vite-plugin-imp --save-dev
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
          style: (name) => `antd/es/${name}/style`,
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

- `src/main.tsx`
- 為了使國際化介面不要出錯

```tsx
import { ConfigProvider } from "antd";
import zhTW from "antd/es/locale/zh_TW";
import "moment/dist/locale/zh-TW";
import { StrictMode } from "react";
import ReactDOM from "react-dom";
import App from "./App";
import "./index.css";

ReactDOM.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>,
  document.getElementById("root")
);
```

## Tailwind CSS

- 禁用`preflight`是為了不要在預設狀況干涉`antd`樣式
- 配置`important`是為了能夠覆蓋`antd`樣式，但不干擾行內樣式
- `colors`配置可以直接使用`@ant-design/colors`色版，與`antd`搭配時色彩較和諧

```bash
npm install tailwindcss@latest postcss@latest autoprefixer@latest --save-dev
```

```bash
npx tailwindcss init -p
```

```bash
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' > src/index.css
```

- `tailwind.config.js`

```js
module.exports = {
  corePlugins: {
    preflight: false,
  },
  important: "#root",
  purge: ["./index.html", "./src/**/*.{vue,js,ts,jsx,tsx}"],
  darkMode: false,
  theme: {
    colors: {
      white: "#fff",
      black: "#000",
      ...require("@ant-design/colors"),
    },
    extend: {},
  },
  variants: {
    extend: {},
  },
  plugins: [],
};
```

## Jest

- 初步嘗試可以跑起來，有隱藏的坑未可知，先擱置

```bash
npm install \
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
--save-dev
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
