# Vite Note

- <https://vitejs.dev/>

## Vite

```bash
yarn create @vitejs/app vite-project --template react-ts
```

```bash
cd vite-project && yarn
```

- `vite.config.ts`

```ts
import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [reactRefresh()],
  build: {
    // chunk size limit warning, default: 500
    chunkSizeWarningLimit: 500,
    rollupOptions: {
      output: {
        // split libraries to different chunk
        // example here split 'antd' library to single chunk
        manualChunks: {
          antd: ["antd"],
        },
      },
    },
  },
  server: {
    proxy: {
      "/api": "http://localhost:4000/",
    },
  },
});
```

## Ant Design

```bash
yarn add antd @ant-design/icons
```

```bash
yarn add less vite-plugin-imp --dev
```

- `vite.config.ts`

```ts
import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";
import vitePluginImp from "vite-plugin-imp";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    reactRefresh(),
    vitePluginImp({
      libList: [
        {
          libName: "antd",
          // dynamic import
          style: (name) => `antd/es/${name}/style`,
        },
      ],
    }),
  ],
  css: {
    preprocessorOptions: {
      less: {
        javascriptEnabled: true,
      },
    },
  },
});
```

## Tailwind CSS

```bash
yarn add tailwindcss@latest postcss@latest autoprefixer@latest --dev
```

```bash
npx tailwindcss init -p
```

```bash
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' >> src/_tailwind.css
```

- `tailwind.config.js`

```js
module.exports = {
  purge: ["./src/**/*.tsx"],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {},
  },
  variants: {
    extend: {},
  },
  plugins: [],
};
```

- In `src/main.tsx`

```tsx
import "./_tailwind.css";
```
