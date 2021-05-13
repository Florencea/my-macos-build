# Vite 使用筆記

- [Vite 使用筆記](#vite-使用筆記)
  - [相關文件](#相關文件)
  - [Vite](#vite)
  - [Tailwind CSS](#tailwind-css)
  - [Ant Design](#ant-design)

## 相關文件

- [Vite](https://cn.vitejs.dev/)
- [Tailwind CSS](https://tailwindcss.com/)
- [Ant Design](https://ant.design/index-cn)

## Vite

```bash
yarn create @vitejs/app vite-project --template react-ts
```

```bash
cd vite-project && yarn
```

- 在`vite.config.ts`的常用設定

```ts
import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [reactRefresh()],
  build: {
    // chunk 尺寸大於多少kb會跳警告，預設為 500
    chunkSizeWarningLimit: 500,
    rollupOptions: {
      output: {
        // 要不要把不同庫切到不同 chunk 去，這邊設定會把 antd 庫 分到同一個 chunk
        manualChunks: {
          antd: ["antd"],
        },
      },
    },
  },
  server: {
    // proxy 設定，把指定路徑轉到特定伺服器，開發常用
    proxy: {
      "/api": "http://localhost:4000/",
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

- 在`src/main.tsx`加入

```tsx
import "./_tailwind.css";
```

## Ant Design

```bash
yarn add antd @ant-design/icons
```

```bash
yarn add less vite-plugin-imp --dev
```

- 修改`vite.config.ts`

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
          // 按需載入
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
