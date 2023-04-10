# Next.js Note

- Scaffold a project with [Next.js](https://nextjs.org/), [Ant Design](https://ant.design/) and [Tailwind CSS](https://tailwindcss.com/)

- [Next.js Note](#nextjs-note)
  - [CLI](#cli)
  - [FILES](#files)
    - [`.env`](#env)
    - [`.eslintrc.json`](#eslintrcjson)
    - [`.npmrc`](#npmrc)
    - [`.prettierignore`](#prettierignore)
    - [`next.config.js`](#nextconfigjs)
    - [`package.json`](#packagejson)
    - [`postcss.config.js`](#postcssconfigjs)
    - [`tailwind.config.ts`](#tailwindconfigts)
    - [`pages/_app.tsx`](#pages_apptsx)
    - [`pages/index.tsx`](#pagesindextsx)

## CLI

```sh
npx -y create-next-app@latest next-app --ts --no-tailwind --eslint --use-npm --no-src-dir --no-experimental-app --import-alias --reset-preferences "@/*"
```

```sh
cd next-app
```

```sh
npm i -P --save \
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
prettier \
sirv-cli
```

```sh
npx tailwindcss init -p --ts
```

```sh
rm -rf styles
```

```sh
touch .env .eslintrc.json .npmrc .prettierignore
```

```sh
code .
```

## FILES

### `.env`

```dotenv
PORT=3000
NEXT_TELEMETRY_DISABLED=1
```

### `.eslintrc.json`

```json
{
  "extends": ["next/core-web-vitals", "prettier"]
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
.next
next-env.d.ts
/public
/out
```

### `next.config.js`

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: process.env.STATIC ? "export" : "standalone",
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

### `package.json`

```json
{
  "scripts": {
    "dev": "dotenv next dev",
    "build": "dotenv next build",
    "export": "dotenv -v STATIC=1 next build",
    "preview": "dotenv sirv out",
    "start": "dotenv next start",
    "lint": "dotenv next lint",
    "format": "prettier '**/*' --write --ignore-unknown --cache"
  }
}
```

### `postcss.config.js`

```js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

### `tailwind.config.ts`

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

### `pages/_app.tsx`

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

### `pages/index.tsx`

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
