# Vite Note

- <https://cn.vitejs.dev/>
- Works with npm, yarn, yarn2, pnpm
- Official: pnpm

## Vite

```bash
yarn create vite vite-project --template react-ts
```

```bash
cd vite-project && yarn
```

## Ant Design

```bash
yarn add antd @ant-design/icons @ant-design/colors
```

```bash
yarn add -D less vite-plugin-imp
```

- `vite.config.ts`

```ts
import { blue } from '@ant-design/colors'
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
          style: (name) => `antd/es/${name}/style`
        }
      ]
    })
  ],
  css: {
    preprocessorOptions: {
      less: {
        javascriptEnabled: true,
        modifyVars: {
          'primary-color': blue.primary
        }
      }
    }
  }
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
import './index.css'

ReactDOM.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>,
  document.getElementById('root')
)
```

## Tailwind CSS

```bash
yarn add -D tailwindcss postcss autoprefixer
```

```bash
yarn run tailwindcss init -p
```

```bash
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' > src/index.css
```

- `tailwind.config.js`

```js
module.exports = {
  corePlugins: {
    preflight: false
  },
  important: '#root',
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  darkMode: 'media',
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
