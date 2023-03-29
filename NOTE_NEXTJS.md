# Next.js Note

- <https://nextjs.org/docs/getting-started>

## Next.js + antd + tailwindCSS

```bash
npx -y create-next-app@latest next-app --typescript --eslint --use-npm --no-src-dir --no-experimental-app --import-alias "@/*"
```

```bash
cd next-app
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true save=true --location=project
```

```bash
printf "{\n  \"extends\": [\n    \"next/core-web-vitals\",\n    \"prettier\"\n  ]\n}\n" > .eslintrc.json
```

```bash
printf "{\n  \"singleQuote\": true,\n  \"semi\": false\n}\n" > .prettierrc.json
```

```bash
printf ".next\nnext-env.d.ts\n/public\n/out\n" > .prettierignore
```

```bash
printf "PORT=3000\nNEXT_TELEMETRY_DISABLED=1\n" > .env
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

```bash
npx tailwindcss init -p --ts
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
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },
}

module.exports = nextConfig
```

- `postcss.config.js`

```js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

- `tailwind.config.ts`

```ts
import type { Config } from 'tailwindcss'

export default {
  important: '#__next',
  content: [
    './pages/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#722ed1',
      },
    },
  },
  plugins: [],
} satisfies Config
```

- `pages/_app.tsx`

```tsx
import { StyleProvider } from '@ant-design/cssinjs'
import { App as AntApp, ConfigProvider } from 'antd'
import zhTW from 'antd/locale/zh_TW'
import 'dayjs/locale/zh-tw'
import type { AppProps } from 'next/app'
import 'tailwindcss/tailwind.css'
import tailwindConfig from '../tailwind.config'

const PRIMARY_COLOR = tailwindConfig.theme.extend.colors.primary

export default function App({ Component, pageProps }: AppProps) {
  return (
    <StyleProvider hashPriority="high">
      <ConfigProvider
        getPopupContainer={
          typeof window !== 'undefined'
            ? () => document.getElementById('__next') as HTMLDivElement
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
  )
}
```

- `pages/index.tsx`

```tsx
import { App as AntApp, Button, DatePicker, Typography } from 'antd'
import { NextPage } from 'next'
import Head from 'next/head'
import Image from 'next/image'
import { useState } from 'react'

const Page: NextPage = () => {
  const [count, setCount] = useState(0)
  const { message } = AntApp.useApp()
  return (
    <>
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
            src="/next.svg"
            className="pointer-events-none mb-10"
            alt="Vercel logo"
            fill
          />
        </a>
        <Typography.Title>Next + TailwindCSS + Antd</Typography.Title>
        <div className="flex justify-center space-x-3">
          <Button type="primary" onClick={() => setCount((count) => count + 1)}>
            count is: {count}
          </Button>
          <DatePicker
            onChange={(date) => {
              if (date !== null) {
                message.info(date.toDate().toLocaleDateString('zh-TW'))
              }
            }}
          />
        </div>
      </div>
    </>
  )
}

export default Page
```
