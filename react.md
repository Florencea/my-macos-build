# React Development Notes

- [React Development Notes](#react-development-notes)
  - [Create React APP + TypeScript + Google TypeScript Style + Bootstrap + FontAwesome + SASS](#create-react-app--typescript--google-typescript-style--bootstrap--fontawesome--sass)
    - [`cra app-name`](#cra-app-name)
    - [Full steps of `cra`](#full-steps-of-cra)
  - [Create React APP + TypeScript + Google TypeScript Style + Tailwind CSS + FontAwesome](#create-react-app--typescript--google-typescript-style--tailwind-css--fontawesome)
    - [`crat app-name`](#crat-app-name)
    - [Full steps of `crat`](#full-steps-of-crat)

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
npx -y gts init --yarn
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
npx -y gts init --yarn
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
