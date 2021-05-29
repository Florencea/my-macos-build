# Umi Note

- <https://umijs.org/>

## Umi + Ant Design + Tailwind

```bash
mkdir myapp && cd myapp
```

```bash
yarn create @umijs/umi-app
```

```bash
yarn add @ant-design/colors @ant-design/icons
```

```bash
yarn add antd umi-plugin-tailwindcss --dev
```

```bash
rm src/pages/index.tsx src/pages/index.less
```

```bash
mkdir -p src/models src/pages/protected/default src/pages/public/default
```

```bash
touch src/models/interface.ts src/access.ts src/util.ts src/app.tsx src/config.ts src/pages/protected/default/_Index.tsx src/pages/public/default/_Index.tsx
```

- `./src/models/interface.ts`

```ts
export interface InitialStateT {
  token?: string;
}

export interface AccessT {
  isLogin: boolean;
}
```

- `./src/access.ts`

```ts
import { InitialStateT, AccessT } from "./models/interface";

export default function (initialState: InitialStateT): AccessT {
  return {
    isLogin: initialState?.token !== undefined,
  };
}
```

- `./src/util.ts`

```ts
import { InitialStateT } from "./models/interface";

const STATE_KEY = "SITE_STATE";

const getSavedInitialState = (): InitialStateT | undefined => {
  const savedInitialState = window.localStorage.getItem(STATE_KEY);
  if (savedInitialState !== null) {
    return JSON.parse(savedInitialState);
  } else {
    return undefined;
  }
};

const setSavedInitialState = (initialState: InitialStateT) => {
  window.localStorage.setItem(STATE_KEY, JSON.stringify(initialState));
};

export const localStorageHelper = {
  get: {
    initialState: getSavedInitialState(),
  },
  set: {
    initialState: setSavedInitialState,
  },
  remove: {
    initialState: () => {
      window.localStorage.removeItem(STATE_KEY);
    },
  },
  clear: () => {
    window.localStorage.clear();
  },
};
```

- `./src/app.tsx`

```ts
import { BasicLayoutProps } from "@ant-design/pro-layout";
import { InitialStateT } from "./models/interface";
import { history } from "umi";
import {
  DEFAULT_PATH_PROTECTED,
  DEFAULT_PATH_PUBLIC,
  INITIALSTATE_DEFAULT,
  ROUTES_NEED_REDIRECT,
  TITLE,
} from "./config";
import { localStorageHelper } from "./util";

const isAccessRouteNeedRedirect = (path: string) =>
  new Set(ROUTES_NEED_REDIRECT).has(path);

export const layout = ({
  initialState,
}: {
  initialState: InitialStateT;
}): BasicLayoutProps => {
  const { token } = initialState;
  const isLogin = token !== undefined;
  return {
    title: TITLE,
    onPageChange: async () => {
      const { location } = history;
      // authorized user access protected routes
      if (isLogin && isAccessRouteNeedRedirect(location.pathname)) {
        history.push(DEFAULT_PATH_PROTECTED);
      }
      // unauthorized user access protected routes
      if (!isLogin && !isAccessRouteNeedRedirect(location.pathname)) {
        history.push(DEFAULT_PATH_PUBLIC);
      }
    },
  };
};

export async function getInitialState(): Promise<InitialStateT> {
  const savedInitialState = localStorageHelper.get.initialState;
  return savedInitialState !== undefined
    ? savedInitialState
    : INITIALSTATE_DEFAULT;
}
```

- `./src/config.ts`

```ts
import { InitialStateT } from "./models/interface";
import { gold, grey } from "@ant-design/colors";
/**
 * default state
 */
export const INITIALSTATE_DEFAULT: InitialStateT = {};
/**
 * theme
 */
export const THEME = {
  "primary-color": gold.primary,
  "layout-header-background": grey[7],
};
/**
 * routes
 */
export const TITLE = "page title";
export const DEFAULT_PATH_PUBLIC = "/public/default";
export const DEFAULT_PATH_PROTECTED = "/protected/default";

const basicRouteConfig = {
  headerRender: false,
};

const basicRouteConfigWithoutMenu = {
  hideInMenu: true,
  hideInBreadcrumb: true,
  menuRender: false,
  headerRender: false,
};

const protectedRoutes = [
  {
    path: DEFAULT_PATH_PROTECTED,
    name: "protected page",
    icon: "gift",
    access: "isLogin",
    component: "@/pages/protected/default/_Index",
    ...basicRouteConfig,
  },
];

const publicRoutes = [
  {
    path: DEFAULT_PATH_PUBLIC,
    name: "public page",
    component: "@/pages/public/default/_Index",
    ...basicRouteConfigWithoutMenu,
  },
];

export const ROUTES = [
  ...protectedRoutes,
  ...publicRoutes,
  { exact: false, path: "/", name: "", redirect: DEFAULT_PATH_PUBLIC },
];
export const ROUTES_NEED_REDIRECT = [DEFAULT_PATH_PUBLIC];
```

- `.umirc.ts`

```ts
import { THEME, ROUTES, TITLE } from "./src/config";
import { defineConfig } from "umi";

export default defineConfig({
  // dev config
  nodeModulesTransform: {
    type: "none",
  },
  fastRefresh: {},
  // proxy: {
  //   "/api": "http://localhost:4000/",
  //   "/api": {
  //     target: "https://localhost:4000/",
  //     changeOrigin: true,
  //     secure: false,
  //   },
  // },
  // devServer: {
  //   https: { key: "./cert/localhost.key", cert: "./cert/localhost.crt" },
  // },
  // site config
  // favicon: "/favicon.png",
  // route config
  title: TITLE,
  routes: ROUTES,
  history: { type: "hash" },
  // build config
  hash: true,
  // dynamicImport: {},
  dynamicImportSyntax: {},
  // build config for modern browser only
  // targets: {
  //   chrome: 89,
  //   firefox: 88,
  //   safari: 13,
  //   edge: false,
  //   ios: 13,
  // },
  // terserOptions: {
  //   parse: {
  //     ecma: 8,
  //   },
  //   compress: {
  //     ecma: 8,
  //   },
  //   ecma: 8,
  //   keep_classnames: false,
  //   keep_fnames: false,
  //   ie8: false,
  //   module: false,
  //   nameCache: null,
  //   safari10: false,
  //   toplevel: false,
  //   output: {
  //     ecma: 8,
  //     comments: false,
  //     ascii_only: true,
  //   },
  // },
  // antd config
  locale: {
    default: "zh-TW",
    antd: true,
    baseNavigator: true,
  },
  layout: {
    logo: null,
  },
  antd: {},
  theme: THEME,
});
```

- `./src/pages/protected/default/_Index.tsx`

```tsx
export default function Index() {
  return <span>protected default page</span>;
}
```

- `./src/pages/public/default/_Index.tsx`

```tsx
export default function Index() {
  return <span>public default page</span>;
}
```

## ESLint & Prettier

```bash
printf '.umi\n.umi-production\n.umi-test\ndist/\n' > .prettierignore
```

```bash
rm .editorconfig .prettierrc
```

- Use [ESLint Config Alloy TypeScript React](README.md#eslint-config-alloy-typescript-react)
