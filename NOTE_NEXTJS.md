# Next.js Note

- <https://nextjs.org/docs/getting-started>

## Next.js + antd + tailwindCSS

```bash
npm -y create next-app@latest -- my-app --typescript --eslint --use-npm
```

```bash
cd my-app
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true --location=project
```

```bash
printf "NEXT_TELEMETRY_DISABLED=1\nPORT=3001\n" > .env
```

```bash
printf ".next\nnext-env.d.ts\n/public\n/out\n" > .prettierignore
```

```bash
npm install \
next@latest \
react@latest \
react-dom@latest \
antd \
dotenv-cli
```

```bash
npm install --save-dev \
@types/node@latest \
@types/react@latest \
@types/react-dom@latest \
eslint@latest \
eslint-config-next@latest \
typescript@latest \
tailwindcss \
postcss \
autoprefixer \
prettier \
shx
```

```bash
npx tailwindcss init --postcss
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
    "prettier": "prettier --write \"**/*\" --ignore-unknown",
    "deps:up": "npm update --save && npm run reset",
    "reset": "shx rm -rf node_modules out .next next-env.d.ts && npm install"
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
const SEED_TOKEN_COLORS = Object.fromEntries(
  Object.entries(require("antd").theme.defaultSeed).filter(([, value]) =>
    `${value}`.startsWith("#")
  )
);

const SEED_TOKEN_BORDER_RADIUS = Object.fromEntries(
  Object.entries(require("antd").theme.defaultSeed).filter(([, value]) =>
    `${value}`.toLowerCase().includes("radius")
  )
);

/** @type {Pick<import('antd/es/theme').SeedToken, keyof import('antd/es/theme').SeedToken & `color${string}`>} */
const customColorSeed = {
  colorPrimary: "#722ed1",
  colorInfo: "#722ed1",
};

/** @type {Pick<import('antd/es/theme').SeedToken, keyof import('antd/es/theme').SeedToken & `${string}Radius`>} */
const customRadiusSeed = {
  borderRadius: 4,
};

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
        ...SEED_TOKEN_COLORS,
        ...customColorSeed,
      },
      borderRadius: {
        ...SEED_TOKEN_BORDER_RADIUS,
        ...customRadiusSeed,
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
import tailwindConfig from "../tailwind.config.js";

const { colors, borderRadius } = tailwindConfig.theme!
  .extend as unknown as Record<string, Record<string, string>>;

export default function App({ Component, pageProps }: AppProps) {
  return (
    <ConfigProvider
      locale={zhTW}
      theme={{
        token: {
          ...colors,
          ...borderRadius,
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
const { Title } = Typography;

const Page: NextPage = () => {
  const [count, setCount] = useState(0);
  const [msg, msgConetext] = message.useMessage();
  return (
    <>
      {msgConetext}
      <Head>
        <title>Next + TailwindCSS + Antd</title>
      </Head>
      <div className="h-screen flex flex-col justify-center items-center text-center text-3xl">
        <a
          className="relative block w-[20vmin] h-[10vmin]"
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
        <Title className="text-colorPrimary">Next + TailwindCSS + Antd</Title>
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
