#! /bin/bash

function print_step() {
  printf "\E[1;36m"
  printf " +--> "
  printf "\E[0m"
  printf "%s\n" "$1"
}

function print_help() {
  printf "\nUsage: cra.sh my-app-name\n\n"
}
if [[ $# -eq 1 ]]; then
  APP_NAME=$1
  printf "\E[1;36m"
  printf "\n <-+ Create React App Custom Script with Bootstrap +-->\n\n"
  printf "\E[0m"
  print_step "Run Create React App"
  (
    # set -x
    yarn create react-app "$APP_NAME" --template typescript &>/dev/null
  )
  cd "$APP_NAME" || exit
  print_step "Install Bootstrap, Reactstrap, FontAwesome"
  (
    # set -x
    yarn add bootstrap reactstrap @fortawesome/fontawesome-free &>/dev/null
  )
  print_step "Install Node SASS, which need to compile, may take a while"
  (
    # set -x
    yarn add node-sass@4.14.1 &>/dev/null
  )
  print_step "Install ESLint Plugins: React, JSX-a11y, Import, Promise, Node, Prettier"
  (
    # set -x
    yarn add eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise eslint-plugin-node eslint-plugin-prettier --dev &>/dev/null
  )
  print_step "Run Google gts"
  (
    # set -x
    mv tsconfig.json tsconfig.old.json
    npx -y gts init --yarn &>/dev/null
  )
  print_step "Rewrite package.json, tsconfig.json, eslintrc.json, reportWebVitals.ts. .gitignore"
  (
    # set -x
    jq '.scripts.test = "react-scripts test --coverage --verbose"' <package.json >package2.json
    jq '.jest = {"collectCoverageFrom":["**/*.{ts,tsx}","!**/src/reportWebVitals.ts","!**/src/index.tsx","!**/src/react-app-env.d.ts"]}' <package2.json >package3.json
    rm package.json
    rm package2.json
    mv package3.json package.json
  )
  (
    # set -x
    echo '{"extends":"./node_modules/gts/tsconfig-google.json","compilerOptions":{"rootDir":".","outDir":"build","target":"es5","lib":["dom","dom.iterable","esnext"],"allowJs":true,"skipLibCheck":true,"esModuleInterop":true,"allowSyntheticDefaultImports":true,"strict":true,"forceConsistentCasingInFileNames":true,"noFallthroughCasesInSwitch":true,"module":"esnext","moduleResolution":"node","resolveJsonModule":true,"isolatedModules":true,"noEmit":true,"jsx":"react-jsx"},"include":["src"]}' >tsconfig.json
    rm tsconfig.old.json
  )
  (
    # set -x
    echo '{"extends":["./node_modules/gts/","plugin:react/recommended","plugin:jsx-a11y/recommended","plugin:import/errors","plugin:import/warnings","plugin:import/typescript","plugin:promise/recommended"],"env":{"browser":true,"jest":true},"plugins":["react","jsx-a11y","import","promise"],"settings":{"react":{"version":"detect"}}}' >.eslintrc2.json
    rm .eslintrc.json
    mv .eslintrc2.json .eslintrc.json
  )
  (
    # set -x
    mv src/reportWebVitals.ts src/reportWebVitals.old.ts
    echo 'import { ReportHandler } from "web-vitals";const reportWebVitals = (onPerfEntry?: ReportHandler) => { if (onPerfEntry && onPerfEntry instanceof Function) { import("web-vitals") .then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => { getCLS(onPerfEntry); getFID(onPerfEntry); getFCP(onPerfEntry); getLCP(onPerfEntry); getTTFB(onPerfEntry); return; }) .catch((err) => { console.error(err); }); } };export default reportWebVitals;' >>src/reportWebVitals.ts
    rm src/reportWebVitals.old.ts
  )
  (
    # set -x
    printf "\n# lint\n.eslintcache\n" >>.gitignore
  )
  print_step "Remove conflict devlopment dependencies: typescript, @types/node"
  (
    # set -x
    yarn remove typescript @types/node --dev &>/dev/null
    yarn add typescript @types/node --dev &>/dev/null
  )
  print_step "Add FontAwesome, src/bootstrap-custom.css and import to src/App.tsx"
  (
    # set -x
    printf "\$theme-colors: (\n  \"custom-color\": #900,\n);\n\n@import \"../node_modules/bootstrap/scss/bootstrap\";\n" >>src/bootstrap-custom.scss
    awk '/logo.svg/ { print; print "import '\''@fortawesome/fontawesome-free/css/all.min.css'\'';"; next }1' src/App.tsx >src/App2.tsx
    awk '/logo.svg/ { print; print "import '\''./bootstrap-custom.scss'\'';"; next }1' src/App2.tsx >src/App3.tsx
    rm src/App.tsx
    rm src/App2.tsx
    mv src/App3.tsx src/App.tsx
  )
  print_step "Run yarn fix"
  (
    # set -x
    yarn fix &>/dev/null
  )
  print_step "Add commit for modefied files"
  (
    # set -x
    git config advice.addIgnoredFile false
    git add ./.gitignore
    git add ./*
    git add ./.eslintignore
    git add ./.eslintrc.json
    git add ./.prettierrc.js
    git commit -q -m "init: Initialize project using customized Create React App script"
  )
  print_step "Open VSCode for $APP_NAME"
  (
    # set -x
    code -n .
  )
else
  print_help
fi
