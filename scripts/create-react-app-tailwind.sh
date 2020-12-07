#! /bin/bash

function print_step() {
  printf "\E[1;36m"
  printf " +-> "
  printf "\E[0m"
  printf "%s\n" "$1"
}

function print_help() {
  printf "\nUsage: crat.sh my-app-name\n\n"
}
if [[ $# -eq 1 ]]; then
  APP_NAME=$1
  print_step "Run Create React App"
  (
    # set -x
    npx create-react-app "$APP_NAME" --template typescript &>/dev/null
  )
  cd "$APP_NAME" || exit
  print_step "Install Tailwind CSS, FontAwesome"
  (
    # set -x
    npm install tailwindcss@npm:@tailwindcss/postcss7-compat postcss@^7 autoprefixer@^9 @craco/craco @fortawesome/fontawesome-free &>/dev/null
  )
  print_step "Install ESLint Plugins: React, JSX-a11y, Import, Promise"
  (
    # set -x
    npm install eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise --save-dev &>/dev/null
  )
  print_step "Run Google gts"
  (
    # set -x
    mv tsconfig.json tsconfig.old.json
    npx gts init &>/dev/null
  )
  print_step "Remove conflict devlopment dependencies: typescript, @types/node"
  (
    # set -x
    npm uninstall typescript @types/node --save-dev &>/dev/null
    npm install typescript @types/node &>/dev/null
  )
  print_step "Create Tailwind configuration file"
  (
    # set x
    npx tailwindcss init &>/dev/null
  )
  print_step "Rewrite package.json, tsconfig.json, eslintrc.json, reportWebVitals.ts. .gitignore, tailwind.config.js, index.css"
  (
    # set -x
    jq '.scripts.start = "craco start"' <package.json >package2.json
    jq '.scripts.build = "craco build"' <package2.json >package3.json
    jq '.scripts.test = "craco test --coverage --verbose"' <package3.json >package4.json
    jq '.jest = {"collectCoverageFrom":["**/*.{ts,tsx}","!**/src/reportWebVitals.ts","!**/src/index.tsx","!**/src/react-app-env.d.ts"]}' <package4.json >package5.json
    rm package.json
    rm package2.json
    rm package3.json
    rm package4.json
    mv package5.json package.json
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
  (
    # set -x
    mv tailwind.config.js tailwind.config.old.js
    echo 'module.exports = { purge: ["./src/**/*.js", "./public/index.html"], darkMode: false, theme: { extend: {}, }, variants: {}, plugins: [], };' >tailwind.config.js
    rm tailwind.config.old.js
  )
  (
    # set -x
    mv src/index.css src/index.old.css
    printf "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n" >src/index.css
    rm src/index.old.css
  )
  print_step "Add FontAwesome to src/App.tsx"
  (
    # set -x
    awk '/logo.svg/ { print; print "import '\''@fortawesome/fontawesome-free/css/all.min.css'\'';"; next }1' src/App.tsx >src/App2.tsx
    rm src/App.tsx
    mv src/App2.tsx src/App.tsx
  )
  print_step "Create craco.config.js"
  (
    # set -x
    echo 'module.exports = { style: { postcss: { plugins: [require("tailwindcss"), require("autoprefixer")], }, }, };' >>craco.config.js
  )
  print_step "Run npm fix"
  (
    # set -x
    npm run fix &>/dev/null
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
