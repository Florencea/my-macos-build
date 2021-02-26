# React Development Notes

- [React Development Notes](#react-development-notes)
  - [Vite + TypeScript + Google TypeScript Style + Tailwind CSS + Ant Design + Jest](#vite--typescript--google-typescript-style--tailwind-css--ant-design--jest)
    - [Commends](#commends)
    - [Files](#files)
    - [Yarn](#yarn)
    - [Git](#git)
  - [Next.js + TypeScript + Google TypeScript Style + Tailwind CSS + Ant Design + Jest](#nextjs--typescript--google-typescript-style--tailwind-css--ant-design--jest)
    - [Install packages](#install-packages)
    - [Configuation files](#configuation-files)
    - [Tailwind CSS setup](#tailwind-css-setup)
    - [Change file extensions to `.tsx`](#change-file-extensions-to-tsx)
    - [Import Modules](#import-modules)
    - [Jest configuations](#jest-configuations)
    - [Done](#done)
    - [Commit files](#commit-files)
  - [Create React APP + TypeScript + Google TypeScript Style + Bootstrap + FontAwesome + SASS](#create-react-app--typescript--google-typescript-style--bootstrap--fontawesome--sass)
    - [`cra app-name`](#cra-app-name)
    - [Full steps of `cra`](#full-steps-of-cra)
  - [Create React APP + TypeScript + Google TypeScript Style + Tailwind CSS + FontAwesome](#create-react-app--typescript--google-typescript-style--tailwind-css--fontawesome)
    - [`crat app-name`](#crat-app-name)
    - [Full steps of `crat`](#full-steps-of-crat)

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
  purge: ["./src/**/*.tsx", "./components/**/*.tsx"],
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

## Next.js + TypeScript + Google TypeScript Style + Tailwind CSS + Ant Design + Jest

### Install packages

```fish
yarn create next-app
cd <app-name>
mkdir test
mkdir components
npx gts init -y --yarn
yarn add ts-node jest jest-css-modules @babel/core babel-jest @types/react eslint eslint-plugin-node eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise typescript --force --dev
yarn add antd @ant-design/icons swr tailwindcss@latest postcss@latest autoprefixer@latest @testing-library/jest-dom @testing-library/react @jest/types
code .
```

### Configuation files

- `package.json`

```json
{
  "scripts": {
    "test": "jest --passWithNoTests --no-cache --silent --coverage --verbose --watchAll=false",
    "dev": "next dev",
    "build": "next build",
    "build-static": "next export",
    "start": "next start",
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
    "rootDir": ".",
    "outDir": "build",
    "allowJs": true,
    "skipLibCheck": true,
    "noEmit": true,
    "esModuleInterop": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve"
  },
  "include": ["src/**/*.ts", "test/**/*.ts"],
  "exclude": ["node_modules"]
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
.next/
build/
coverage/
node_modules/
out/
public/
styles/
```

### Tailwind CSS setup

```fish
npx -y tailwindcss init -p
```

- `tailwind.config.js`

```javascript
module.exports = {
  purge: ["./pages/**/*.tsx", "./components/**/*.tsx"],
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

### Change file extensions to `.tsx`

```fish
mv pages/api/hello.js pages/api/hello.ts
mv pages/_app.js pages/_app.tsx
mv pages/index.js pages/index.tsx
```

### Import Modules

```fish
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' >> styles/tailwind.css
```

- `pages/_app.tsx`

```tsx
import React from "react";
import type { AppProps } from "next/app";
import "antd/dist/antd.css";
import "../styles/tailwind.css";
import "../styles/globals.css";

function MyApp({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />;
}

export default MyApp;
```

- `pages/index.tsx`

```tsx
import React from "react";
import Head from "next/head";
import styles from "../styles/Home.module.css";

export default function Home() {
  return (
    <div className={styles.container}>
      <Head>
        <title>Create Next App</title>
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main className={styles.main}>
        <h1 className={styles.title}>
          Welcome to <a href="https://nextjs.org">Next.js!</a>
        </h1>

        <p className={styles.description}>
          Get started by editing{" "}
          <code className={styles.code}>pages/index.js</code>
        </p>

        <div className={styles.grid}>
          <a href="https://nextjs.org/docs" className={styles.card}>
            <h3>Documentation &rarr;</h3>
            <p>Find in-depth information about Next.js features and API.</p>
          </a>

          <a href="https://nextjs.org/learn" className={styles.card}>
            <h3>Learn &rarr;</h3>
            <p>Learn about Next.js in an interactive course with quizzes!</p>
          </a>

          <a
            href="https://github.com/vercel/next.js/tree/master/examples"
            className={styles.card}
          >
            <h3>Examples &rarr;</h3>
            <p>Discover and deploy boilerplate example Next.js projects.</p>
          </a>

          <a
            href="https://vercel.com/import?filter=next.js&utm_source=create-next-app&utm_medium=default-template&utm_campaign=create-next-app"
            className={styles.card}
          >
            <h3>Deploy &rarr;</h3>
            <p>
              Instantly deploy your Next.js site to a public URL with Vercel.
            </p>
          </a>
        </div>
      </main>

      <footer className={styles.footer}>
        <a
          href="https://vercel.com?utm_source=create-next-app&utm_medium=default-template&utm_campaign=create-next-app"
          target="_blank"
          rel="noopener noreferrer"
        >
          Powered by{" "}
          <img src="/vercel.svg" alt="Vercel Logo" className={styles.logo} />
        </a>
      </footer>
    </div>
  );
}
```

- `pages/api/hello.ts`

```typescript
import type { NextApiRequest, NextApiResponse } from "next";

type Data = {
  name: string;
};

export default (req: NextApiRequest, res: NextApiResponse<Data>) => {
  res.status(200).json({ name: "John Doe" });
};
```

- `src/index.ts`

```typescript
export default function index() {}
```

### Jest configuations

```fish
printf '{\n  "presets": ["next/babel"]\n}\n' >> .babelrc
touch jest.config.ts
touch jest.setup.ts
touch test/index.test.tsx
```

- `jest.config.ts`

```typescript
import type { Config } from "@jest/types";

export default async (): Promise<Config.InitialOptions> => {
  return {
    setupFilesAfterEnv: ["./jest.setup.ts"],
    moduleNameMapper: {
      "\\.(css|less|scss|sss|styl)$": "<rootDir>/node_modules/jest-css-modules",
    },
    collectCoverageFrom: [
      "**/*.{ts,tsx}",
      "!**/jest.config.ts",
      "!**/jest.setup.ts",
      "!**/next-env.d.ts",
      "!**/postcss.config.js",
      "!**/tailwind.config.js",
      "!**/build/*",
      "!**/build/src/*",
      "!**/.next/*",
      "!**/coverage/*",
      "!**/node_modules/*",
      "!**/public/*",
      "!**/styles/*",
      "!**/test/*",
    ],
  };
};
```

- `jest.setup.ts`

```typescript
Object.defineProperty(window, "matchMedia", {
  value: () => {
    return {
      matches: false,
      addListener: () => {},
      removeListener: () => {},
    };
  },
});
```

- `test/index.test.tsx`

```tsx
import React from "react";
import "@testing-library/jest-dom";
import { render, screen } from "@testing-library/react";
import Home from "../pages/index";

it("should properly rendered.", async () => {
  render(<Home />);
  expect(screen.getByText("Next.js!")).toBeInTheDocument();
});
```

### Done

```fish
yarn fix
yarn test
yarn dev
```

### Commit files

```fish
git config advice.addIgnoredFile false
git add ./*
git add ./.*
git commit -m "init: Configuations for TypeScript, Tailwind CSS, Ant Design, Jest"
```

## Create React APP + TypeScript + Google TypeScript Style + Bootstrap + FontAwesome + SASS

### `cra app-name`

- Recommend to use `cra` for alias in `scripts/create-react-app.sh`

### Full steps of `cra`

```fish
yarn create react-app app-name --template typescript
cd app-name
yarn add bootstrap reactstrap @fortawesome/fontawesome-free
# need to compile, may take a while
yarn add node-sass@4.14.1
yarn add eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise eslint-plugin-node eslint-plugin-prettier --dev
npx gts init -y --yarn
```

- Remove `typescript` and `@types/node` devDependencies. (important!)

```fish
yarn remove typescript @types/node --dev
yarn add typescript @types/node --dev
```

- Change npm scripts `"test"` in `package.json` to

```json
{
  "scripts": {
    "test": "react-scripts test --coverage --verbose"
  }
}
```

- Add `"jest"` section in `package.json`

```json
{
  "jest": {
    "collectCoverageFrom": [
      "**/*.{ts,tsx}",
      "!**/src/reportWebVitals.ts",
      "!**/src/index.tsx",
      "!**/src/react-app-env.d.ts"
    ]
  }
}
```

- Replace all of `tsconfig.json` with content below.

```json
{
  "extends": "./node_modules/gts/tsconfig-google.json",
  "compilerOptions": {
    "rootDir": ".",
    "outDir": "build",
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": ["src"]
}
```

- Replace `.eslintrc.json` with content below.

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

- Add `bootstrap-custom.scss` to `src/`

  ```fish
  printf "\$theme-colors: (\n  \"custom-color\": #900,\n);\n\n@import \"../node_modules/bootstrap/scss/bootstrap\";\n" >> src/bootstrap-custom.scss
  ```

- Import `fontawesome` and `bootstrap` in `src/App.tsx`

  ```typescript
  import "@fortawesome/fontawesome-free/css/all.min.css";
  import "./bootstrap-custom.scss";
  ```

- Replace `reportWebVitals.ts` with content below

```typescript
import { ReportHandler } from "web-vitals";

const reportWebVitals = (onPerfEntry?: ReportHandler) => {
  if (onPerfEntry && onPerfEntry instanceof Function) {
    import("web-vitals")
      .then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
        getCLS(onPerfEntry);
        getFID(onPerfEntry);
        getFCP(onPerfEntry);
        getLCP(onPerfEntry);
        getTTFB(onPerfEntry);
        return;
      })
      .catch((err) => {
        console.error(err);
      });
  }
};

export default reportWebVitals;
```

- Clear `App.tsx` and `App.css`, start codeing.

## Create React APP + TypeScript + Google TypeScript Style + Tailwind CSS + FontAwesome

### `crat app-name`

- Recommend to use `crat` for alias in `scripts/create-react-app-tailwind.sh`

### Full steps of `crat`

```fish
yarn create react-app app-name --template typescript
cd app-name
yarn add tailwindcss@npm:@tailwindcss/postcss7-compat postcss@^7 autoprefixer@^9 @craco/craco @fortawesome/fontawesome-free
yarn add eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise eslint-plugin-node eslint-plugin-prettier --dev
npx gts init -y --yarn
```

- Remove `typescript` and `@types/node` devDependencies. (important!)

```fish
yarn remove typescript @types/node --dev
yarn add typescript @types/node --dev
```

- Change npm scripts `"start`, `"build"` and `"test"` in `package.json` to

```json
{
  "scripts": {
    "start": "craco start",
    "build": "craco build",
    "test": "craco test --coverage --verbose"
  }
}
```

- Add `"jest"` section in `package.json`

```json
{
  "jest": {
    "collectCoverageFrom": [
      "**/*.{ts,tsx}",
      "!**/src/reportWebVitals.ts",
      "!**/src/index.tsx",
      "!**/src/react-app-env.d.ts"
    ]
  }
}
```

- Replace all of `tsconfig.json` with content below.

```json
{
  "extends": "./node_modules/gts/tsconfig-google.json",
  "compilerOptions": {
    "rootDir": ".",
    "outDir": "build",
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": ["src"]
}
```

- Replace `.eslintrc.json` with content below.

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

- Create `craco.config.js`

  ```javascript
  module.exports = {
    style: {
      postcss: {
        plugins: [require("tailwindcss"), require("autoprefixer")],
      },
    },
  };
  ```

- Create Tailwind configuration file

```fish
npx -y tailwindcss init
```

- Replace content of `tailwind.config.js` to

```javascript
module.exports = {
  purge: ["./src/**/*.js", "./public/index.html"],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {},
  },
  variants: {},
  plugins: [],
};
```

- Replace content of `./src/index.css` to

```postcss
@tailwind base;
@tailwind components;
@tailwind utilities;
```

- Replace `reportWebVitals.ts` with content below

```typescript
import { ReportHandler } from "web-vitals";

const reportWebVitals = (onPerfEntry?: ReportHandler) => {
  if (onPerfEntry && onPerfEntry instanceof Function) {
    import("web-vitals")
      .then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
        getCLS(onPerfEntry);
        getFID(onPerfEntry);
        getFCP(onPerfEntry);
        getLCP(onPerfEntry);
        getTTFB(onPerfEntry);
        return;
      })
      .catch((err) => {
        console.error(err);
      });
  }
};

export default reportWebVitals;
```

- Clear `App.tsx` and `App.css`, start codeing.
