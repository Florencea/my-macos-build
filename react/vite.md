# Vite

- [Vite](#vite)
  - [Vite + TypeScript + Google TypeScript Style + Tailwind CSS + Ant Design + Jest](#vite--typescript--google-typescript-style--tailwind-css--ant-design--jest)
    - [Commends](#commends)
    - [Files](#files)
    - [Yarn](#yarn)
    - [Git](#git)

## Vite + TypeScript + Google TypeScript Style + Tailwind CSS + Ant Design + Jest

### Commends

```fish
# Packages
yarn create @vitejs/app vite-project --template react-ts
cd vite-project && yarn
mkdir test src/components
yarn remove vite @vitejs/plugin-react-refresh --dev
yarn add ts-node jest jest-css-modules @babel/core @babel/preset-react babel-jest ts-jest svg-jest @types/react eslint eslint-plugin-node eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise typescript --force --dev
yarn add antd @ant-design/icons swr tailwindcss@latest postcss@latest autoprefixer@latest @testing-library/jest-dom @testing-library/react @jest/types vite @vitejs/plugin-react-refresh
# Google gts
npx gts init -y --yarn
rm src/index.ts
# Tailwind CSS
npx tailwindcss init -p
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' >> src/_tailwind.css
# Jest
touch jest.config.ts
touch test/App.test.tsx
# Open VSCode
code .
```

### Files

- `package.json`

```json
{
  "license": "ISC",
  "scripts": {
    "test": "jest --passWithNoTests --no-cache --silent --coverage --verbose --watchAll=false",
    "dev": "vite",
    "build": "tsc && vite build",
    "serve": "vite preview",
    "lint": "gts lint",
    "clean": "gts clean",
    "compile": "tsc",
    "fix": "gts fix",
    "prepare": "yarn run compile",
    "pretest": "yarn run compile",
    "posttest": "yarn run lint"
  }
}
```

- `tsconfig.json`

```json
{
  "extends": "./node_modules/gts/tsconfig-google.json",
  "compilerOptions": {
    "outDir": "build",
    "target": "ESNext",
    "lib": ["DOM", "DOM.Iterable", "ESNext"],
    "types": ["vite/client"],
    "allowJs": false,
    "skipLibCheck": false,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react"
  },
  "include": ["src/**/*.ts", "src/**/*.tsx", "test/**/*.ts", "test/**/*.tsx"]
}
```

- `.eslintrc.json`

```json
{
  "extends": [
    "./node_modules/gts/",
    "plugin:react/recommended",
    "plugin:jsx-a11y/recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "plugin:promise/recommended"
  ],
  "env": {
    "browser": true,
    "jest": true
  },
  "plugins": ["react", "jsx-a11y", "import", "promise"],
  "settings": {
    "react": {
      "version": "detect"
    }
  }
}
```

- `.eslintignore`

```text
build/
coverage/
node_modules/
```

- `vite.config.ts`

```typesctipt
import {defineConfig} from 'vite';
import reactRefresh from '@vitejs/plugin-react-refresh';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [reactRefresh()],
  build: {
    outDir: 'build',
  },
});
```

- `tailwind.config.js`

```javascript
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

- `src/main.tsx`

```tsx
import React from "react";
import ReactDOM from "react-dom";
import "antd/dist/antd.css";
import "./_tailwind.css";
import "./index.css";
import App from "./App";

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById("root")
);
```

- `jest.config.ts`

```typescript
import type { Config } from "@jest/types";

export default async (): Promise<Config.InitialOptions> => {
  return {
    preset: "ts-jest",
    moduleNameMapper: {
      "\\.(css|less|scss|sss|styl)$": "<rootDir>/node_modules/jest-css-modules",
    },
    transform: {
      "\\.svg$": "svg-jest",
    },
    collectCoverageFrom: [
      "**/*.{ts,tsx}",
      "!**/jest.config.ts",
      "!**/jest.setup.ts",
      "!**/postcss.config.js",
      "!**/tailwind.config.js",
      "!**/vite.config.ts",
      "!**/build/*",
      "!**/coverage/*",
      "!**/node_modules/*",
      "!**/test/*",
      "!**/src/main.tsx",
    ],
  };
};
```

- `test/App.test.tsx`

```tsx
import React from "react";
import "@testing-library/jest-dom";
import { render, screen } from "@testing-library/react";
import App from "../src/App";

it("should properly rendered.", async () => {
  render(<App />);
  expect(screen.getByText("Hello Vite + React!")).toBeInTheDocument();
});
```

### Yarn

```fish
yarn fix
yarn test
yarn dev
```

### Git

```fish
printf 'node_modules\n.DS_Store\n*.local\nbuild\ncoverage\n' > .gitignore
git init
git config advice.addIgnoredFile false
git add ./*
git add ./.*
git branch -m main
git commit -m "init: Configuations for Vite, TypeScript, Tailwind CSS, Ant Design, Jest"
```
