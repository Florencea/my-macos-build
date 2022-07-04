# Create React App Note

- cra: `5.0.1`, react: `18.x`
- <https://create-react-app.dev/docs/getting-started/>

## cra + antd + tailwindCSS

```bash
yarn create react-app my-app --template typescript
```

```bash
cd my-app
```

```bash
yarn add \
antd \
@ant-design/icons \
@ant-design/colors \
moment \
serve \
@craco/craco \
craco-antd \
tailwindcss \
postcss \
autoprefixer
```

```bash
yarn remove \
@testing-library/jest-dom \
@testing-library/react \
@testing-library/user-event \
@types/jest \
web-vitals
```

```bash
yarn tailwindcss init -p
```

```bash
touch craco.config.js
```

```bash
rm src/App.css src/index.css src/reportWebVitals.ts src/App.test.tsx src/setupTests.ts
```

- `package.json`

```json
{
  "scripts": {
    "dev": "craco start",
    "build": "craco build",
    "preview": "serve -s build",
    "eject": "react-scripts eject"
  },
  "prettier": {
    "semi": false,
    "singleQuote": true,
    "trailingComma": "all"
  }
}
```

- `craco.config.js`

```js
const CracoAntDesignPlugin = require('craco-antd')
const { presetDarkPalettes } = require('@ant-design/colors')
const { getThemeVariables } = require('antd/dist/theme')

module.exports = {
  plugins: [
    {
      plugin: CracoAntDesignPlugin,
      options: {
        customizeTheme: {
          ...getThemeVariables({
            dark: true,
          }),
          '@primary-color': presetDarkPalettes.cyan.primary,
        },
      },
    },
  ],
}
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
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
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

- `src/index.tsx`

```tsx
import { ConfigProvider } from 'antd'
import zhTW from 'antd/es/locale/zh_TW'
import 'moment/locale/zh-tw'
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
        <div>Hello CRA + Antd + TailwindCSS!</div>
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
        <a href="https://reactjs.org" target="_blank" rel="noopener noreferrer">
          Learn React
        </a>
      </header>
    </div>
  )
}
```
