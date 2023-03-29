# Vite Note

- This guide will scaffold a project with [Vite](https://vitejs.dev/), [Ant Design](https://ant.design/) and [Tailwind CSS](https://tailwindcss.com/)
- Last update with `vite@4.2.1`, `antd@5.3.3`, `tailwindcss@3.3.0`

## Step 1. CLI commands

- [Scaffolding Your First Vite Project](https://vitejs.dev/guide/#scaffolding-your-first-vite-project)

```bash
npm -y create vite@latest vite-app -- --template react-swc-ts
```

```bash
cd vite-app
```

- [npm config](https://docs.npmjs.com/cli/v9/commands/npm-config)
  - [`audit = false`](https://docs.npmjs.com/cli/v9/using-npm/config#audit)
  - [`fund = false`](https://docs.npmjs.com/cli/v9/using-npm/config#fund)
  - [`loglevel = error`](https://docs.npmjs.com/cli/v9/using-npm/config#loglevel)
  - [`update-notifier = false`](https://docs.npmjs.com/cli/v9/using-npm/config#update-notifier)
  - [`engine-strict = true`](https://docs.npmjs.com/cli/v9/using-npm/config#engine-strict)
  - [`save = true`](https://docs.npmjs.com/cli/v9/using-npm/config#save)
  - [`location = project`](https://docs.npmjs.com/cli/v9/commands/npm-config#location)

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true save=true --location=project
```

- Install and update packages

```bash
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

- Initialize Tailwind Config
  - [Install Tailwind CSS with Next.js](https://tailwindcss.com/docs/guides/nextjs)
  - [ESM and TypeScript support](https://tailwindcss.com/blog/tailwindcss-v3-3#esm-and-typescript-support)

```bash
npx tailwindcss init -p --ts
```

- Use Customized [ESLint Config](https://eslint.org/docs/latest/use/configure/configuration-files)
  - [For React](https://github.com/jsx-eslint/eslint-plugin-react)
    - [Using the new JSX transform from React 17](https://github.com/jsx-eslint/eslint-plugin-react#configuration-legacy-eslintrc)
  - [For Typescript](https://typescript-eslint.io/getting-started)
  - [For Prettier](https://github.com/prettier/eslint-config-prettier)
  - [For React Hooks](https://www.npmjs.com/package/eslint-plugin-react-hooks)

```bash
printf "{\n  \"root\": true,\n  \"env\": {\n    \"browser\": true,\n    \"node\": true\n  },\n  \"settings\": {\n    \"react\": {\n      \"version\": \"detect\"\n    }\n  },\n  \"extends\": [\n    \"eslint:recommended\",\n    \"plugin:react/recommended\",\n    \"plugin:react/jsx-runtime\",\n    \"plugin:@typescript-eslint/recommended\",\n    \"prettier\"\n  ],\n  \"parser\": \"@typescript-eslint/parser\",\n  \"parserOptions\": {\n    \"ecmaFeatures\": {\n      \"jsx\": true\n    },\n    \"ecmaVersion\": \"latest\",\n    \"sourceType\": \"module\"\n  },\n  \"plugins\": [\"react\", \"react-hooks\", \"@typescript-eslint\"]\n}\n" > .eslintrc.json
```

- ESLint igonre patterns

```bash
printf "/public\n/dist\n" > .eslintignore
```

- Prettier igonre patterns

```bash
printf "/public\n/dist\n" > .prettierignore
```

- Remove unnecessary files

```bash
rm -rf src/App.css src/index.css src/assets
```

## Step 2. Modify templete files

- `package.json`
  - [`vite`](https://vitejs.dev/guide/cli.html#vite)
  - [`vite build`](https://vitejs.dev/guide/cli.html#vite-build)
    - `tsc` for type check, vite build project use [esbuild](https://esbuild.github.io/) and [rollup.js](https://rollupjs.org/), bundling without type checking
  - [`vite preview`](https://vitejs.dev/guide/cli.html#vite-preview)
  - [`eslint CLI`](https://eslint.org/docs/latest/use/command-line-interface)
  - [`prettier CLI`](https://prettier.io/docs/en/cli.html)
    - [`--write`](https://prettier.io/docs/en/cli.html#--write)
    - [`--ignore-unknown`](https://prettier.io/docs/en/cli.html#--ignore-unknown)
    - [`--cache`](https://prettier.io/docs/en/cli.html#--cache)

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

- `vite.config.ts`
  - [`build.chunkSizeWarningLimit: Infinity`](https://vitejs.dev/config/build-options.html#build-chunksizewarninglimit)
    - Because chunk size close to 500k when do nothing with antd
    - It's easy to over the limit
  - [`@vitejs/plugin-react-swc`](https://vitejs.dev/blog/announcing-vite4.html#new-react-plugin-using-swc-during-development)
    - This plugin use [SWC](https://swc.rs/) during development
    - For big projects that don't require non-standard React extensions, cold start and Hot Module Replacement (HMR) can be significantly faster.

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

- `tailwind.config.ts`
  - [`important: '#root'`](https://tailwindcss.com/docs/configuration#selector-strategy)
    - For overriding antd style
  - Note: Extends styles from Tailwind config, then import to antd `<ConfigProvider />`

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

- `src/main.tsx`
  - [Customize antd theme with `<ConfigProvider />`](https://ant.design/docs/react/customize-theme#customize-theme-with-configprovider)
    - Import theme colors from Tailwind config
  - [Internationalization](https://ant.design/docs/react/i18n)
    - Remember to import dayjs locales for DatePicker components
  - [Use `<StyleProvider/>` to overrides Tailwind preflight CSS rules](https://ant.design/docs/react/compatible-style)
    - Tailwind [preflight](https://tailwindcss.com/docs/preflight) rules would conflict with some antd component styles like `<Button />`
  - [`getPopupContainer`](https://ant.design/components/config-provider#api)
    - Set the container of the popup element on React root element
    - Because Tailwind's `important` rules base on `<div id="#root" />`
  - [`<App />` provide global style & static function replacement](https://ant.design/components/app)

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

- `src/App.tsx`
  - Basic page to check antd and Tailwind CSS works fine

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
