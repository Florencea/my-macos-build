# Vite Note

- Scaffold a project with [Vite](https://vitejs.dev/), [Ant Design](https://ant.design/) and [Tailwind CSS](https://tailwindcss.com/)

- [Vite Note](#vite-note)
  - [CLI](#cli)
  - [FILES](#files)
    - [`.eslintignore`](#eslintignore)
    - [`eslint.config.js`](#eslintconfigjs)
    - [`.npmrc`](#npmrc)
    - [`.prettierignore`](#prettierignore)
    - [`.prettierrc.json`](#prettierrcjson)
    - [`package.json`](#packagejson)
    - [`tailwind.config.ts`](#tailwindconfigts)
    - [`vite.config.ts`](#viteconfigts)
    - [`src/main.tsx`](#srcmaintsx)
    - [`src/App.tsx`](#srcapptsx)

## CLI

```sh
npm -y create vite@latest vite-app -- --template react-ts
```

```sh
cd vite-app
```

```sh
npm i -D --save \
@types/react@latest \
@types/react-dom@latest \
@vitejs/plugin-react@latest \
react@latest \
react-dom@latest \
typescript@latest \
vite@latest \
antd@latest \
@ant-design/cssinjs@latest \
dayjs@latest \
eslint@latest \
@typescript-eslint/eslint-plugin@latest \
@typescript-eslint/parser@latest \
eslint-plugin-react-hooks@latest \
eslint-plugin-react-refresh@latest \
eslint-config-prettier@latest \
globals \
prettier@latest \
tailwindcss@latest \
postcss@latest \
autoprefixer@latest
```

```sh
npx tailwindcss init -p --ts
```

```sh
rm -rf .eslintrc.cjs src/assets src/App.css src/index.css
```

```sh
touch .eslintignore eslint.config.js .prettierignore .prettierrc.json .npmrc
```

```sh
code .
```

## FILES

### `.eslintignore`

```ignore
/public
/dist
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
/public
/dist
```

### `.prettierrc.json`

```json
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "all"
}
```

### `eslint.config.js`

```js
import js from '@eslint/js'
import tsPlugin from '@typescript-eslint/eslint-plugin'
import tsParser from '@typescript-eslint/parser'
import prettier from 'eslint-config-prettier'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import globals from 'globals'

export default [
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      globals: globals.browser,
      parser: tsParser,
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
      '@typescript-eslint': tsPlugin,
    },
    rules: {
      ...js.configs.recommended.rules,
      ...tsPlugin.configs.recommended.rules,
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': 'warn',
    },
  },
  prettier,
]
```

### `package.json`

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint src --report-unused-disable-directives --max-warnings 0 && tsc",
    "format": "prettier '**/*' --write --ignore-unknown --cache"
  }
}
```

### `tailwind.config.ts`

```ts
import type { Config } from 'tailwindcss'

export default {
  important: '#root',
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
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

### `vite.config.ts`

```ts
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: Infinity,
    reportCompressedSize: false,
  },
})
```

### `src/main.tsx`

```tsx
import { StyleProvider } from '@ant-design/cssinjs'
import { App as AntApp, ConfigProvider } from 'antd'
import zhTW from 'antd/es/locale/zh_TW'
import 'dayjs/locale/zh-tw'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import 'tailwindcss/tailwind.css'
import tailwindConfig from '../tailwind.config'
import App from './App'

const container = document.getElementById('root') as HTMLDivElement

const PRIMARY_COLOR = tailwindConfig.theme.extend.colors.primary

createRoot(container).render(
  <StrictMode>
    <ConfigProvider
      getPopupContainer={() => container}
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
      <StyleProvider hashPriority="high">
        <AntApp>
          <App />
        </AntApp>
      </StyleProvider>
    </ConfigProvider>
  </StrictMode>,
)
```

### `src/App.tsx`

```tsx
import {
  App as AntApp,
  DatePicker,
  Descriptions,
  Space,
  Tag,
  version,
} from 'antd'

export default function App() {
  const { message } = AntApp.useApp()
  return (
    <div className="flex h-screen flex-col items-center justify-center gap-3 text-center">
      <a href="https://vitejs.dev" target="_blank" rel="noreferrer">
        <img
          src="/vite.svg"
          className="pointer-events-none h-[20vmin]"
          alt="Vite logo"
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
                if (!date) return
                message.info(date?.toDate().toLocaleString())
              }}
            />
          </Space>
        </Descriptions.Item>
      </Descriptions>
    </div>
  )
}
```
