# Vite Note

- Scaffold a project with [Vite](https://vitejs.dev/), [Ant Design](https://ant.design/), [Tailwind CSS](https://tailwindcss.com/) and [Generouted(Next.js like route)](https://github.com/oedotme/generouted)

- [Vite Note](#vite-note)
  - [TESTED PACKAGE VERSION](#tested-package-version)
  - [CLI](#cli)
  - [FILES](#files)
    - [`.env`](#env)
    - [`.eslintignore`](#eslintignore)
    - [`.eslintrc.cjs`](#eslintrccjs)
    - [`.npmrc`](#npmrc)
    - [`.prettierignore`](#prettierignore)
    - [`index.html`](#indexhtml)
    - [`package.json`](#packagejson)
    - [`tailwind.config.ts`](#tailwindconfigts)
    - [`tsconfig.node.json`](#tsconfignodejson)
    - [`vite.config.ts`](#viteconfigts)
    - [`src/main.tsx`](#srcmaintsx)
    - [`src/vite-env.d.ts`](#srcvite-envdts)
    - [`src/pages/[...all].tsx`](#srcpagesalltsx)
    - [`src/pages/index.tsx`](#srcpagesindextsx)

## TESTED PACKAGE VERSION

- `node`: `18.17.1`
- `npm`: `9.6.7`

```json
{
  "@ant-design/cssinjs": "1.16.2",
  "@generouted/react-router": "1.15.4",
  "@types/node": "20.4.10",
  "@types/react": "18.2.20",
  "@types/react-dom": "18.2.7",
  "@typescript-eslint/eslint-plugin": "6.3.0",
  "@typescript-eslint/parser": "6.3.0",
  "@vitejs/plugin-react": "4.0.4",
  "antd": "5.8.3",
  "autoprefixer": "10.4.15",
  "dayjs": "1.11.9",
  "eslint": "8.47.0",
  "eslint-config-prettier": "9.0.0",
  "eslint-plugin-react": "7.33.1",
  "eslint-plugin-react-hooks": "4.6.0",
  "eslint-plugin-react-refresh": "0.4.3",
  "postcss": "8.4.27",
  "prettier": "3.0.1",
  "react": "18.2.0",
  "react-dom": "18.2.0",
  "react-router-dom": "6.15.0",
  "tailwindcss": "3.3.3",
  "typescript": "5.1.6",
  "vite": "4.4.9"
}
```

## CLI

```sh
npm -y create vite@latest vite-app -- --template react-ts
```

```sh
cd vite-app
```

```sh
npm i -D --save \
@types/node@latest \
@types/react@latest \
@types/react-dom@latest \
react@latest \
react-dom@latest \
typescript@latest \
vite@latest \
@vitejs/plugin-react@latest \
@generouted/react-router@latest \
react-router-dom@latest \
antd@latest \
@ant-design/cssinjs@latest \
dayjs@latest \
eslint@latest \
@typescript-eslint/eslint-plugin@latest \
@typescript-eslint/parser@latest \
eslint-plugin-react@latest \
eslint-plugin-react-hooks@latest \
eslint-plugin-react-refresh@latest \
eslint-config-prettier@latest \
prettier@latest \
tailwindcss@latest \
postcss@latest \
autoprefixer@latest
```

```sh
npx tailwindcss init -p --ts
```

```sh
rm -rf src/assets src/App.css src/App.tsx src/index.css
```

```sh
mkdir src/pages
```

```sh
touch .env .eslintignore .prettierignore .npmrc 'src/pages/[...all].tsx' src/pages/index.tsx
```

```sh
code .
```

## FILES

### `.env`

```sh
VITE_TITLE="VITE APP"
VITE_FAVICON="vite.svg"
VITE_WEB_BASE="/"
VITE_API_PREFIX="/api"
PORT=5173
PROXY_SERVER="http://localhost:5173/"
```

### `.eslintignore`

```ignore
/public
/dist
.eslintrc.cjs
```

### `.eslintrc.cjs`

```js
module.exports = {
  root: true,
  env: { browser: true, es2020: true, node: true },
  settings: {
    react: {
      version: "detect",
    },
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/strict-type-checked",
    "plugin:@typescript-eslint/stylistic-type-checked",
    "plugin:react/recommended",
    "plugin:react/jsx-runtime",
    "plugin:react-hooks/recommended",
    "prettier",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaFeatures: {
      jsx: true,
    },
    ecmaVersion: "latest",
    sourceType: "module",
    project: ["./tsconfig.json", "./tsconfig.node.json"],
    tsconfigRootDir: __dirname,
  },
  ignorePatterns: ["tailwind.config.ts", "postcss.config.js"],
  plugins: ["react-refresh"],
  rules: {
    "react-refresh/only-export-components": [
      "warn",
      { allowConstantExport: true },
    ],
  },
};
```

### `.npmrc`

```npmrc
audit=false
fund=false
loglevel=error
update-notifier=false
engine-strict=true
save=true
```

### `.prettierignore`

```ignore
/public
/dist
```

### `index.html`

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>%VITE_TITLE%</title>
    <link rel="icon" type="images/svg+xml" href="/%VITE_FAVICON%" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

### `package.json`

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint --ext .js,.jsx,.ts,.tsx,.mjs,.cjs --report-unused-disable-directives . && tsc",
    "format": "prettier '**/*' --write --ignore-unknown --cache"
  }
}
```

### `tailwind.config.ts`

```ts
import type { Config } from "tailwindcss";

export default {
  important: "#root",
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: "#722ed1",
      },
    },
  },
  plugins: [],
} satisfies Config;
```

### `tsconfig.node.json`

```json
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strictNullChecks": true
  },
  "include": ["vite.config.ts"]
}
```

### `vite.config.ts`

```ts
import generouted from "@generouted/react-router/plugin";
import react from "@vitejs/plugin-react";
import { join } from "node:path";
import { cwd } from "node:process";
import { CommonServerOptions, defineConfig, loadEnv } from "vite";

const { PORT, VITE_API_PREFIX, PROXY_SERVER, VITE_WEB_BASE } = loadEnv(
  "development",
  cwd(),
  "",
);

const SERVER_OPTIONS: CommonServerOptions = {
  port: parseInt(PORT, 10),
  strictPort: true,
  proxy: {
    [join(VITE_WEB_BASE, VITE_API_PREFIX)]: {
      target: PROXY_SERVER,
      changeOrigin: true,
      secure: false,
    },
  },
};

export default defineConfig({
  base: VITE_WEB_BASE,
  server: SERVER_OPTIONS,
  preview: SERVER_OPTIONS,
  build: {
    chunkSizeWarningLimit: Infinity,
    reportCompressedSize: false,
  },
  plugins: [react(), generouted()],
});
```

### `src/main.tsx`

```tsx
import { StyleProvider } from "@ant-design/cssinjs";
import { Routes } from "@generouted/react-router/lazy";
import { App, ConfigProvider } from "antd";
import zhTW from "antd/es/locale/zh_TW";
import "dayjs/locale/zh-tw";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "tailwindcss/tailwind.css";
import tailwindConfig from "../tailwind.config.ts";

const container = document.getElementById("root") as HTMLDivElement;

const PRIMARY_COLOR = tailwindConfig.theme.extend.colors.primary;

createRoot(container).render(
  <StrictMode>
    <ConfigProvider
      getPopupContainer={() => container}
      locale={zhTW}
      theme={{
        token: {
          colorPrimary: PRIMARY_COLOR,
          colorInfo: PRIMARY_COLOR,
          colorLink: PRIMARY_COLOR,
          colorLinkHover: PRIMARY_COLOR,
          colorLinkActive: PRIMARY_COLOR,
        },
      }}
    >
      <StyleProvider hashPriority="high">
        <App>
          <Routes />
        </App>
      </StyleProvider>
    </ConfigProvider>
  </StrictMode>,
);
```

### `src/vite-env.d.ts`

```ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_TITLE: string;
  readonly VITE_FAVICON: string;
  readonly VITE_WEB_BASE: string;
  readonly VITE_API_PREFIX: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

### `src/pages/[...all].tsx`

```tsx
import { Navigate } from "../router";

export default function NotFound() {
  return <Navigate to="/" replace />;
}
```

### `src/pages/index.tsx`

```tsx
import { App, DatePicker, Descriptions, Space, Tag, version } from "antd";

export default function Index() {
  const { message } = App.useApp();
  return (
    <div className="flex h-screen flex-col items-center justify-center gap-3 text-center">
      <a href="https://vitejs.dev" target="_blank" rel="noreferrer">
        <img
          src="/vite.svg"
          className="pointer-events-none h-[20vmin]"
          alt="Vite logo"
        />
      </a>
      <h1 className="text-3xl font-bold text-primary">
        Vite + React + TailwindCSS + antd
      </h1>
      <Descriptions bordered>
        <Descriptions.Item label="antd">
          <Space>
            <Tag color="processing">{version}</Tag>
            <DatePicker
              onChange={(date) => {
                if (!date) return;
                void message.info(date.toDate().toLocaleString());
              }}
            />
          </Space>
        </Descriptions.Item>
      </Descriptions>
    </div>
  );
}
```
