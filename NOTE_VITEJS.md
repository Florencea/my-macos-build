# Vite Note

- Scaffold a project with [Vite](https://vitejs.dev/), [Ant Design](https://ant.design/) and [Tailwind CSS](https://tailwindcss.com/)

- [Vite Note](#vite-note)
  - [TESTED PACKAGE VERSION](#tested-package-version)
  - [CLI](#cli)
  - [FILES](#files)
    - [`.eslintignore`](#eslintignore)
    - [`.eslintrc.json`](#eslintrcjson)
    - [`.npmrc`](#npmrc)
    - [`.prettierignore`](#prettierignore)
    - [`package.json`](#packagejson)
    - [`tailwind.config.ts`](#tailwindconfigts)
    - [`vite.config.ts`](#viteconfigts)
    - [`src/main.tsx`](#srcmaintsx)
    - [`src/App.tsx`](#srcapptsx)

## TESTED PACKAGE VERSION

- `node`: `18.17.0`
- `npm`: `9.6.7`

```json
{
  "@ant-design/cssinjs": "1.15.0",
  "@types/react": "18.2.17",
  "@types/react-dom": "18.2.7",
  "@typescript-eslint/eslint-plugin": "6.2.0",
  "@typescript-eslint/parser": "6.2.0",
  "@vitejs/plugin-react": "4.0.3",
  "antd": "5.7.3",
  "autoprefixer": "10.4.14",
  "dayjs": "1.11.9",
  "eslint": "8.45.0",
  "eslint-config-prettier": "8.8.0",
  "eslint-plugin-react-hooks": "4.6.0",
  "eslint-plugin-react-refresh": "0.4.3",
  "postcss": "8.4.27",
  "prettier": "3.0.0",
  "react": "18.2.0",
  "react-dom": "18.2.0",
  "tailwindcss": "3.3.3",
  "typescript": "5.1.6",
  "vite": "4.4.7"
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
@types/react@latest \
@types/react-dom@latest \
@vitejs/plugin-react@latest \
react@latest \
react-dom@latest \
typescript@latest \
vite@latest \
antd@latest \
@ant-design/cssinjs@latest \
dayjs@latest \
eslint@latest \
@typescript-eslint/eslint-plugin@latest \
@typescript-eslint/parser@latest \
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
rm -rf .eslintrc.cjs src/assets src/App.css src/index.css
```

```sh
touch .eslintignore .eslintrc.json .prettierignore .npmrc
```

```sh
code .
```

## FILES

### `.eslintignore`

```ignore
/public
/dist
```

### `.eslintrc.json`

```json
{
  "env": { "browser": true, "es2020": true, "node": true },
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:react-hooks/recommended",
    "prettier"
  ],
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "ecmaVersion": "latest",
    "sourceType": "module"
  },
  "plugins": ["react-refresh"],
  "rules": {
    "react-refresh/only-export-components": "warn"
  }
}
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

### `vite.config.ts`

```ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: Infinity,
    reportCompressedSize: false,
  },
});
```

### `src/main.tsx`

```tsx
import { StyleProvider } from "@ant-design/cssinjs";
import { App as AntApp, ConfigProvider } from "antd";
import zhTW from "antd/es/locale/zh_TW";
import "dayjs/locale/zh-tw";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "tailwindcss/tailwind.css";
import tailwindConfig from "../tailwind.config";
import App from "./App";

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
        <AntApp>
          <App />
        </AntApp>
      </StyleProvider>
    </ConfigProvider>
  </StrictMode>,
);
```

### `src/App.tsx`

```tsx
import {
  App as AntApp,
  DatePicker,
  Descriptions,
  Space,
  Tag,
  version,
} from "antd";

export default function App() {
  const { message } = AntApp.useApp();
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
                message.info(date?.toDate().toLocaleString());
              }}
            />
          </Space>
        </Descriptions.Item>
      </Descriptions>
    </div>
  );
}
```
