# Next.js Note

- <https://nextjs.org/docs/getting-started>

## Next.js + antd + tailwindCSS

```bash
npm -y create next-app@latest -- next-app --typescript --eslint --use-npm
```

```bash
cd next-app
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true save-exact=true --location=project
```

```bash
printf ".next\nnext-env.d.ts\n/public\n/out\n" > .prettierignore
```

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
typescript@latest \
antd \
dotenv-cli \
tailwindcss \
postcss \
autoprefixer \
prettier \
prettier-plugin-tailwindcss
```

```bash
npx tailwindcss init -p
```

```bash
rm -rf styles
```

- `package.json`

```json
{
  "scripts": {
    "dev": "dotenv next dev",
    "build": "dotenv next build",
    "export": "dotenv next build && dotenv next export",
    "start": "dotenv next start",
    "lint": "dotenv next lint",
    "format": "prettier --write \"**/*\" --ignore-unknown"
  }
}
```

- `next.config.js`

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    unoptimized: true,
  },
  swcMinify: true,
  compiler: {
    removeConsole: process.env.NODE_ENV === "production",
  },
};

module.exports = nextConfig;
```

- `tailwind.config.js`

```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  corePlugins: {
    preflight: false,
  },
  important: "body",
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
};
```

- `pages/_app.tsx`

```tsx
import { ConfigProvider } from "antd";
import "antd/dist/reset.css";
import zhTW from "antd/locale/zh_TW";
import "dayjs/locale/zh-tw";
import type { AppProps } from "next/app";
import "tailwindcss/tailwind.css";

export default function App({ Component, pageProps }: AppProps) {
  return (
    <ConfigProvider
      locale={zhTW}
      theme={{
        token: {
          colorPrimary: "#722ed1",
          colorInfo: "#722ed1",
        },
      }}
    >
      <Component {...pageProps} />
    </ConfigProvider>
  );
}
```

- `pages/index.tsx`

```tsx
import { Button, DatePicker, message, Typography } from "antd";
import { NextPage } from "next";
import Head from "next/head";
import Image from "next/image";
import { useState } from "react";

const Page: NextPage = () => {
  const [count, setCount] = useState(0);
  const [msg, msgConetext] = message.useMessage();
  return (
    <>
      {msgConetext}
      <Head>
        <title>Next + TailwindCSS + Antd</title>
      </Head>
      <div className="flex h-screen flex-col items-center justify-center text-center text-3xl">
        <a
          className="relative block h-[10vmin] w-[20vmin]"
          href="https://nextjs.org/"
          target="_blank"
          rel="noreferrer"
        >
          <Image
            src="/vercel.svg"
            className="pointer-events-none mb-10"
            alt="Vercel logo"
            fill
          />
        </a>
        <Typography.Title className="text-primary">
          Next + TailwindCSS + Antd
        </Typography.Title>
        <div className="flex justify-center space-x-3">
          <Button type="primary" onClick={() => setCount((count) => count + 1)}>
            count is: {count}
          </Button>
          <DatePicker
            onChange={(date) => {
              if (date !== null) {
                msg.info(date.toDate().toLocaleDateString("zh-TW"));
              }
            }}
          />
        </div>
      </div>
    </>
  );
};

export default Page;
```
