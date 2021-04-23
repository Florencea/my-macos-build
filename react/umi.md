# Umi

## Docs

- [https://umijs.org/zh-CN/docs](https://umijs.org/zh-CN/docs)

## note

- 引用一般圖片要用
  - `require('./img')`(相對路徑)
  - `require('@/img')`(從 src 開始的路徑)
- 引用 svg 同一般模組
  - `import logoSrc from './logo.svg'`

## cli

```sh
# 注意 create umi app 是在目錄下發動而不是目錄外
mkdir myapp && cd myapp
yarn create @umijs/umi-app
# 修改 prettier 配置使根目錄文件也能被格式化
printf '.umi\n.umi-production\n.umi-test\ndist/\n' > .prettierignore
echo (jq 'setpath(["scripts","dev"];"umi dev") | setpath(["scripts","serve"];"serve dist")' package.json) > package.json
yarn add serve --dev
yarn prettier
# public 裡面要放東西，不然開發伺服器時會報錯，可以等有東西放的時候再建 public 目錄
mkdir public
code .
```

## config

- 配置文件[https://umijs.org/zh-CN/config](https://umijs.org/zh-CN/config)
- 編輯`.umirc.ts`，以下是常用配置

  ```ts
  {
    // 路由未匹配時的預設 title
    title: 'page title',
    // 是否讓生成的文件包含 hash 後綴，通常用於增量發布和避免瀏覽器加載緩存。
    hash: true,
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
    // 自動引入跟 TypeScript 提示需要 yarn add antd --dev
    antd: {},
  }
  ```

## 配合 ESLint

- 注意：下列 ESLint 規則可以全域預設不寫 `import React from 'react'`，若 VSCode 的自動引入功能一定要引入 React 才能作動的話，請把工作區的 `TypeScript` 版本升到 `4.3` 以上，才能配合 `React 17` 之後不用一直寫 `import React from 'react'` 的問題

```sh
# standard, react, browser
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
  "rules": {}
}
```

## 配合 Tailwind CSS

- 此種情形下`antd`樣式優先權依舊大於`Tailwind CSS`
- 安裝完需重開編輯器才會有 Tailwind CSS 語法提示

```sh
yarn add umi-plugin-tailwindcss --dev
```
