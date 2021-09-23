# Vite 開發筆記

- <https://cn.vitejs.dev/>

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
import reactRefresh from "@vitejs/plugin-react-refresh";

export default defineConfig({
  plugins: [reactRefresh()],
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

## Auto import React

```bash
yarn add vite-react-jsx --dev
```

- `vite.config.ts`

```ts
import reactJsx from "vite-react-jsx";

export default {
  plugins: [reactJsx()],
};
```

- `tsconfig.json`

```json
{
  "jsx": "react-jsx"
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

```bash
yarn add antd @ant-design/icons
```

```bash
yarn add less vite-plugin-imp --dev
```

- `vite.config.ts`

```ts
import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";
import imp from "vite-plugin-imp";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    reactRefresh(),
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

```bash
yarn add @babel/core babel-jest babel-preset-react-app @testing-library/dom @testing-library/jest-dom @testing-library/react @testing-library/user-event jest jest-circus jest-scss-transform jest-watch-typeahead identity-obj-proxy svg-jest --dev
```

```bash
touch .babelrc.json jest.config.js jest.css.mock.js jest.setup.js
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
