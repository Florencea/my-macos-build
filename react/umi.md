# UmiJS 開發筆記

- <https://umijs.org/zh-CN/docs>

## 注意事項

- 與 Tailwind 配合使用時，要注意 Antd 的 CSS 優先權較高
  - 老實說這樣也是正常，若 Tailwind 預設樣式覆蓋 Antd 組件，外觀會變得亂七八糟
- 開發時，盡可能把型別與使用型別的程式碼放一起，記住，型別只是輔助開發，別讓型別定義成為開發累贅
- 只有在需要儲存前端狀態的場景，才需要從`model`導出`data`，也可以讓`model`裡的 API 函數直接回傳資料，不要在初始化上面下功夫
- Umi + Antd + Antd Icon + Ahooks 是非常穩定的組合，盡可能使用螞蟻金服系列的 React 生態系，比較不容易出 Bug
- 新特性如 mfsu、Webpack 5 等到預設啟用的時候再開，bug 很多
- 內建的國際化必須要刷新畫面才有用，與其使用 setLocale 不如直接改 localstorage 的 `umi_locale`

## Umi + Ant Design + Tailwind + ESLint & Prettier

- 可適應一般使用 token 登入機制的後台開發狀況

```bash
mkdir myapp && cd myapp
```

```bash
yarn create @umijs/umi-app
```

```bash
yarn add \
@ant-design/colors \
@ant-design/icons \
ahooks
```

```bash
yarn add \
antd \
tailwindcss@latest \
@tailwindcss/postcss7-compat \
umi-plugin-tailwindcss \
eslint \
typescript \
@typescript-eslint/parser \
@typescript-eslint/eslint-plugin \
eslint-plugin-react \
eslint-config-alloy \
--dev
```

```bash
rm \
src/pages/index.tsx \
src/pages/index.less \
.editorconfig \
.prettierrc \
README.md
```

```bash
printf '.umi\n.umi-production\n.umi-test\ndist/\n' > .prettierignore
```

```bash
mkdir -p \
.vscode \
public \
src/models \
src/components \
src/configs \
src/utils \
src/pages/private/Welcome \
src/pages/private/Logout \
src/pages/public/Login
```

```bash
touch \
.eslintrc.js \
.prettierrc.js \
.vscode/settings.json \
mock/api.ts \
public/robots.txt \
src/access.ts \
src/app.tsx \
src/global.less \
src/components/PageFrame.tsx \
src/configs/api.ts \
src/configs/routes.ts \
src/configs/theme.ts \
src/models/auth.ts \
src/pages/private/Welcome/Welcome.tsx \
src/pages/private/Logout/Logout.tsx \
src/pages/public/Login/Login.tsx \
src/utils/api.ts \
src/utils/storage.ts
```

```bash
code .
```

- `.eslintrc.js`

```js
module.exports = {
  extends: ["alloy", "alloy/react", "alloy/typescript"],
  env: {
    // 你的環境變量（包含多個預定義的全局變量）
    //
    browser: true,
    // node: true,
    // mocha: true,
    // jest: true,
    // jquery: true
  },
  globals: {
    // 你的全局變量（設置為 false 表示它不允許被重新賦值）
    //
    // myGlobal: false
    React: true,
  },
  rules: {
    // 自定義你的規則
  },
};
```

- `.prettierrc.js`

```js
module.exports = {
  // 一行最多 120 字符
  printWidth: 120,
  // 使用 2 個空格縮進
  tabWidth: 2,
  // 不使用縮進符，而使用空格
  useTabs: false,
  // 行尾需要有分號
  semi: true,
  // 使用單引號
  singleQuote: true,
  // 對象的 key 僅在必要時用引號
  quoteProps: "as-needed",
  // jsx 不使用單引號，而使用雙引號
  jsxSingleQuote: false,
  // 末尾需要有逗號
  trailingComma: "all",
  // 大括號內的首尾需要空格
  bracketSpacing: true,
  // jsx 標簽的反尖括號需要換行
  jsxBracketSameLine: false,
  // 箭頭函數，只有一個參數的時候，也需要括號
  arrowParens: "always",
  // 每個文件格式化的范圍是文件的全部內容
  rangeStart: 0,
  rangeEnd: Infinity,
  // 不需要寫文件開頭的 @prettier
  requirePragma: false,
  // 不需要自動在文件開頭插入 @prettier
  insertPragma: false,
  // 使用默認的折行標准
  proseWrap: "preserve",
  // 根據顯示樣式決定 html 要不要折行
  htmlWhitespaceSensitivity: "css",
  // vue 文件中的 script 和 style 內不用縮進
  vueIndentScriptAndStyle: false,
  // 換行符使用 lf
  endOfLine: "lf",
  // 格式化嵌入的內容
  embeddedLanguageFormatting: "auto",
};
```

