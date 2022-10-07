# Vite Note

- <https://cn.vitejs.dev/>

## vite + antd + tailwindCSS

```bash
npm create vite vite-project -- --template react-ts
```

```bash
cd vite-project && printf "audit=false\nfund=false\nloglevel=error\nupdate-notifier=false\n" > .npmrc && npm i && npm rm react react-dom
```

```bash
npm i -D \
react \
react-dom \
antd \
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
rm -rf src/App.css src/index.css src/assets
```

- `package.json`

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "prettier": "prettier --write '**/*.{js,jsx,tsx,ts,md,json}'",
    "deps:up": "npm up --save && npm run reset",
    "reset": "rm -rf node_modules dist && npm i"
  },
  "eslintConfig": {
    "extends": [
      "react-app"
    ]
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
import pluginReact from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import pluginImp from 'vite-plugin-imp';

export default defineConfig({
  plugins: [
    pluginReact(),
    pluginImp({
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
          'primary-color': '#2f54eb',
        },
      },
    },
  },
});

```

- `tailwind.config.cjs`

```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  corePlugins: {
    preflight: false,
  },
  important: 'html > body',
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
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
