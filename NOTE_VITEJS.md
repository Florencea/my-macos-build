# Vite Note

- <https://cn.vitejs.dev/>

## vite + antd + tailwindcss

```bash
npm -y create vite@latest vite-app -- --template react-swc-ts
```

```bash
cd vite-app
```

```bash
npm config set audit=false fund=false loglevel=error update-notifier=false engine-strict=true save=true --location=project
```

```bash
npm i -P \
@types/react@latest \
@types/react-dom@latest \
@vitejs/plugin-react-swc@latest \
react@latest \
react-dom@latest \
typescript@latest \
vite@latest \
antd \
eslint \
eslint-config-prettier \
eslint-plugin-react \
eslint-plugin-react-hooks \
@typescript-eslint/eslint-plugin \
@typescript-eslint/parser \
prettier \
tailwindcss \
postcss \
autoprefixer
```

```bash
npx tailwindcss init -p
```

```bash
printf "{\n  \"root\": true,\n  \"env\": {\n    \"browser\": true,\n    \"node\": true\n  },\n  \"settings\": {\n    \"react\": {\n      \"version\": \"detect\"\n    }\n  },\n  \"extends\": [\n    \"eslint:recommended\",\n    \"plugin:react/recommended\",\n    \"plugin:react/jsx-runtime\",\n    \"plugin:@typescript-eslint/recommended\",\n    \"prettier\"\n  ],\n  \"parser\": \"@typescript-eslint/parser\",\n  \"parserOptions\": {\n    \"ecmaFeatures\": {\n      \"jsx\": true\n    },\n    \"ecmaVersion\": \"latest\",\n    \"sourceType\": \"module\"\n  },\n  \"plugins\": [\n    \"react\",\n    \"react-hooks\",\n    \"@typescript-eslint\"\n  ]\n}" > .eslintrc.json
```

```bash
printf "/public\n/dist\n" > .eslintignore
```

```bash
printf "/public\n/dist\n" > .prettierignore
```

```bash
rm -rf src/App.css src/assets
```

- `package.json`

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint --ext .js,.jsx,.ts,.tsx,.mjs,.cjs . && tsc",
    "format": "prettier '**/*' --write --ignore-unknown"
  }
}
```

- `vite.config.ts`

```ts
import react from "@vitejs/plugin-react-swc";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: Infinity,
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
  important: "#root",
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
};
```

- `src/index.css`

```css
@import "antd/dist/reset.css";
@tailwind base;
@tailwind components;
@tailwind utilities;
```

- `src/main.tsx`

```tsx
import { App as AntApp, ConfigProvider } from "antd";
import zhTW from "antd/es/locale/zh_TW";
import "dayjs/locale/zh-tw";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./index.css";

const container = document.getElementById("root") as HTMLDivElement;
const root = createRoot(container);

root.render(
  <StrictMode>
    <ConfigProvider
      getPopupContainer={() => container}
      locale={zhTW}
      theme={{
        token: {
          colorPrimary: "#722ed1",
          colorInfo: "#722ed1",
          colorLink: "#722ed1",
          colorLinkHover: "#722ed1",
          colorLinkActive: "#722ed1",
        },
      }}
    >
      <AntApp>
        <App />
      </AntApp>
    </ConfigProvider>
  </StrictMode>
);
```

- `src/App.tsx`

```tsx
import { App as AntApp, Button, DatePicker } from "antd";
import { useState } from "react";

export default function App() {
  const [count, setCount] = useState(0);
  const { message } = AntApp.useApp();

  return (
    <div className="flex h-screen flex-col items-center justify-center text-center text-3xl">
      <div className="space-x-8">
        <a href="https://vitejs.dev" target="_blank" rel="noreferrer">
          <img
            src="/vite.svg"
            className="pointer-events-none mb-10 h-[20vmin]"
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
              message.info(date.toDate().toLocaleDateString("zh-TW"));
            }
          }}
        />
      </div>
    </div>
  );
}
```
