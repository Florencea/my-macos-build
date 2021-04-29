# Umi.js 使用筆記

- [Umi.js 使用筆記](#umijs-使用筆記)
  - [框架相關文件](#框架相關文件)
  - [命令列建立專案](#命令列建立專案)
  - [靜態資源引用](#靜態資源引用)
  - [配置文件說明](#配置文件說明)
  - [配合 ESLint](#配合-eslint)
  - [配合 Tailwind CSS](#配合-tailwind-css)
  - [其他注意事項](#其他注意事項)

## 框架相關文件

- [https://umijs.org/zh-CN/docs](https://umijs.org/zh-CN/docs)

## 命令列建立專案

```sh
# 注意 create umi app 是在目錄下發動而不是目錄外
mkdir myapp && cd myapp
yarn create @umijs/umi-app
# 修改 prettier 配置使根目錄文件也能被格式化
printf '.umi\n.umi-production\n.umi-test\ndist/\n' > .prettierignore
# 加入 yarn dev 與 yarn serve 命令
# 移除 prettier 相關指令，會與 VSCode 內的規則起衝突
echo (jq 'setpath(["scripts","dev"];"umi dev") | setpath(["scripts","serve"];"serve dist") | delpaths([["gitHooks"],["lint-staged"],["script","prettier"]])' package.json) > package.json
# 設定 trailingComma: none ，防止 prettier 與 eslint 起衝突
echo (jq 'setpath(["trailingComma"];"none")' .prettierrc) > .prettierrc
yarn add serve --dev
# public 裡面要放東西，不然開發伺服器時會報錯，可以等有東西放的時候再建 public 目錄
mkdir public
code .
```

## 靜態資源引用

- 引用一般圖片要用
  - `require('./img')`(相對路徑)
  - `require('@/img')`(從 src 開始的路徑)
- 引用 svg 同一般模組
  - `import logoSrc from './logo.svg'`

## 配置文件說明

- 配置文件 [https://umijs.org/zh-CN/config](https://umijs.org/zh-CN/config)
- 編輯`.umirc.ts`，以下是常用配置

  ```ts
  {
    // 路由未匹配時的預設 title
    title: 'page title',
    // 是否讓生成的文件包含 hash 後綴，通常用於增量發布和避免瀏覽器加載緩存。
    hash: true,
    // 編譯輸出目錄，預設是 'dist'，記得改了這個要去改 .pretieerignore 跟 .gitignore ，不然目錄裡的東西會被影響到
    outputPath: 'dist',
    // 配置 favicon 地址，請放到 public 目錄，編譯後才看得到，開發中看不到 favicon
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
      '/api': 'http://localhost:4000/api',
    },
    // 要用 antd 只要從這邊打開就夠了
    // VSCode自動引入跟 TypeScript 提示需要 yarn add antd --dev
    antd: {},
  }
  ```

## 配合 ESLint

- 注意：下列 ESLint 規則可以全域預設不寫 `import React from 'react'`，若 VSCode 的自動引入功能得引入 React 才生效，請把工作區的 `TypeScript` 版本升到 `4.3` 以上，就能配合 `React 17` 之後不用一直寫 `import React from 'react'`
- 規則`multiline-ternary: 0`以防`prettier`與`eslint`格式化三元運算式產生衝突

```sh
# 使用 standard, react, browser
yarn add eslint eslint-plugin-react@latest @typescript-eslint/eslint-plugin@latest eslint-config-standard@latest eslint@^7.12.1 eslint-plugin-import@^2.22.1 eslint-plugin-node@^11.1.0 eslint-plugin-promise@^4.2.1 @typescript-eslint/parser@latest --dev
```

- `.eslintrc.json`

```json
{
  "env": {
    "browser": true,
    "es2021": true
  },
  "extends": ["plugin:react/recommended", "standard"],
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "ecmaFeatures": {
      "jsx": true
    },
    "ecmaVersion": 12,
    "sourceType": "module"
  },
  "plugins": ["react", "@typescript-eslint"],
  "globals": { "React": true },
  "rules": {
    "multiline-ternary": 0
  }
}
```

## 配合 Tailwind CSS

- 此種情形下`antd`樣式優先權依舊大於`Tailwind CSS`
- 安裝完需重開 VSCode 才會有 Tailwind CSS 語法提示

```sh
yarn add umi-plugin-tailwindcss --dev
```

## 其他注意事項

- 記得反覆檢查
  - `.gitignore`，編譯目錄需要加進去，還有建議把`yarn.lock`跟`package-lock.json`移除以鎖定套件版本
  - `.prettierignore`，編譯目錄需要移除
  - `.prettierrc`，`trailingComma`改為`none`，防止與`eslint`起衝突
