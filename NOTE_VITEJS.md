# Vite Note

- note for vite version: `2.9.9`
- <https://cn.vitejs.dev/>
- Works with npm, yarn, yarn2, pnpm
- Official: pnpm

## Vite

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
eslint-config-alloy
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
    "trailingComma": "none"
  }
}
```

## Ant Design

```bash
pnpm add antd @ant-design/icons @ant-design/colors moment
```

```bash
pnpm add -D less vite-plugin-imp
```

- `vite.config.ts`

```ts
import { presetPalettes } from '@ant-design/colors'
import react from '@vitejs/plugin-react'
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
          'primary-color': presetPalettes.blue.primary,
        },
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
import ReactDOM from 'react-dom'
import App from './App'

ReactDOM.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>,
  document.getElementById('root'),
)
```

## Windi CSS

```bash
pnpm add -D vite-plugin-windicss windicss
```

```bash
touch windi.config.ts
```

- `windi.config.ts`

```ts
import { defineConfig } from 'windicss/helpers'
import { presetPalettes } from '@ant-design/colors'

export default defineConfig({
  preflight: false,
  darkMode: false,
  important: '#root',
  theme: {
    extend: {
      colors: {
        white: '#fff',
        black: '#000',
        ...presetPalettes,
      },
    },
  },
})
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

- `src/main.tsx`

```tsx
import { ConfigProvider } from 'antd'
import zhTW from 'antd/es/locale/zh_TW'
import 'moment/dist/locale/zh-TW'
import { StrictMode } from 'react'
import ReactDOM from 'react-dom'
import 'virtual:windi.css'
import App from './App'

ReactDOM.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>,
  document.getElementById('root'),
)
```

## Index example

```bash
rm src/App.css
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
      <header
        className="h-screen flex flex-col justify-center items-center"
        style={{ fontSize: 'calc(10px + 2vmin)' }}
      >
        <img
          src={logo}
          className="h-[40vmin] pointer-events-none motion-safe:animate-spin"
          alt="logo"
        />
        <p>Hello Vite + React!</p>
        <p>
          <Button type="primary" onClick={() => setCount((count) => count + 1)}>
            count is: {count}
          </Button>
          <DatePicker
            onChange={(date) => {
              if (date !== null) {
                message.info(date.toISOString())
              }
            }}
          />
        </p>
        <p>
          Edit <code>App.tsx</code> and save to test HMR updates.
        </p>
        <p>
          <a
            className="App-link"
            href="https://reactjs.org"
            target="_blank"
            rel="noopener noreferrer"
          >
            Learn React
          </a>
          {' | '}
          <a
            className="App-link"
            href="https://vitejs.dev/guide/features.html"
            target="_blank"
            rel="noopener noreferrer"
          >
            Vite Docs
          </a>
        </p>
      </header>
    </div>
  )
}
```
