# React Development Notes

## Create React APP + TypeScript + Google TypeScript Style + SASS

```fish
npx create-react-app app-name --template typescript
cd app-name
npm install bootstrap @fortawesome/fontawesome-free
npm install reactstrap --legacy-peer-deps
# need to compile, may take a while
npm install node-sass@4.14.1
npm install eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise --save-dev
npx gts init
```

- Remove `typescript` and `@types/node` devDependencies. (important!)

```fish
npm uninstall typescript @types/node --save-dev
npm install typescript @types/node
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
