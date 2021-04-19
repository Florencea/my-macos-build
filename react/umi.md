# Umi

## Docs

- [https://umijs.org/zh-CN/docs](https://umijs.org/zh-CN/docs)

## note

- Umi 支援 LTS 版的 Node.js，若使用最新版會跳警告
- Umi 相當於帶路由版、對 Antd 友好的 CRA，不像 Next.js 連 API 跟 SSR 都包進去了
- 引用一般圖片要用`require('./img')`(相對路徑)或`require('@/img')`(從 src 開始的路徑)
- 引用 svg 同一般模組`import logoSrc from ''./logo.svg`

## cli

```sh
# 注意 create umi app 是在目錄下發動而不是目錄外
mkdir myapp && cd myapp
yarn create @umijs/umi-app
mv tsconfig.json tsconfig_old.json
npx gts init -y --yarn
mv package.json package_old.json
cat package_old.json | jq 'delpaths([["scripts","lint"],["scripts","clean"],["scripts","complie"],["scripts","fix"],["scripts","prepare"],["scripts","pretest"],["scripts","posttest"]])' | jq 'setpath(["scripts","dev"];"umi dev")' > package.json
rm package_old.json
jq 'setpath(["extends"];"./node_modules/gts/tsconfig-google.json")' tsconfig_old.json > tsconfig.json
rm tsconfig_old.json src/index.ts
mkdir public
code .
```

## config

- 編輯`.umirc.ts`，以下是通常需要加進去的東西

  ```ts
  {
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
    antd: {},
  }
  ```

## 配合 TailwindCSS

```sh
yarn add umi-plugin-tailwindcss --dev
```
