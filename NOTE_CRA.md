# Create React App Note

- <https://create-react-app.dev/docs/getting-started/>

## cra + antd + tailwindcss

```bash
npm -y create react-app -- cra-app --template typescript
```

```bash
cd cra-app
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true save-exact=true --location=project
```

```bash
npm i -P \
react@latest \
react-dom@latest \
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
antd \
tailwindcss \
postcss \
autoprefixer \
typescript \
eslint \
prettier \
prettier-plugin-tailwindcss \
sirv-cli \
dotenv-cli
```

```bash
printf "PORT=3000\n" > .env
```

```bash
printf "defaults\n" > .browserslistrc
```

```bash
printf "{\n  \"extends\": [\"react-app\", \"react-app/jest\"]\n}\n" > .eslintrc.json
```

```bash
printf "/public\n/build\n" > .prettierignore
```

```bash
rm -rf src/App.css src/index.css
```

```bash
npx tailwindcss init -p
```

- `package.json`

```json
{
  "scripts": {
    "dev": "dotenv react-scripts start",
    "build": "dotenv react-scripts build",
    "test": "dotenv react-scripts test",
    "preview": "dotenv sirv build --single",
    "prettier": "prettier --write \"**/*\" --ignore-unknown"
  }
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
      <div className="flex h-screen flex-col items-center justify-center space-y-3 text-center text-3xl">
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
