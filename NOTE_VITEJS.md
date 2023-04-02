# Vite Note

- Scaffold a project with [Vite](https://vitejs.dev/), [Ant Design](https://ant.design/) and [Tailwind CSS](https://tailwindcss.com/)

- [Vite Note](#vite-note)
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

## CLI

```sh
npm -y create vite@latest vite-app -- --template react-swc-ts
```

```sh
cd vite-app
```

```sh
npm i -P \
@types/react@latest \
@types/react-dom@latest \
@vitejs/plugin-react-swc@latest \
react@latest \
react-dom@latest \
typescript@latest \
vite@latest \
antd \
@ant-design/cssinjs \
dayjs \
eslint \
eslint-config-prettier \
eslint-plugin-react \
eslint-plugin-react-hooks \
@typescript-eslint/eslint-plugin \
@typescript-eslint/parser \
prettier \
tailwindcss \
postcss \
autoprefixer
```

```sh
npx tailwindcss init -p --ts
```

```sh
rm -rf src/App.css src/index.css src/assets
```

```sh
touch .eslintignore .eslintrc.json .prettierignore .npmrc
```

```sh
code .
```

## FILES

### `.eslintignore`

```sh
/public
/dist
```

### `.eslintrc.json`

```json
{
  "root": true,
  "env": {
    "browser": true,
    "node": true
  },
  "settings": {
    "react": {
      "version": "detect"
    }
  },
  "extends": [
    "eslint:recommended",
    "plugin:react/recommended",
    "plugin:react/jsx-runtime",
    "plugin:react-hooks/recommended",
    "plugin:@typescript-eslint/recommended",
    "prettier"
  ],
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "ecmaFeatures": {
      "jsx": true
    },
    "ecmaVersion": "latest",
    "sourceType": "module"
  },
  "plugins": ["react", "@typescript-eslint"]
}
```

### `.npmrc`

```sh
audit=false
fund=false
loglevel=error
update-notifier=false
engine-strict=true
save=true
```

### `.prettierignore`

```sh
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
    "lint": "eslint --ext .js,.jsx,.ts,.tsx,.mjs,.cjs . && tsc",
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
import react from "@vitejs/plugin-react-swc";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: Infinity,
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
const root = createRoot(container);

const PRIMARY_COLOR = tailwindConfig.theme.extend.colors.primary;

root.render(
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
  </StrictMode>
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
