# Next.js Note

- <https://nextjs.org/docs/getting-started>
- Works with npm, yarn, yarn2, pnpm

## Next.js

```bash
npx -y create-next-app@latest --typescript
```

- `package.json`

```json
{
  "prettier": {
    "semi": false,
    "singleQuote": true,
    "trailingComma": "none"
  }
}
```

## Ant Design

```bash
npm install antd @ant-design/icons @ant-design/colors next-with-less
```

- `next.config.js`

```js
/** @type {import('next').NextConfig} */
const withLess = require('next-with-less')
const { volcano } = require('@ant-design/colors')

module.exports = withLess({
  exportPathMap: async () => ({
    '/': { page: '/' }
  }),
  images: {
    loader: 'custom'
  },
  reactStrictMode: true,
  lessLoaderOptions: {
    lessOptions: {
      modifyVars: {
        'primary-color': volcano.primary
      }
    }
  }
})
```

- `pages/_app.tsx`

```tsx
import { ConfigProvider } from 'antd'
import 'antd/dist/antd.dark.less'
import zhTW from 'antd/lib/locale/zh_TW'
import moment from 'moment'
import 'moment/locale/zh-tw'
import type { AppProps } from 'next/app'
import '../styles/globals.css'

moment.locale('zh-tw')

function MyApp({ Component, pageProps }: AppProps) {
  return (
    <ConfigProvider locale={zhTW}>
      <Component {...pageProps} />
    </ConfigProvider>
  )
}

export default MyApp
```

## Tailwind CSS

```bash
npm install -D tailwindcss postcss autoprefixer
```

```bash
npx tailwindcss init -p
```

```bash
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' > styles/globals.css
```

- `tailwind.config.js`

```js
module.exports = {
  corePlugins: {
    preflight: false
  },
  important: '#__next',
  content: [
    './pages/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}'
  ],
  darkMode: true,
  theme: {
    colors: {
      white: '#fff',
      black: '#000',
      ...require('@ant-design/colors')
    },
    extend: {}
  },
  plugins: []
}
```
