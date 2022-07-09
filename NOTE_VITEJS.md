# Vite Note

- vite: `2.9.x`, react: `18.x`
- <https://cn.vitejs.dev/>

## vite + antd + tailwindCSS

```bash
pnpm create vite vite-project --template react-ts
```

```bash
cd vite-project && pnpm i
```

```bash
pnpm add -D \
eslint \
typescript \
@typescript-eslint/parser \
@typescript-eslint/eslint-plugin \
eslint-plugin-react \
eslint-config-alloy \
less \
vite-plugin-imp \
tailwindcss \
postcss \
autoprefixer
```

```bash
pnpm add \
antd \
@ant-design/icons \
@ant-design/colors \
moment
```

```bash
pnpm tailwindcss init -p
```

```bash
rm src/App.css
```

- `package.json`

```json
{
  "eslintConfig": {
    "extends": ["alloy", "alloy/react", "alloy/typescript"],
    "env": {
      "browser": true
    },
    "globals": {
      "React": "readonly",
      "JSX": "readonly"
    },
    "rules": {
      "spaced-comment": [
        "error",
        "always",
        {
          "markers": ["/"]
        }
      ],
      "@typescript-eslint/no-require-imports": 0
    }
  },
  "prettier": {
    "semi": false,
    "singleQuote": true,
    "trailingComma": "all"
  }
}
```

- `vite.config.ts`

```ts
import { presetDarkPalettes } from '@ant-design/colors'
import react from '@vitejs/plugin-react'
import { getThemeVariables } from 'antd/dist/theme'
import { defineConfig } from 'vite'
import imp from 'vite-plugin-imp'

export default defineConfig({
  plugins: [
    react(),
    imp({
      libList: [
        {
          libName: 'antd',
          libDirectory: 'es',
          style: (name) => `antd/es/${name}/style`,
        },
      ],
    }),
  ],
  css: {
    preprocessorOptions: {
      less: {
        javascriptEnabled: true,
        modifyVars: {
          ...getThemeVariables({
            dark: true,
          }),
          'primary-color': presetDarkPalettes.cyan.primary,
        },
      },
    },
  },
})
```

- `tailwind.config.js`

```js
const { presetDarkPalettes } = require('@ant-design/colors')

/** @type {import('tailwindcss').Config} */
module.exports = {
  corePlugins: {
    preflight: false,
  },
  important: '#root',
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        white: '#fff',
        black: '#000',
        ...presetDarkPalettes,
      },
      animation: {
        spin: 'spin 20s linear infinite',
      },
    },
  },
  plugins: [],
}
```

- `src/main.tsx`

```tsx
import { ConfigProvider } from 'antd'
import zhTW from 'antd/es/locale/zh_TW'
import 'moment/dist/locale/zh-TW'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import 'tailwindcss/tailwind.css'
import App from './App'

const container = document.getElementById('root') as HTMLDivElement
const root = createRoot(container)

root.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>,
)
```

- `src/App.tsx`

```tsx
import { Button, DatePicker, message } from 'antd'
import { useState } from 'react'
import logo from './logo.svg'

export default function App() {
  const [count, setCount] = useState(0)

  return (
    <div className="text-center">
      <header className="h-screen flex flex-col justify-center items-center text-3xl space-y-3">
        <img
          src={logo}
          className="h-[40vmin] pointer-events-none motion-safe:animate-spin"
          alt="logo"
        />
        <div>Hello Vite + Antd + TailwindCSS!</div>
        <div className="space-x-2">
          <Button type="primary" onClick={() => setCount((count) => count + 1)}>
            count is: {count}
          </Button>
          <DatePicker
            onChange={(date) => {
              if (date !== null) {
                message.info(date.toLocaleString())
              }
            }}
          />
        </div>
        <div>
          Edit <code>App.tsx</code> and save to test HMR updates.
        </div>
      </header>
    </div>
  )
}
```
