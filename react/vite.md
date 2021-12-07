# Vite Note

- <https://cn.vitejs.dev/>
- Works with npm, yarn, pnpm

## Vite

```bash
npm init -y vite@latest vite-project -- --template react-ts
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
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: 500,
    rollupOptions: {
      output: {
        manualChunks: {
          antd: ['antd'],
        },
      },
    },
  },
  server: {
    proxy: {
      '/api': 'http://localhost:4000/',
    },
  },
});
```

## ESLint Config Alloy TypeScript React

```bash
npm install -D \
eslint \
@typescript-eslint/parser \
@typescript-eslint/eslint-plugin \
eslint-plugin-react \
eslint-config-alloy
```

- `package.json`

```json
{
  "eslintConfig": {
    "extends": ["alloy", "alloy/react", "alloy/typescript"],
    "env": {
      "browser": true
    },
    "globals": {
      "React": "readonly"
    },
    "rules": {
      "spaced-comment": [
        "error",
        "always",
        {
          "markers": ["/"]
        }
      ],
      "@typescript-eslint/no-require-imports": 0
    }
  }
}
```

## Ant Design

```bash
npm install antd @ant-design/icons
```

```bash
npm install -D less vite-plugin-imp
```

- `vite.config.ts`

```ts
import { defineConfig } from 'vite';
import imp from 'vite-plugin-imp';

export default defineConfig({
  plugins: [
    imp({
      libList: [
        {
          libName: 'antd',
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

```tsx
import { ConfigProvider } from 'antd';
import zhTW from 'antd/es/locale/zh_TW';
import 'moment/dist/locale/zh-TW';
import { StrictMode } from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import './index.css';

ReactDOM.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>,
  document.getElementById('root'),
);
```

## Tailwind CSS

```bash
npm install -D tailwindcss@latest postcss@latest autoprefixer@latest
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
  important: '#root',
  purge: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  darkMode: false,
  theme: {
    colors: {
      white: '#fff',
      black: '#000',
      ...require('@ant-design/colors'),
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

```bash
npm install -D \
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
svg-jest
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
  roots: ['<rootDir>/src'],
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  collectCoverageFrom: ['src/**/*.{js,jsx,ts,tsx}', '!src/**/*.d.ts', '!src/**/main.tsx'],
  testMatch: ['<rootDir>/src/**/__tests__/**/*.{js,jsx,ts,tsx}', '<rootDir>/src/**/*.{spec,test}.{js,jsx,ts,tsx}'],
  testEnvironment: 'jsdom',
  transform: {
    '^.+\\.(js|jsx|mjs|cjs|ts|tsx)$': '<rootDir>/node_modules/babel-jest',
    '^.+\\.scss$': 'jest-scss-transform',
    '^.+\\.css$': '<rootDir>/jest.css.mock.js',
    '\\.svg$': 'svg-jest',
  },
  transformIgnorePatterns: [
    '[/\\\\]node_modules[/\\\\].+\\.(js|jsx|mjs|cjs|ts|tsx)$',
    '^.+\\.module\\.(css|sass|scss)$',
  ],
  moduleNameMapper: {
    '^.+\\.module\\.(css|sass|scss)$': 'identity-obj-proxy',
  },
  watchPlugins: ['jest-watch-typeahead/filename', 'jest-watch-typeahead/testname'],
  resetMocks: true,
};
```

- `jest.css.mock.js`

```js
module.exports = {
  process() {
    return 'module.exports = {};';
  },
  getCacheKey() {
    return 'cssTransform';
  },
};
```

- `jest.setup.js`

```js
import '@testing-library/jest-dom';
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
import { render, screen } from '@testing-library/react';
import React from 'react';
import App from './App';

it('should properly rendered when routing to /', async () => {
  render(<App />);
  expect(screen.getAllByText(/Vite/)[0]).toBeInTheDocument();
});
```