- `.vscode/settings.json`

```jsonc
{
  // Typescript
  "typescript.tsdk": "node_modules/typescript/lib",
  // TailWindCSS
  "css.validate": false,
  "editor.quickSuggestions": {
    "strings": true
  },
  "tailwindCSS.emmetCompletions": true,
  "tailwindCSS.includeLanguages": {
    "plaintext": "html"
  },
  // ESLint
  "eslint.validate": [
    "javascript",
    "javascriptreact",
    "vue",
    "typescript",
    "typescriptreact"
  ],
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  // Prettier
  "files.eol": "\n",
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  // Shell Script
  "[shellscript]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  },
  // Markdown
  "markdownlint.config": {
    "MD033": false
  }
}
```

- `.gitignore`

```text
# See https://help.github.com/articles/ignoring-files/ for more about ignoring files.

# dependencies
/node_modules
/npm-debug.log*
/yarn-error.log
/package-lock.json

# production
/dist

# misc
.DS_Store

# umi
/src/.umi
/src/.umi-production
/src/.umi-test
/.env.local
```

- `.umirc.ts`

```ts
import { routes, TITLE } from "./src/configs/routes";
import { theme } from "./src/configs/theme";
import { defineConfig } from "umi";

export default defineConfig({
  // dev config
  nodeModulesTransform: {
    type: "none",
  },
  fastRefresh: {},
  proxy: {
    // '/api': 'http://localhost:4000/',
    // "/api": {
    //   target: "https://localhost:4000/",
    //   changeOrigin: true,
    //   secure: false,
    // },
  },
  // devServer: {
  //   https: { key: "./cert/localhost.key", cert: "./cert/localhost.crt" },
  // },
  // site config
  // favicon: '/favicon.png',
  // route config
  title: TITLE,
  routes,
  history: { type: "hash" },
  // build config
  hash: true,
  ignoreMomentLocale: true,
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
  theme,
});
```

- `package.json`

```json
{
  "scripts": {
    "dev": "umi dev"
  }
}
```

- `mock/api.ts`

```ts
const user = {
  account: "test",
  password: "test",
};

const success = {
  success: true,
  data: {
    token: "fake_token",
  },
};

const failed = {
  success: false,
  errorCode: "401",
  errorMessage: "帳號或密碼錯誤",
  showType: 2,
};

export default {
  "POST /api/login": (req: any, res: any) => {
    const { account, password } = req.body;
    if (account === user.account && password === user.password) {
      res.json(success);
    } else {
      res.status(401).json(failed);
    }
  },
  "POST /api/logout": { success: true },
};
```

- `public/robots.txt`

```text
# https://www.robotstxt.org/robotstxt.html
User-agent: *
Disallow:
```

- `src/components/PageFrame.tsx`

```tsx
import { getPageTitle } from "@/configs/routes";
import { Col, Empty, PageHeader, PageHeaderProps, Row } from "antd";
import { useMemo } from "react";
import { history } from "umi";

interface Props {
  pageHeaderProps?: Partial<PageHeaderProps>;
  children?: React.ReactNode;
}

export default ({ pageHeaderProps, children }: Props) => {
  const TITLE = useMemo(
    () => getPageTitle(history.location.pathname),
    [history.location.pathname]
  );
  return (
    <Row className="h-screen">
      <Col className="p-3" span={24}>
        <PageHeader ghost={false} title={TITLE} {...pageHeaderProps} />
        <div className="mt-3">
          {children ?? (
            <Empty
              className="pt-20"
              image={Empty.PRESENTED_IMAGE_SIMPLE}
              description="頁面建造中"
            />
          )}
        </div>
      </Col>
    </Row>
  );
};
```

- `src/configs/api.ts`

```ts
export const prefix = "/api";

export const api = {
  auth: {
    login: "/login",
    logout: "/logout",
  },
};
```

- `src/configs/routes.ts`

