# Vite Note

- <https://cn.vitejs.dev/>

## vite + antd + tailwindcss

```bash
npm -y create vite vite-project -- --template react-ts
```

```bash
cd vite-project
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true save-exact=true --location=project
```

```bash
npm install --save-prod \
@types/react@latest \
@types/react-dom@latest \
@vitejs/plugin-react@latest \
react@latest \
react-dom@latest \
typescript@latest \
vite@latest \
antd \
eslint \
eslint-config-react-app \
prettier \
tailwindcss \
postcss \
autoprefixer \
shx
```

```bash
npx tailwindcss init --postcss
```

```bash
printf "{\n  \"extends\": \"react-app\"\n}\n" > .eslintrc.json
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
    "prettier": "prettier --write '**/*' --ignore-unknown",
    "deps:up": "npm update --save && npm run reset",
    "reset": "shx rm -rf node_modules dist && npm install"
  }
}
```

- `vite.config.ts`

```ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: Infinity,
    reportCompressedSize: false,
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
  important: "body",
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
};
```

- `src/main.tsx`

```tsx
import { ConfigProvider } from "antd";
import "antd/dist/reset.css";
import zhTW from "antd/es/locale/zh_TW";
import "dayjs/locale/zh-tw";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "tailwindcss/tailwind.css";
import App from "./App";

const container = document.getElementById("root") as HTMLDivElement;
const root = createRoot(container);

root.render(
  <StrictMode>
    <ConfigProvider
      locale={zhTW}
      theme={{
        token: {
          colorPrimary: "#722ed1",
          colorInfo: "#722ed1",
        },
      }}
    >
      <App />
    </ConfigProvider>
  </StrictMode>
);
```

- `src/App.tsx`

```tsx
import { Button, DatePicker, message } from "antd";
import { useState } from "react";

export default function App() {
  const [count, setCount] = useState(0);
  const [msg, msgConetext] = message.useMessage();

  return (
    <>
      {msgConetext}
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
      </div>
    </>
  );
}
```
