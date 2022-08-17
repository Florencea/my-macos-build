# Vite Note

- <https://cn.vitejs.dev/>

## vite + antd + tailwindCSS

```bash
npm create vite vite-project -- --template react-ts
```

```bash
cd vite-project && printf "audit=false\nfund=false\nloglevel=error\n" > .npmrc && npm i && npm rm react react-dom
```

```bash
npm i -D \
react \
react-dom \
antd \
@ant-design/icons \
@ant-design/colors \
moment \
typescript \
eslint \
eslint-config-react-app \
prettier \
less \
vite-plugin-imp \
tailwindcss \
postcss \
autoprefixer
```

```bash
npx tailwindcss init -p
```

```bash
rm src/App.css src/index.css
```

- `package.json`

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "reset": "sudo rm -rf node_modules dist && npm i"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "prettier": {
    "arrowParens": "avoid",
    "singleQuote": true,
    "semi": true
  }
}
```

- `vite.config.ts`

```ts
import { presetDarkPalettes } from '@ant-design/colors';
import react from '@vitejs/plugin-react';
import { getThemeVariables } from 'antd/dist/theme.js';
import { defineConfig } from 'vite';
import imp from 'vite-plugin-imp';

export default defineConfig({
  plugins: [
    react(),
    imp({
      libList: [
        {
          libName: 'antd',
          libDirectory: 'es',
          style: name => `antd/es/${name}/style`,
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
});
```

- `tailwind.config.cjs`

```js
const { presetDarkPalettes } = require('@ant-design/colors');

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
};
```

- `src/main.tsx`

```tsx
import { ConfigProvider } from 'antd';
import zhTW from 'antd/es/locale/zh_TW';
import 'moment/dist/locale/zh-TW';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import 'tailwindcss/tailwind.css';
import App from './App';

const container = document.getElementById('root') as HTMLDivElement;
const root = createRoot(container);

root.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>
);
```

- `src/App.tsx`

```tsx
import { Button, DatePicker, message } from 'antd';
import { useState } from 'react';
import reactLogo from './assets/react.svg';

export default function App() {
  const [count, setCount] = useState(0);

  return (
    <div className="h-screen flex flex-col justify-center items-center text-center text-3xl">
      <div className="space-x-8">
        <a href="https://vitejs.dev" target="_blank" rel="noreferrer">
          <img
            src="/vite.svg"
            className="h-[20vmin] pointer-events-none mb-10"
            alt="Vite logo"
          />
        </a>
        <a href="https://reactjs.org" target="_blank" rel="noreferrer">
          <img
            src={reactLogo}
            className="h-[20vmin] pointer-events-none motion-safe:animate-spin mb-10"
            alt="React logo"
          />
        </a>
      </div>
      <p>Vite + React + TailwindCSS + antd</p>
      <div className="flex justify-center space-x-3">
        <Button type="primary" onClick={() => setCount(count => count + 1)}>
          count is: {count}
        </Button>
        <DatePicker
          onChange={date => {
            if (date !== null) {
              message.info(date.toLocaleString());
            }
          }}
        />
      </div>
    </div>
  );
}
```
