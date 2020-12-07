#! /bin/bash

function print_step() {
  printf "\E[1;36m"
  printf "\n + %s\n\n" "$1"
  printf "\E[0m"
}

function print_help() {
  printf "\nUsage: cra.sh my-app-name\n\n"
}
if [[ $# -eq 1 ]]; then
  APP_NAME=$1
  print_step "Execute Create React App"
  (
    set -x
    npx create-react-app "$APP_NAME" --template typescript
  )
  cd "$APP_NAME" || exit
  print_step "npm install Bootstrap, React Bootstrap, React Bootstrap Icons"
  (
    set -x
    npm install bootstrap
    npm install react-bootstrap --legacy-peer-deps
    npm install react-bootstrap-icons --legacy-peer-deps
  )
  print_step "npm install Node SASS, which need to compile, may take a while"
  (
    set -x
    npm install node-sass@4.14.1
  )
  print_step "npm install ESLint Plugins: React, JSX-a11y, Import, Promise"
  (
    set -x
    npm install eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise --save-dev
  )
  print_step "Execute Google gts"
  (
    set -x
    mv tsconfig.json tsconfig.old.json
    npx gts init
  )
  print_step "Remove conflict devlopment dependencies: typescript, @types/node"
  (
    set -x
    npm uninstall typescript @types/node --save-dev
    npm install typescript @types/node
  )
  print_step "Rewrite package.json"
  (
    set -x
    jq '.scripts.test = "react-scripts test --coverage --verbose"' <package.json >package2.json
    jq '.jest = {"collectCoverageFrom":["**/*.{ts,tsx}","!**/src/reportWebVitals.ts","!**/src/index.tsx","!**/src/react-app-env.d.ts"]}' <package2.json >package3.json
    rm package.json
    rm package2.json
    mv package3.json package.json
  )
  print_step "Rewrite tsconfig.json"
  (
    set -x
    echo '{"extends":"./node_modules/gts/tsconfig-google.json","compilerOptions":{"rootDir":".","outDir":"build","target":"es5","lib":["dom","dom.iterable","esnext"],"allowJs":true,"skipLibCheck":true,"esModuleInterop":true,"allowSyntheticDefaultImports":true,"strict":true,"forceConsistentCasingInFileNames":true,"noFallthroughCasesInSwitch":true,"module":"esnext","moduleResolution":"node","resolveJsonModule":true,"isolatedModules":true,"noEmit":true,"jsx":"react-jsx"},"include":["src"]}' >tsconfig.json
    rm tsconfig.old.json
  )
  print_step "Rewrite eslintrc.json"
  (
    set -x
    echo '{"extends":["./node_modules/gts/","plugin:react/recommended","plugin:jsx-a11y/recommended","plugin:import/errors","plugin:import/warnings","plugin:import/typescript","plugin:promise/recommended"],"env":{"browser":true,"jest":true},"plugins":["react","jsx-a11y","import","promise"],"settings":{"react":{"version":"detect"}}}' >.eslintrc2.json
    rm .eslintrc.json
    mv .eslintrc2.json .eslintrc.json
  )
  print_step "Add src/bootstrap-custom.css and import to src/App.tsx"
  (
    set -x
    printf "\$theme-colors: (\n  \"custom-color\": #900,\n);\n\n@import \"../node_modules/bootstrap/scss/bootstrap\";\n" >>src/bootstrap-custom.scss
    awk '/logo.svg/ { print; print "import '\''./bootstrap-custom.scss'\'';"; next }1' src/App.tsx >src/App2.tsx
    rm src/App.tsx
    mv src/App2.tsx src/App.tsx
  )
  print_step "Rewrite reportWebVitals.ts"
  (
    set -x
    mv src/reportWebVitals.ts src/reportWebVitals.old.ts
    echo 'import { ReportHandler } from "web-vitals";const reportWebVitals = (onPerfEntry?: ReportHandler) => { if (onPerfEntry && onPerfEntry instanceof Function) { import("web-vitals") .then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => { getCLS(onPerfEntry); getFID(onPerfEntry); getFCP(onPerfEntry); getLCP(onPerfEntry); getTTFB(onPerfEntry); return; }) .catch((err) => { console.error(err); }); } };export default reportWebVitals;' >>src/reportWebVitals.ts
    rm src/reportWebVitals.old.ts
  )
  print_step "Run npm fix to fix all styles"
  (
    set -x
    npm run fix
  )
  print_step "Add commit for modefied files"
  (
    set -x
    git add ./*
    git add ./.*
    git commit -m "init: Initialize project using customized Create React App script"
  )
  print_step "All done. Open VSCode for $APP_NAME"
  (
    set -x
    code ./src/App.tsx
  )
else
  print_help
fi
