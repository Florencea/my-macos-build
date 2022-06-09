# Vite Note

- vite: `2.9.x`, react: `18.x`
- <https://cn.vitejs.dev/>
- Works with npm, yarn, yarn2, pnpm
- Official: pnpm

## vite + antd + windi

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
vite-plugin-windicss \
windicss
```

```bash
pnpm add \
antd \
@ant-design/icons \
@ant-design/colors \
moment
```

```bash
touch windi.config.ts
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
import { presetPalettes } from '@ant-design/colors'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import imp from 'vite-plugin-imp'
import windiCss from 'vite-plugin-windicss'

export default defineConfig({
  plugins: [
    react(),
    windiCss(),
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
          'primary-color': presetPalettes.blue.primary,
        },
      },
    },
  },
})
```

- `windi.config.ts`

```ts
import { defineConfig } from 'windicss/helpers'
import { presetPalettes } from '@ant-design/colors'

export default defineConfig({
  preflight: false,
  attributify: false,
  darkMode: false,
  important: '#root',
  theme: {
    extend: {
      colors: {
        white: '#fff',
        black: '#000',
        ...presetPalettes,
      },
      animation: {
        spin: 'spin 20s linear infinite',
      },
    },
  },
})
```

- `src/main.tsx`

```tsx
import { ConfigProvider } from 'antd'
import zhTW from 'antd/es/locale/zh_TW'
import 'moment/dist/locale/zh-TW'
import { StrictMode } from 'react'
import ReactDOM from 'react-dom/client'
import 'virtual:windi.css'
import App from './App'

const rootNode = document.getElementById('root') as HTMLElement

const root = ReactDOM.createRoot(rootNode)

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
    <div className="text-center bg-[#282c34] text-white">
      <header className="h-screen flex flex-col justify-center items-center text-3xl space-y-3">
        <img
          src={logo}
          className="h-[40vmin] pointer-events-none motion-safe:animate-spin"
          alt="logo"
        />
        <div>Hello Vite + React!</div>
        <div className="space-x-2">
          <Button type="primary" onClick={() => setCount((count) => count + 1)}>
            count is: {count}
          </Button>
          <DatePicker
            onChange={(date) => {
              if (date !== null) {
                message.info(date.toDate().toLocaleDateString())
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
