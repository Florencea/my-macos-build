#! /bin/bash

function print_step() {
  printf "\E[1;31m"
  printf " + "
  printf "\E[0m"
  printf "%s\n" "$1"
}

function print_help() {
  printf "\nUsage: crat.sh my-app-name\n\n"
}
if [[ $# -eq 1 ]]; then
  APP_NAME=$1
  printf "\E[1;31m"
  printf "\n + Create React App Custom Script with Tailwind CSS\n\n"
  printf "\E[0m"
  print_step "Run Create React App"
  (
    # yarn create react-app "$APP_NAME" --template typescript &>/dev/null
    yarn create react-app "$APP_NAME" --template typescript
  )
  cd "$APP_NAME" || exit
  print_step "Add Tailwind CSS, FontAwesome"
  (
    # yarn add tailwindcss@npm:@tailwindcss/postcss7-compat postcss@^7 autoprefixer@^9 @craco/craco @fortawesome/fontawesome-free &>/dev/null
    yarn add tailwindcss@npm:@tailwindcss/postcss7-compat postcss@^7 autoprefixer@^9 @craco/craco @fortawesome/fontawesome-free
  )
  print_step "Add ESLint Plugins: React, JSX-a11y, Import, Promise, Node, Prettier"
  (
    # yarn add eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise eslint-plugin-node eslint-plugin-prettier --dev &>/dev/null
    yarn add eslint-plugin-react eslint-plugin-jsx-a11y eslint-plugin-import eslint-plugin-promise eslint-plugin-node eslint-plugin-prettier --dev
  )
  print_step "Run Google gts"
  (
    # npx gts init -y --yarn &>/dev/null
    npx gts init -y --yarn
  )
  print_step "Create Tailwind configuration"
  (
    # tailwind.config.js
    # npx -y tailwindcss init &>/dev/null
    npx -y tailwindcss init
    # craco.config.js
    echo 'module.exports = { style: { postcss: { plugins: [require("tailwindcss"), require("autoprefixer")], }, }, };' >>craco.config.js
  )
  print_step "Customize configurations"
  (
    # package.json
    jq '.scripts.start = "craco start"' <package.json >package2.json
    jq '.scripts.build = "craco build"' <package2.json >package3.json
    jq '.scripts.test = "craco test --coverage --verbose"' <package3.json >package4.json
    jq '.jest = {"collectCoverageFrom":["**/*.{ts,tsx}","!**/src/reportWebVitals.ts","!**/src/index.tsx","!**/src/react-app-env.d.ts"]}' <package4.json >package5.json
    rm package.json
    rm package2.json
    rm package3.json
    rm package4.json
    mv package5.json package.json
    # tsconfig.json
    echo '{"extends":"./node_modules/gts/tsconfig-google.json","compilerOptions":{"rootDir":".","outDir":"build","target":"es5","lib":["dom","dom.iterable","esnext"],"allowJs":true,"skipLibCheck":true,"esModuleInterop":true,"allowSyntheticDefaultImports":true,"strict":true,"forceConsistentCasingInFileNames":true,"noFallthroughCasesInSwitch":true,"module":"esnext","moduleResolution":"node","resolveJsonModule":true,"isolatedModules":true,"noEmit":true,"jsx":"react-jsx"},"include":["src"]}' >tsconfig.json
    # eslintrc.json
    echo '{"extends":["./node_modules/gts/","plugin:react/recommended","plugin:jsx-a11y/recommended","plugin:import/errors","plugin:import/warnings","plugin:import/typescript","plugin:promise/recommended"],"env":{"browser":true,"jest":true},"plugins":["react","jsx-a11y","import","promise"],"settings":{"react":{"version":"detect"}}}' >.eslintrc2.json
    rm .eslintrc.json
    mv .eslintrc2.json .eslintrc.json
    # src/reportWebVitals.ts
    mv src/reportWebVitals.ts src/reportWebVitals.old.ts
    echo 'import { ReportHandler } from "web-vitals";const reportWebVitals = (onPerfEntry?: ReportHandler) => { if (onPerfEntry && onPerfEntry instanceof Function) { import("web-vitals") .then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => { getCLS(onPerfEntry); getFID(onPerfEntry); getFCP(onPerfEntry); getLCP(onPerfEntry); getTTFB(onPerfEntry); return; }) .catch((err) => { console.error(err); }); } };export default reportWebVitals;' >>src/reportWebVitals.ts
    rm src/reportWebVitals.old.ts
    # .gitignore
    printf "\n# lint\n.eslintcache\n" >>.gitignore
    # tailwind.config.js
    mv tailwind.config.js tailwind.config.old.js
    echo 'module.exports = { purge: ["./src/**/*.js", "./public/index.html"], darkMode: false, theme: { extend: {}, }, variants: {}, plugins: [], };' >tailwind.config.js
    rm tailwind.config.old.js
    # src/index.css
    mv src/index.css src/index.old.css
    printf "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n" >src/index.css
    rm src/index.old.css
    # src/App.tsx
    awk '/logo.svg/ { print; print "import '\''@fortawesome/fontawesome-free/css/all.min.css'\'';"; next }1' src/App.tsx >src/App2.tsx
    rm src/App.tsx
    mv src/App2.tsx src/App.tsx
  )
  print_step "Remove conflicts: typescript, @types/node"
  (
    # yarn remove typescript @types/node --dev &>/dev/null
    yarn remove typescript @types/node --dev
    # yarn add typescript @types/node --dev &>/dev/null
    yarn add typescript @types/node --dev
  )
  print_step "Run yarn fix"
  (
    # yarn fix &>/dev/null
    yarn fix
  )
  print_step "Commit modefied files"
  (
    git config advice.addIgnoredFile false
    git add ./.gitignore &>/dev/null
    git add ./* &>/dev/null
    git add ./.eslintignore &>/dev/null
    git add ./.eslintrc.json &>/dev/null
    git add ./.prettierrc.js &>/dev/null
    git commit -q -m "init: Initialize project using customized Create React App script" &>/dev/null
  )
  print_step "Done."
  (
    code -n .
  )
else
  print_help
fi
