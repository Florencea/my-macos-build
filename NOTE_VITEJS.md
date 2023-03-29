# Vite Note

- <https://cn.vitejs.dev/>

## vite + antd + tailwindcss

```bash
npm -y create vite@latest vite-app -- --template react-swc-ts
```

```bash
cd vite-app
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true save=true --location=project
```

```bash
npm i -P \
@types/react@latest \
@types/react-dom@latest \
@vitejs/plugin-react-swc@latest \
react@latest \
react-dom@latest \
typescript@latest \
vite@latest \
antd \
@ant-design/cssinjs \
dayjs \
eslint \
eslint-config-prettier \
eslint-plugin-react \
eslint-plugin-react-hooks \
@typescript-eslint/eslint-plugin \
@typescript-eslint/parser \
prettier \
tailwindcss \
postcss \
autoprefixer
```

```bash
npx tailwindcss init -p --ts
```

```bash
printf "{\n  \"root\": true,\n  \"env\": {\n    \"browser\": true,\n    \"node\": true\n  },\n  \"settings\": {\n    \"react\": {\n      \"version\": \"detect\"\n    }\n  },\n  \"extends\": [\n    \"eslint:recommended\",\n    \"plugin:react/recommended\",\n    \"plugin:react/jsx-runtime\",\n    \"plugin:@typescript-eslint/recommended\",\n    \"prettier\"\n  ],\n  \"parser\": \"@typescript-eslint/parser\",\n  \"parserOptions\": {\n    \"ecmaFeatures\": {\n      \"jsx\": true\n    },\n    \"ecmaVersion\": \"latest\",\n    \"sourceType\": \"module\"\n  },\n  \"plugins\": [\"react\", \"react-hooks\", \"@typescript-eslint\"]\n}\n" > .eslintrc.json
```

```bash
printf "/public\n/dist\n" > .eslintignore
```

```bash
printf "{\n  \"singleQuote\": true,\n  \"semi\": false\n}\n" > .prettierrc.json
```

```bash
printf "/public\n/dist\n" > .prettierignore
```

```bash
rm -rf src/App.css src/index.css src/assets
```

- `package.json`

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint --ext .js,.jsx,.ts,.tsx,.mjs,.cjs . && tsc",
    "format": "prettier '**/*' --write --ignore-unknown"
  }
}
```

- `vite.config.ts`

```ts
import react from '@vitejs/plugin-react-swc'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: Infinity,
  },
})
```

- `tailwind.config.ts`

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

- `src/main.tsx`

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
const root = createRoot(container)

const PRIMARY_COLOR = tailwindConfig.theme.extend.colors.primary

root.render(
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
  </StrictMode>
)
```

- `src/App.tsx`

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