```ts
import { Route } from "@ant-design/pro-layout/lib/typings";

export const DEFAULT_PATH_PUBLIC = "/login";
export const DEFAULT_PATH_PRIVATE = "/welcome";
export const TITLE = "myapp";

const basicRouteConfig: Route = {
  hideInBreadcrumb: true,
  headerRender: false,
};

const basicRouteConfigWithoutMenu: Route = {
  ...basicRouteConfig,
  hideInMenu: true,
  menuRender: false,
};

const privateRoutes: Route[] = [
  {
    ...basicRouteConfig,
    path: DEFAULT_PATH_PRIVATE,
    name: "歡迎",
    icon: "Smile",
    access: "isLogin",
    component: "@/pages/private/Welcome/Welcome",
  },
  {
    ...basicRouteConfig,
    path: "/logout",
    name: "登出",
    icon: "Logout",
    access: "isLogin",
    component: "@/pages/private/Logout/Logout",
  },
];

const publicRoutes: Route[] = [
  {
    ...basicRouteConfigWithoutMenu,
    path: DEFAULT_PATH_PUBLIC,
    component: "@/pages/public/Login/Login",
  },
];

export const ROUTES_NEED_REDIRECT = [DEFAULT_PATH_PUBLIC];

export const routes: Route[] = [
  ...privateRoutes,
  ...publicRoutes,
  { exact: false, path: "/", name: "", redirect: DEFAULT_PATH_PUBLIC },
];

export const getPageTitle = (currentPath: string) =>
  routes.find((r) => r.path === currentPath)?.name ?? "";
```

- `src/configs/theme.ts`

```ts
import { grey, purple } from "@ant-design/colors";

export const theme = {
  "primary-color": purple[4],
  "layout-header-background": grey[7],
};
```

- `src/models/auth.ts`

```ts
import { api } from "@/configs/api";
import { useApi } from "@/utils/api";
import { storage } from "@/utils/storage";
import { useBoolean } from "ahooks";
import { useCallback, useMemo } from "react";
import { useModel } from "umi";

interface ItemT {
  token: string;
}

interface FormT {
  account: string;
  password: string;
}

const DEFAULT_FORM: FormT = {
  account: "",
  password: "",
};

const API = api.auth;

export default () => {
  const { initialState, setInitialState } =
    useModel<"@@initialState">("@@initialState");
  const token = useMemo(() => initialState?.token ?? "", [initialState]);

  const [loading, { setTrue: setLoading, setFalse: setNotLoading }] =
    useBoolean();

  const Login = useCallback(async (body: FormT) => {
    try {
      setLoading();
      const { data } = await useApi<FormT, ItemT>(API.login, {
        method: "POST",
        body,
      });
      storage.setToken(data.token);
      setInitialState({ ...initialState, token: data.token });
      return true;
    } catch {
      return false;
    } finally {
      setNotLoading();
    }
  }, []);

  const Logout = useCallback(async () => {
    try {
      setLoading();
      await useApi(API.logout, {
        method: "POST",
        token,
      });
      return true;
    } catch {
      return false;
    } finally {
      storage.removeToken();
      setInitialState({ ...initialState, token: undefined });
      setNotLoading();
    }
  }, [token]);

  return {
    auth: {
      Login,
      Logout,
      DEFAULT_FORM,
      loading,
    },
  };
};
```

- `src/pages/private/Logout/Logout.tsx`

```tsx
import { DEFAULT_PATH_PUBLIC } from "@/configs/routes";
import { useEffect } from "react";
import { history, useModel } from "umi";

export default () => {
  const {
    auth: { Logout },
  } = useModel("auth");
  useEffect(() => {
    const logout = async () => {
      if (await Logout()) {
        history.push(DEFAULT_PATH_PUBLIC);
      }
    };
    logout();
  }, []);
  return null;
};
```

- `src/pages/private/Welcome/Welcome.tsx`

```tsx
import PageFrame from "@/components/PageFrame";

export default () => {
  return <PageFrame />;
};
```

- `src/pages/public/Login/Login.tsx`

```tsx
import { DEFAULT_PATH_PRIVATE } from "@/configs/routes";
import { Button, Col, Form, Input, Row } from "antd";
import { useEffect, useRef } from "react";
import { history, useModel } from "umi";

export default () => {
  const { auth } = useModel("auth");
  const [form] = Form.useForm<typeof auth.DEFAULT_FORM>();
  const inputRef = useRef<Input>(null);
  useEffect(() => {
    inputRef.current!.focus({
      cursor: "all",
    });
  }, []);
  return (
    <Row className="h-screen" align="middle" justify="center">
      <Col>
        <Form
          form={form}
          name="auth"
          initialValues={auth.DEFAULT_FORM}
          onFinish={async (values) => {
            if (await auth.Login(values)) {
              history.push(DEFAULT_PATH_PRIVATE);
            }
          }}
        >
          <Form.Item label="帳號" name="account" rules={[{ required: true }]}>
            <Input ref={inputRef} placeholder="account" />
          </Form.Item>
          <Form.Item label="密碼" name="password" rules={[{ required: true }]}>
            <Input.Password
              autoComplete="current-password"
              placeholder="password"
            />
          </Form.Item>
          <Form.Item noStyle>
            <Button
              htmlType="submit"
              type="primary"
              block
              loading={auth.loading}
            >
              登入
            </Button>
          </Form.Item>
        </Form>
      </Col>
    </Row>
  );
};
```

- `src/utils/api.ts`

