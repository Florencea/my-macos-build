# Umi.js 使用筆記

- [Umi.js 使用筆記](#umijs-使用筆記)
  - [框架相關文件](#框架相關文件)
  - [命令列建立專案](#命令列建立專案)
  - [配置文件說明](#配置文件說明)
  - [配合 ESLint、Prettier](#配合-eslintprettier)
  - [配合 Tailwind CSS](#配合-tailwind-css)
  - [配合 Ant Design](#配合-ant-design)
  - [靜態資源引用](#靜態資源引用)
  - [其他注意事項](#其他注意事項)

## 框架相關文件

- [https://umijs.org/zh-CN/docs](https://umijs.org/zh-CN/docs)

## 命令列建立專案

```sh
# 注意 create umi app 是在目錄下發動而不是目錄外
mkdir myapp && cd myapp
yarn create @umijs/umi-app
# 加入 yarn dev 與 yarn serve 命令
echo (jq 'setpath(["scripts","dev"];"umi dev") | setpath(["scripts","serve"];"serve -s dist")' package.json) > package.json
yarn add serve --dev
```

## 配置文件說明

- 配置文件 [https://umijs.org/zh-CN/config](https://umijs.org/zh-CN/config)
- 編輯`.umirc.ts`，以下是常用配置

  ```ts
  {
    // 路由未匹配時的預設 title
    title: 'page title',
    // 是否讓生成的文件包含 hash 後綴，通常用於增量發布和避免瀏覽器加載緩存。
    hash: true,
    // 配置 favicon 地址，請放到 public 目錄
    favicon: '/favicon.ico'
    // 開發時的 proxy server 配置
    proxy: {
      // 需轉址的寫法
      '/api': {
        'target': 'http://jsonplaceholder.typicode.com/',
        'changeOrigin': true,
        'pathRewrite': { '^/api' : '' },
      },
      // 簡單寫法
      '/api': 'http://localhost:4000/',
    },
  }
  ```

## 配合 ESLint、Prettier

- 直接[使用 alloy 配置](README.md#alloy-typescript-react)

```bash
# 修改 .prettierignore 使根目錄文件也能被格式化
printf '.umi\n.umi-production\n.umi-test\ndist/\n' > .prettierignore
# 刪除原本的 .editorconfig .prettierrc
rm .editorconfig .prettierrc
# 參見文件，使用 alloy 配置
```

## 配合 Tailwind CSS

- 此種情形下`antd`樣式優先權依舊大於`Tailwind CSS`
- 安裝完需重開 VSCode 才會有 Tailwind CSS 語法提示

```sh
yarn add umi-plugin-tailwindcss --dev
```

## 配合 Ant Design

- 在`.umirc.ts`加入

```js
{
  antd: {},
}
```

- VSCode 自動引入跟 TypeScript 提示需要

```bash
yarn add antd --dev
```

## 靜態資源引用

- 引用一般圖片要用
  - `require('./img')`(相對路徑)
  - `require('@/img')`(從 src 開始的路徑)
- 引用 svg 同一般模組
  - `import logoSrc from './logo.svg'`

## 其他注意事項

- 強烈建議不要亂改目錄名稱
- 若編譯輸出目錄有更改(不是`dist`了)，記得檢查`.gitignore`、`.prettierignore`、`tsconfig.json`(可能有遺漏，建議不要改)
- 建議把`.gitignore`中的`yarn.lock`跟`package-lock.json`移除以鎖定套件版本
