# Vite Note

- <https://cn.vitejs.dev/>
- Works with npm, yarn, pnpm

## Vite

```bash
npm init -y vite@latest vite-project -- --template react-ts
```

```bash
cd vite-project && npm install
```

- `package.json`

```json
{
  "license": "ISC",
  "private": true
}
```

- `vite.config.ts`

```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: 500,
    rollupOptions: {
      output: {
        manualChunks: {
          antd: ['antd']
        }
      }
    }
  },
  server: {
    proxy: {
      '/api': 'http://localhost:4000/'
    }
  }
});
```

## Ant Design

```bash
npm install antd @ant-design/icons
```

```bash
npm install -D less vite-plugin-imp
```

- `vite.config.ts`

```ts
import { defineConfig } from 'vite';
import imp from 'vite-plugin-imp';

export default defineConfig({
  plugins: [
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
        javascriptEnabled: true
      }
    }
  }
});
```

- `src/main.tsx`

```tsx
import { ConfigProvider } from 'antd';
import zhTW from 'antd/es/locale/zh_TW';
import 'moment/dist/locale/zh-TW';
import { StrictMode } from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import './index.css';

ReactDOM.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>,
  document.getElementById('root')
);
```

## Tailwind CSS

```bash
npm install -D tailwindcss@latest postcss@latest autoprefixer@latest
```

```bash
npx tailwindcss init -p
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
  purge: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  darkMode: false,
  theme: {
    colors: {
      white: '#fff',
      black: '#000',
      ...require('@ant-design/colors')
    },
    extend: {}
  },
  variants: {
    extend: {}
  },
  plugins: []
};
```