```tsx
import { prefix } from "@/configs/api";
import { request, RequestConfig } from "umi";

type MethodT = "GET" | "POST" | "PUT" | "DELETE";

interface ApiOptionT<T> {
  method: MethodT;
  token?: string;
  params?: object;
  body?: T;
}

interface BasicResT<ResT> {
  success: boolean;
  data: ResT;
  errorCode: string;
  errorMessage: string;
  showType: number;
}

const basicHeaders = {
  Accept: "application/json",
  "Content-Type": "application/json; charset=utf-8",
};

const API_OPTIONS = <dataT>({
  method,
  token,
  params,
  body,
}: ApiOptionT<dataT>): RequestConfig => ({
  method,
  prefix,
  headers: token
    ? {
        ...basicHeaders,
        Authorization: `Bearer ${token}`,
      }
    : basicHeaders,
  params,
  data: body,
});

/**
 * useApi<ReqT, ResT>(url: string, options: { method: 'GET' | 'POST' | 'PUT' | 'DELETE', token: string , params: object, body: object })
 */
export const useApi = <ReqT = undefined, ResT = undefined>(
  url: string,
  options: ApiOptionT<ReqT>
) => request<BasicResT<ResT>>(url, API_OPTIONS<ReqT>(options));
```

- `src/utils/storage.ts`

```tsx
const keyToken = "myapp_authentication";

export const storage = {
  getToken: () => {
    const token = window.localStorage.getItem(keyToken);
    return token !== null ? token : undefined;
  },
  setToken: (token: string) => {
    window.localStorage.setItem(keyToken, token);
  },
  removeToken: () => {
    window.localStorage.removeItem(keyToken);
  },
};
```

- `src/access.ts`

```tsx
import { InitialStateT } from "./app";

interface AccessT {
  isLogin: boolean;
}

export default (initialState: InitialStateT): AccessT => ({
  isLogin: initialState.token !== undefined,
});
```

- `src/app.tsx`

```tsx
import { BasicLayoutProps } from "@ant-design/pro-layout";
import { history } from "umi";
// import logo from '../public/favicon.png';
import {
  DEFAULT_PATH_PRIVATE,
  DEFAULT_PATH_PUBLIC,
  ROUTES_NEED_REDIRECT,
  TITLE,
} from "./configs/routes";
import { storage } from "./utils/storage";

const isAccessRouteNeedRedirect = (path: string) =>
  new Set(ROUTES_NEED_REDIRECT).has(path);

export const layout = ({
  initialState,
}: {
  initialState: InitialStateT;
}): BasicLayoutProps => {
  const isLogin = initialState.token !== undefined;
  return {
    title: TITLE,
    // logo,
    rightContentRender: () => null,
    onPageChange: async () => {
      const {
        location: { pathname },
      } = history;
      // authorized user access protected routes
      if (isLogin && isAccessRouteNeedRedirect(pathname)) {
        history.push(DEFAULT_PATH_PRIVATE);
      }
      // unauthorized user access protected routes
      if (!isLogin && !isAccessRouteNeedRedirect(pathname)) {
        history.push(DEFAULT_PATH_PUBLIC);
      }
    },
  };
};

export interface InitialStateT {
  token?: string;
}

export const getInitialState = async (): Promise<InitialStateT> => {
  return { token: storage.getToken() };
};
```

- `src/global.less`

```less
.fadeIn {
  animation: fadeIn 0.5s ease-out;
}

.fadeInUp {
  animation: fadeInUp 0.2s ease-out;
}

.fadeInZoom {
  animation: fadeInZoom 0.1s ease-out;
}

.fadeInPop {
  animation: fadeInPop 0.5s ease-out;
}

/* shake effect for validate failed <Input /> */
.ant-form-item-has-error {
  animation: shakeX 0.3s ease-out;
}

@keyframes fadeIn {
  0% {
    opacity: 0;
  }
  100% {
    opacity: 1;
  }
}

@keyframes fadeInUp {
  0% {
    opacity: 0;
    transform: translateY(20px) scale(1.05);
  }
  100% {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes fadeInZoom {
  0% {
    opacity: 0;
    transform: translateY(20px) scale(1.5);
  }
  100% {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes fadeInPop {
  0% {
    opacity: 0;
    transform: translateY(5px) scale(0.9);
  }
  50% {
    opacity: 1;
    transform: translateY(0) scale(1.1);
  }
  100% {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes shakeX {
  from,
  to {
    transform: translate3d(0, 0, 0);
  }

  10%,
  50%,
  90% {
    transform: translate3d(-10px, 0, 0);
  }

  30%,
  70% {
    transform: translate3d(10px, 0, 0);
  }
}
```

```bash
yarn prettier
```

```bash
yarn dev
```
