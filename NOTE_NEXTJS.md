# Next.js Note

- This guide will scaffold a project with [Next.js](https://nextjs.org/), [Ant Design](https://ant.design/) and [Tailwind CSS](https://tailwindcss.com/)
- Last update with `next@13.2.4`, `antd@5.3.3`, `tailwindcss@3.3.0`

## Step 1. CLI commands

- [create-next-app](https://nextjs.org/docs/api-reference/create-next-app)

```bash
npx -y create-next-app@latest next-app --ts --eslint --use-npm --no-src-dir --no-experimental-app --import-alias "@/*"
```

```bash
cd next-app
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

- [ESLint config](https://nextjs.org/docs/basic-features/eslint)
  - [with strict rules](https://nextjs.org/docs/basic-features/eslint#core-web-vitals)
  - [with prettier](https://nextjs.org/docs/basic-features/eslint#prettier)

```bash
printf "{\n  \"extends\": [\n    \"next/core-web-vitals\",\n    \"prettier\"\n  ]\n}\n" > .eslintrc.json
```

- Prettier igonre patterns

```bash
printf ".next\nnext-env.d.ts\n/public\n/out\n" > .prettierignore
```

- [Environment Variables](https://nextjs.org/docs/basic-features/environment-variables)
  - [`PORT = 3000`](https://nextjs.org/docs/api-reference/cli#production)
    - Note: need use [dotenv](https://www.npmjs.com/package/dotenv-cli) for PORT env
  - [`NEXT_TELEMETRY_DISABLED = 1`](https://nextjs.org/telemetry#how-do-i-opt-out)

```bash
printf "PORT=3000\nNEXT_TELEMETRY_DISABLED=1\n" > .env
```

- Install and update packages

```bash
npm i -P \
@types/node@latest \
@types/react@latest \
@types/react-dom@latest \
next@latest \
react@latest \
react-dom@latest \
eslint@latest \
eslint-config-next@latest \
eslint-config-prettier \
typescript@latest \
antd \
@ant-design/cssinjs \
dayjs \
dotenv-cli \
tailwindcss \
postcss \
autoprefixer \
prettier
```

- Initialize Tailwind Config
  - [Install Tailwind CSS with Next.js](https://tailwindcss.com/docs/guides/nextjs)
  - [ESM and TypeScript support](https://tailwindcss.com/blog/tailwindcss-v3-3#esm-and-typescript-support)

```bash
npx tailwindcss init -p --ts
```

- Remove templete styles

```bash
rm -rf styles
```

## Step 2. Modify templete files

- `package.json`
  - [`next dev`](https://nextjs.org/docs/api-reference/cli#development)
  - [`next build`](https://nextjs.org/docs/api-reference/cli#build)
  - [`next export` (Deprecated since Next.js 13.3)](https://nextjs.org/docs/advanced-features/static-html-export#next-export)
  - [`next start`](https://nextjs.org/docs/api-reference/cli#production)
  - [`next lint`](https://nextjs.org/docs/api-reference/cli#lint)
  - [`prettier CLI`](https://prettier.io/docs/en/cli.html)
    - [`--write`](https://prettier.io/docs/en/cli.html#--write)
    - [`--ignore-unknown`](https://prettier.io/docs/en/cli.html#--ignore-unknown)
    - [`--cache`](https://prettier.io/docs/en/cli.html#--cache)

```json
{
  "scripts": {
    "dev": "dotenv next dev",
    "build": "dotenv next build",
    "export": "dotenv next build && dotenv next export",
    "start": "dotenv next start",
    "lint": "dotenv next lint",
    "format": "prettier '**/*' --write --ignore-unknown --cache"
  }
}
```

- `next.config.js`
  - [`reactStrictMode: true`](https://nextjs.org/docs/api-reference/next.config.js/react-strict-mode)
  - [`output: 'export'`](https://nextjs.org/docs/advanced-features/static-html-export#usage)
  - [`images: { unoptimized: true }`](https://nextjs.org/docs/api-reference/next/image#unoptimized)
  - [`compiler: { removeConsole: process.env.NODE_ENV === 'production' }`](https://nextjs.org/docs/advanced-features/compiler#remove-console)

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    unoptimized: true,
  },
  compiler: {
    removeConsole: process.env.NODE_ENV === "production",
  },
};

module.exports = nextConfig;
```

- `postcss.config.js`
  - It seems like an issue in Tailwind CSS 3.3 + Next.js 13.2.4
  - Tailwind CLI generate postcss config in ESM format when use `--ts` flag
  - But Next.js cannot load it, hence fix it to CJS format

```js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

- `tailwind.config.ts`
  - [`important: '#__next'`](https://tailwindcss.com/docs/configuration#selector-strategy)
    - For overriding antd style
  - Note: Extends styles from Tailwind config, then import to antd `<ConfigProvider />`

```ts
import type { Config } from "tailwindcss";

export default {
  important: "#__next",
  content: [
    "./pages/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
  ],
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

- `pages/_app.tsx`
  - [Customize antd theme with `<ConfigProvider />`](https://ant.design/docs/react/customize-theme#customize-theme-with-configprovider)
    - Import theme colors from Tailwind config
  - [Internationalization](https://ant.design/docs/react/i18n)
    - Remember to import dayjs locales for DatePicker components
  - [Use `<StyleProvider/>` to overrides Tailwind preflight CSS rules](https://ant.design/docs/react/compatible-style)
    - Tailwind [preflight](https://tailwindcss.com/docs/preflight) rules would conflict with some antd component styles like `<Button />`
  - [`getPopupContainer`](https://ant.design/components/config-provider#api)
    - Set the container of the popup element on React root element
    - Because Tailwind's `important` rules base on `<div id="__next" />`
    - Check if `window !== undefined` to prevent function execute on server side
  - [`<App />` provide global style & static function replacement](https://ant.design/components/app)

```tsx
import { StyleProvider } from "@ant-design/cssinjs";
import { App as AntApp, ConfigProvider } from "antd";
import zhTW from "antd/locale/zh_TW";
import "dayjs/locale/zh-tw";
import type { AppProps } from "next/app";
import "tailwindcss/tailwind.css";
import tailwindConfig from "../tailwind.config";

const PRIMARY_COLOR = tailwindConfig.theme.extend.colors.primary;

export default function App({ Component, pageProps }: AppProps) {
  return (
    <StyleProvider hashPriority="high">
      <ConfigProvider
        getPopupContainer={
          typeof window !== "undefined"
            ? () => document.getElementById("__next") as HTMLDivElement
            : undefined
        }
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
        <AntApp>
          <Component {...pageProps} />
        </AntApp>
      </ConfigProvider>
    </StyleProvider>
  );
}
```

- `pages/index.tsx`
  - Basic page to check antd and Tailwind CSS works fine
  - [`next/head`](https://nextjs.org/docs/api-reference/next/head)
  - [`next/image`](https://nextjs.org/docs/api-reference/next/image)
    - [props: `fill`](https://nextjs.org/docs/api-reference/next/image#fill)

```tsx
import {
  App as AntApp,
  DatePicker,
  Descriptions,
  Space,
  Tag,
  version,
} from "antd";
import { NextPage } from "next";
import Head from "next/head";
import Image from "next/image";

const Page: NextPage = () => {
  const { message } = AntApp.useApp();
  return (
    <>
      <Head>
        <title>Next + TailwindCSS + Antd</title>
      </Head>
      <div className="flex h-screen flex-col items-center justify-center gap-3 text-center">
        <a
          className="relative block h-[10vmin] w-[20vmin]"
          href="https://nextjs.org/"
          target="_blank"
          rel="noreferrer"
        >
          <Image
            src="/next.svg"
            className="pointer-events-none mb-10"
            alt="Vercel logo"
            fill
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
    </>
  );
};

export default Page;
```
