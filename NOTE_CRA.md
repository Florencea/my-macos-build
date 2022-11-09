# Create React App Note

- <https://create-react-app.dev/docs/getting-started/>

## cra + antd + tailwindCSS

```bash
npx create-react-app my-app --template typescript
```

```bash
cd my-app
```

```bash
rm -rf src/App.css src/index.css
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true --location=project
```

```bash
npx npm-check-updates --upgrade && npm update --save
```

- `package.json`

```json
{
  "scripts": {
    "dev": "craco start",
    "build": "craco build",
    "test": "craco test",
    "preview": "serve --single build",
    "prettier": "prettier --write '**/*.{js,jsx,tsx,ts,css,md}'",
    "deps:up": "npm update --save && npm run reset",
    "reset": "rm -rf node_modules build && npm install"
  },
  "eslintConfig": {
    "extends": ["react-app", "react-app/jest"]
  },
  "prettier": {
    "singleQuote": true
  },
  "homepage": ".",
  "browserslist": ["defaults"],
  "overrides": {
    "craco-antd": {
      "@craco/craco": "$@craco/craco"
    }
  }
}
```

```bash
npm install \
antd \
moment \
@craco/craco \
craco-antd \
tailwindcss \
postcss \
autoprefixer \
typescript \
eslint \
prettier \
serve
```

```bash
npx tailwindcss init --postcss
```

```bash
touch craco.config.js
```

- `craco.config.js`

```js
module.exports = {
  plugins: [
    {
      plugin: require('craco-antd'),
      options: {
        customizeTheme: {
          '@primary-color': require('tailwindcss/colors').cyan[500],
        },
      },
    },
  ],
};
```

- `tailwind.config.js`

```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  corePlugins: {
    preflight: false,
  },
  important: 'html > body',
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
};
```

- `src/index.tsx`

```tsx
import { ConfigProvider } from 'antd';
import zhTW from 'antd/es/locale/zh_TW';
import 'moment/locale/zh-tw';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import 'tailwindcss/tailwind.css';
import App from './App';
import reportWebVitals from './reportWebVitals';

const container = document.getElementById('root') as HTMLDivElement;
const root = createRoot(container);

root.render(
  <StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </StrictMode>
);

reportWebVitals();
```

- `src/App.tsx`

```tsx
import { Button, DatePicker, message } from 'antd';
import { useState } from 'react';
import logo from './logo.svg';

export default function App() {
  const [count, setCount] = useState(0);

  return (
    <div className="h-screen flex flex-col justify-center items-center text-3xl text-center space-y-3">
      <img src={logo} className="h-[30vmin]" alt="logo" />
      <div>Hello CRA + Antd + TailwindCSS!</div>
      <div className="space-x-2">
        <Button type="primary" onClick={() => setCount((count) => count + 1)}>
          count is: {count}
        </Button>
        <DatePicker
          onChange={(date) => {
            if (date !== null) {
              message.info(date.toLocaleString());
            }
          }}
        />
      </div>
      <a href="https://reactjs.org" target="_blank" rel="noopener noreferrer">
        Learn React
      </a>
    </div>
  );
}
```
