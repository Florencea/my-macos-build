# Create React App Note

- <https://create-react-app.dev/docs/getting-started/>

## cra + antd + tailwindcss

```bash
npm -y create react-app -- my-app --template typescript
```

```bash
cd my-app
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true --location=project
```

```bash
npm install --save-dev \
react-scripts@latest \
@testing-library/jest-dom@latest \
@testing-library/react@latest \
@testing-library/user-event@latest \
@types/jest@latest \
@types/node@latest \
@types/react@latest \
@types/react-dom@latest \
typescript@latest \
web-vitals@latest \
tailwindcss \
postcss \
autoprefixer \
typescript \
eslint \
prettier \
sirv-cli \
shx
```

```bash
npm install \
react@latest \
react-dom@latest \
antd
```

```bash
touch .eslintrc.json
```

```bash
printf "/public\n/build\n" > .prettierignore
```

```bash
rm -rf src/App.css src/index.css
```

```bash
npx tailwindcss init --postcss
```

- `package.json`

```json
{
  "scripts": {
    "dev": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "preview": "sirv build --single --port 3000",
    "prettier": "prettier --write \"**/*\" --ignore-unknown",
    "deps:up": "npm update --save && npm run reset",
    "reset": "shx rm -rf node_modules build && npm install"
  },
  "browserslist": ["defaults"]
}
```

- `.eslintrc.json`

```json
{
  "extends": ["react-app", "react-app/jest"]
}
```

- `tailwind.config.js`

```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  corePlugins: {
    preflight: false,
  },
  important: "body",
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
};
```

- `src/index.tsx`

```tsx
import { ConfigProvider } from "antd";
import "antd/dist/reset.css";
import zhTW from "antd/locale/zh_TW";
import "dayjs/locale/zh-tw";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "tailwindcss/tailwind.css";
import App from "./App";
import reportWebVitals from "./reportWebVitals";

const container = document.getElementById("root") as HTMLDivElement;
const root = createRoot(container);

root.render(
  <StrictMode>
    <ConfigProvider
      locale={zhTW}
      theme={{
        token: {
          colorPrimary: "#2f54eb",
          colorInfo: "#2f54eb",
        },
      }}
    >
      <App />
    </ConfigProvider>
  </StrictMode>
);

reportWebVitals();
```

- `src/App.tsx`

```tsx
import { Button, DatePicker, message, Typography } from "antd";
import { useState } from "react";
import logo from "./logo.svg";
const { Link, Title } = Typography;

export default function App() {
  const [count, setCount] = useState(0);
  const [msg, msgConetext] = message.useMessage();

  return (
    <>
      {msgConetext}
      <div className="h-screen flex flex-col justify-center items-center text-3xl text-center space-y-3">
        <img src={logo} className="h-[30vmin]" alt="logo" />
        <Title>Hello CRA + Antd + TailwindCSS!</Title>
        <div className="space-x-2">
          <Button type="primary" onClick={() => setCount((count) => count + 1)}>
            count is: {count}
          </Button>
          <DatePicker
            onChange={(date) => {
              if (date !== null) {
                msg.info(date.toDate().toLocaleDateString("zh-TW"));
              }
            }}
          />
        </div>
        <Link
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </Link>
      </div>
    </>
  );
}
```
