# Create React App Note

- <https://create-react-app.dev/docs/getting-started>
- Works with npm, yarn
- Official: yarn

## Create React App

```bash
yarn create react-app my-app --template typescript && cd my-app
```

```bash
yarn add -D @craco/craco prettier serve
```

```bash
touch craco.config.js
```

- `package.json`

```json
{
  "prettier": {
    "semi": false,
    "singleQuote": true,
    "trailingComma": "all"
  },
  "scripts": {
    "dev": "craco start",
    "build": "craco build",
    "test": "craco test",
    "serve": "serve -s build",
    "eject": "react-scripts eject",
    "prettier": "prettier --write '**/*.{js,jsx,tsx,ts,less,md}'"
  }
}
```

- `craco.config.js`

```js
module.exports = {
  typescript: {
    enableTypeChecking: false,
  },
  webpack: {
    configure: { stats: 'errors-only' },
  },
}
```

## Ant Design

```bash
yarn add antd @ant-design/icons @ant-design/colors craco-less moment
```

- `craco.config.js`

```js
const { getThemeVariables } = require('antd/dist/theme')
const { presetDarkPalettes } = require('@ant-design/colors')
const CracoLessPlugin = require('craco-less')

module.exports = {
  plugins: [
    {
      plugin: CracoLessPlugin,
      options: {
        lessLoaderOptions: {
          lessOptions: {
            modifyVars: {
              ...getThemeVariables({
                dark: true,
              }),
              '@primary-color': presetDarkPalettes.blue.primary,
            },
            javascriptEnabled: true,
          },
        },
      },
    },
  ],
}
```

- `src/index.tsx`

```tsx
import { ConfigProvider } from 'antd'
import 'antd/dist/antd.less'
import zhTW from 'antd/lib/locale/zh_TW'
import 'moment/locale/zh-tw'
import React from 'react'
import ReactDOM from 'react-dom'
import App from './App'
import reportWebVitals from './reportWebVitals'

ReactDOM.render(
  <React.StrictMode>
    <ConfigProvider locale={zhTW}>
      <App />
    </ConfigProvider>
  </React.StrictMode>,
  document.getElementById('root'),
)

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals()
```

## Tailwind CSS

```bash
yarn add -D tailwindcss postcss autoprefixer
```

```bash
yarn run tailwindcss init
```

```bash
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' > src/_tailwind.css
```

- `tailwind.config.js`

```js
const { presetDarkPalettes } = require('@ant-design/colors')

module.exports = {
  corePlugins: {
    preflight: false,
  },
  important: '#root',
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
  darkMode: 'media',
  theme: {
    colors: {
      white: '#fff',
      black: '#000',
      ...presetDarkPalettes,
      primary: presetDarkPalettes.blue.primary,
    },
    extend: {
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
import './_tailwind.css'
```

## antd + tailwindcss example

```bash
rm src/App.css
```

- `src/App.tsx`

```tsx
import { Button, DatePicker, message } from 'antd'
import { useState } from 'react'
import logo from './logo.svg'

function App() {
  const [count, setCount] = useState(0)

  return (
    <div className="text-center">
      <header
        className="h-screen flex flex-col justify-center items-center text-white"
        style={{ fontSize: 'calc(10px + 2vmin)' }}
      >
        <img
          src={logo}
          className="h-[40vmin] pointer-events-none motion-safe:animate-spin"
          alt="logo"
        />
        <p>Hello React!</p>
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

export default App
```
