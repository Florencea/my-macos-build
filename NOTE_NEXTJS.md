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
npm uninstall typescript
```

```bash
npm install \
next@latest \
react@latest \
react-dom@latest \
antd \
next-with-less \
dotenv-cli
```

```bash
npm install --save-dev \
@types/node@latest \
@types/react@latest \
@types/react-dom@latest \
eslint@latest \
eslint-config-next@latest \
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
rm -rf styles .eslintrc.json
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
  },
  "eslintConfig": {
    "extends": ["next/core-web-vitals"]
  }
}
```

- `next.config.js`

```js
const withLess = require("next-with-less");

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
  lessLoaderOptions: {
    lessOptions: {
      modifyVars: {
        "primary-color": "#2f54eb",
      },
    },
  },
};

module.exports = withLess(nextConfig);
```

- `tailwind.config.js`

```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  corePlugins: {
    preflight: false,
  },
  important: "html > body",
  content: [
    "./pages/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
  ],
};
```

- `pages/_app.tsx`

```tsx
import { ConfigProvider } from "antd";
import "antd/dist/antd.less";
import zhTW from "antd/lib/locale/zh_TW";
import moment from "moment";
import "moment/locale/zh-tw";
import type { AppProps } from "next/app";
import "tailwindcss/tailwind.css";

export default function App({ Component, pageProps }: AppProps) {
  return (
    <ConfigProvider locale={zhTW}>
      <Component {...pageProps} />
    </ConfigProvider>
  );
}
```

- `pages/index.tsx`

```tsx
import { Button, DatePicker, message } from "antd";
import { NextPage } from "next";
import Image from "next/image";
import { useState } from "react";

const Page: NextPage = () => {
  const [count, setCount] = useState(0);
  return (
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
      <p>next + tailwindcss + antd</p>
      <div className="flex justify-center space-x-3">
        <Button type="primary" onClick={() => setCount((count) => count + 1)}>
          count is: {count}
        </Button>
        <DatePicker
          onChange={(date) => {
            if (date !== null) {
              message.info(date.toLocaleString());
            }
          }}
        />
      </div>
    </div>
  );
};

export default Page;
```
