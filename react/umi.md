# UmiJS Note

- <https://umijs.org/zh-CN/docs>
- Only work with npm, yarn
- Official: yarn

## umi + antd + tailwindcss

```bash
mkdir myapp && cd myapp
```

```bash
yarn create @umijs/umi-app
```

```bash
yarn add -D \
tailwindcss@2 \
umi-plugin-tailwindcss \
eslint \
typescript \
@typescript-eslint/parser \
@typescript-eslint/eslint-plugin \
eslint-plugin-react \
eslint-config-alloy
```

```bash
yarn add \
antd \
@ant-design/colors \
@ant-design/icons
```

```bash
rm \
src/pages/index.tsx \
src/pages/index.less \
mock/.gitkeep \
README.md
```

```bash
printf '.umi\n.umi-production\n.umi-test\ndist/\n' > .prettierignore
```

```bash
mkdir -p \
public \
src/models \
src/components \
src/configs \
src/hooks \
src/pages/private \
src/pages/public
```

```bash
touch \
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
src/pages/private/Welcome.tsx \
src/pages/private/Logout.tsx \
src/pages/public/Login.tsx \
src/hooks/useApi.ts \
src/hooks/useToken.ts
```

```bash
code .
```

- `.gitignore`

```ignore
# See https://help.github.com/articles/ignoring-files/ for more about ignoring files.

# dependencies
/node_modules
/npm-debug.log*
/yarn-error.log

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
import { defineConfig } from 'umi'
import { routes, TITLE } from './src/configs/routes'
import { theme } from './src/configs/theme'

export default defineConfig({
  nodeModulesTransform: {
    type: 'none'
  },
  fastRefresh: {},
  hash: true,
  ignoreMomentLocale: true,
  locale: {
    default: 'zh-TW',
    antd: true,
    baseNavigator: true
  },
  antd: {},
  layout: {},
  theme,
  routes,
  title: TITLE,
  history: { type: 'hash' }
  // proxy: {
  //   '/api': 'http://localhost:4000/',
  //   "/api": {
  //     target: "https://localhost:4000/",
  //     changeOrigin: true,
  //     secure: false,
  //   },
  // },
  // devServer: {
  //   https: { key: "./cert/localhost.key", cert: "./cert/localhost.crt" },
  // },
  // favicon: '/favicon.png',
})
```

- `package.json`

```json
{
  "eslintConfig": {
    "extends": ["alloy", "alloy/react", "alloy/typescript"],
    "env": {
      "browser": true
    },
    "globals": {
      "React": "readonly"
    },
    "rules": {
      "@typescript-eslint/no-require-imports": 0
    }
  }
}
```

- `tailwind.config.js`

```js
module.exports = {
  corePlugins: {
    preflight: false
  },
  important: '#root',
  purge: ['./src/**/*.html', './src/**/*.tsx', './src/**/*.ts'],
  darkMode: 'media',
  theme: {
    colors: {
      white: '#fff',
      black: '#000',
      ...require('@ant-design/colors')
    },
    extend: {}
  },
  plugins: []
}
```

- `mock/api.ts`

```ts
const success = {
  success: true,
  data: {
    token: 'fake_token'
  }
}

const failed = {
  success: false,
  errorCode: '401',
  errorMessage: '帳號或密碼錯誤',
  showType: 2
}

export default {
  'POST /api/login': (req: any, res: any) => {
    const { account, password } = req.body
    if (`${account}|${password}` === 'test|test') {
      res.json(success)
    } else {
      res.status(401).json(failed)
    }
  },
  'POST /api/logout': { success: true }
}
```

- `public/robots.txt`

```text
# https://www.robotstxt.org/robotstxt.html
User-agent: *
Disallow:
```

- `src/components/PageFrame.tsx`

```tsx
import { getPageTitle } from '@/configs/routes'
import { Col, Empty, PageHeader, PageHeaderProps, Row } from 'antd'
import { useMemo } from 'react'
import { history } from 'umi'

interface Props {
  pageHeaderProps?: Partial<PageHeaderProps>
  children?: React.ReactNode
}

export default ({ pageHeaderProps, children }: Props) => {
  const TITLE = useMemo(
    () => getPageTitle(history.location.pathname),
    [history.location.pathname]
  )
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
  )
}
```

- `src/configs/api.ts`

```ts
export const prefix = '/api'

export const api = {
  auth: {
    login: '/login',
    logout: '/logout'
  }
}
```

- `src/configs/routes.ts`

```ts
import { AccessT } from '@/access'
import { Route } from '@ant-design/pro-layout/lib/typings'

export const DEFAULT_PATH_PUBLIC = '/login'
export const DEFAULT_PATH_PRIVATE = '/welcome'
export const TITLE = 'myapp'

const basicRouteConfig: Route = {
  hideInBreadcrumb: true,
  headerRender: false
}

const basicRouteConfigWithoutMenu: Route = {
  ...basicRouteConfig,
  hideInMenu: true,
  menuRender: false
}

const privateRoutes: (Route & { access: keyof AccessT })[] = [
  {
    ...basicRouteConfig,
    path: DEFAULT_PATH_PRIVATE,
    name: '歡迎',
    icon: 'Smile',
    access: 'isLogin',
    component: '@/pages/private/Welcome'
  },
  {
    ...basicRouteConfig,
    path: '/logout',
    name: '登出',
    icon: 'Logout',
    access: 'isLogin',
    component: '@/pages/private/Logout'
  }
]

const publicRoutes: Route[] = [
  {
    ...basicRouteConfigWithoutMenu,
    path: DEFAULT_PATH_PUBLIC,
    component: '@/pages/public/Login'
  }
]

export const ROUTES_NEED_REDIRECT = [DEFAULT_PATH_PUBLIC]

export const routes: Route[] = [
  ...privateRoutes,
  ...publicRoutes,
  { exact: false, path: '/', name: '', redirect: DEFAULT_PATH_PUBLIC }
]

export const getPageTitle = (currentPath: string) =>
  routes.find((r) => r.path === currentPath)?.name ?? ''
```

- `src/configs/theme.ts`

```ts
import { volcano } from '@ant-design/colors'

export const theme = {
  'primary-color': volcano.primary
}
```

- `src/hooks/useApi.ts`

```ts
import { prefix } from '@/configs/api'
import { request, RequestConfig } from 'umi'

type MethodT = 'GET' | 'POST' | 'PUT' | 'DELETE'

interface ApiOptionT<T> {
  method: MethodT
  token?: string
  params?: object
  body?: T
}

interface BasicResT<ResT> {
  success: boolean
  data: ResT
  errorCode: string
  errorMessage: string
  showType: number
}

const basicHeaders = {
  Accept: 'application/json',
  'Content-Type': 'application/json; charset=utf-8'
}

const API_OPTIONS = <dataT>({
  method,
  token,
  params,
  body
}: ApiOptionT<dataT>): RequestConfig => ({
  method,
  prefix,
  headers: token
    ? {
        ...basicHeaders,
        Authorization: `Bearer ${token}`
      }
    : basicHeaders,
  params,
  data: body
})

/**
 * useApi<ReqT, ResT>(url: string, options: { method: 'GET' | 'POST' | 'PUT' | 'DELETE', token: string , params: object, body: object })
 */
export const useApi = <ReqT = undefined, ResT = undefined>(
  url: string,
  options: ApiOptionT<ReqT>
) => request<BasicResT<ResT>>(url, API_OPTIONS<ReqT>(options))
```

- `src/hooks/useToken.ts`

```ts
const TOKEN_KEY = 'myapp_auth'
export const getToken = () => {
  const token = window.localStorage.getItem(TOKEN_KEY)
  return token !== null ? token : undefined
}
export const setToken = (token: string) => {
  window.localStorage.setItem(TOKEN_KEY, token)
}
export const removeToken = () => {
  window.localStorage.removeItem(TOKEN_KEY)
}
```

- `src/models/auth.ts`

```ts
import { api } from '@/configs/api'
import { useApi } from '@/hooks/useApi'
import { removeToken, setToken } from '@/hooks/useToken'
import { useCallback, useMemo, useState } from 'react'
import { useModel } from 'umi'

interface ItemT {
  token: string
}

interface FormT {
  account: string
  password: string
}

const DEFAULT_FORM: FormT = {
  account: '',
  password: ''
}

const API = api.auth

export default () => {
  const { initialState, setInitialState } =
    useModel<'@@initialState'>('@@initialState')
  const token = useMemo(() => initialState?.token ?? '', [initialState])

  const [loading, setLoading] = useState(false)

  const Login = useCallback(async (body: FormT) => {
    try {
      setLoading(true)
      const { data } = await useApi<FormT, ItemT>(API.login, {
        method: 'POST',
        body
      })
      setToken(data.token)
      setInitialState({ ...initialState, token: data.token })
      return true
    } catch {
      return false
    } finally {
      setLoading(false)
    }
  }, [])

  const Logout = useCallback(async () => {
    try {
      setLoading(true)
      await useApi(API.logout, {
        method: 'POST',
        token
      })
      return true
    } catch {
      return false
    } finally {
      removeToken()
      setInitialState({ ...initialState, token: undefined })
      setLoading(false)
    }
  }, [token])

  return {
    auth: {
      Login,
      Logout,
      DEFAULT_FORM,
      loading
    }
  }
}
```

- `src/pages/private/Logout.tsx`

```tsx
import { DEFAULT_PATH_PUBLIC } from '@/configs/routes'
import { useEffect } from 'react'
import { history, useModel } from 'umi'

export default () => {
  const {
    auth: { Logout }
  } = useModel('auth')
  useEffect(() => {
    const logout = async () => {
      if (await Logout()) {
        history.push(DEFAULT_PATH_PUBLIC)
      }
    }
    logout()
  }, [])
  return null
}
```

- `src/pages/private/Welcome.tsx`

```tsx
import PageFrame from '@/components/PageFrame'

export default () => {
  return <PageFrame />
}
```

- `src/pages/public/Login.tsx`

```tsx
import { DEFAULT_PATH_PRIVATE } from '@/configs/routes'
import { Button, Col, Form, Input, Row } from 'antd'
import { useEffect, useRef } from 'react'
import { history, useModel } from 'umi'

export default () => {
  const { auth } = useModel('auth')
  const [form] = Form.useForm<typeof auth.DEFAULT_FORM>()
  const inputRef = useRef<Input>(null)
  useEffect(() => {
    inputRef.current!.focus({
      cursor: 'all'
    })
  }, [])
  return (
    <Row className="h-screen" align="middle" justify="center">
      <Col className="p-8 rounded bg-white fadeInUp">
        <Form
          form={form}
          name="auth"
          initialValues={auth.DEFAULT_FORM}
          onFinish={async (values) => {
            if (await auth.Login(values)) {
              history.push(DEFAULT_PATH_PRIVATE)
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
  )
}
```

- `src/access.ts`

```ts
import { InitialStateT } from './app'

export interface AccessT {
  isLogin: boolean
}

export default (initialState: InitialStateT): AccessT => ({
  isLogin: initialState.token !== undefined
})
```

- `src/app.tsx`

```tsx
import { BasicLayoutProps } from '@ant-design/pro-layout'
import { history } from 'umi'
import {
  DEFAULT_PATH_PRIVATE,
  DEFAULT_PATH_PUBLIC,
  ROUTES_NEED_REDIRECT,
  TITLE
} from './configs/routes'
import { getToken } from './hooks/useToken'

const isAccessRouteNeedRedirect = (path: string) =>
  new Set(ROUTES_NEED_REDIRECT).has(path)

export const layout = ({
  initialState
}: {
  initialState: InitialStateT
}): BasicLayoutProps => {
  const isLogin = initialState.token !== undefined
  return {
    title: TITLE,
    logo: null,
    rightContentRender: () => null,
    onPageChange: async () => {
      const {
        location: { pathname }
      } = history
      // authorized user access protected routes
      if (isLogin && isAccessRouteNeedRedirect(pathname)) {
        history.push(DEFAULT_PATH_PRIVATE)
      }
      // unauthorized user access protected routes
      if (!isLogin && !isAccessRouteNeedRedirect(pathname)) {
        history.push(DEFAULT_PATH_PUBLIC)
      }
    }
  }
}

export interface InitialStateT {
  token?: string
}

export const getInitialState = async (): Promise<InitialStateT> => {
  return { token: getToken() }
}
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
yarn start
```
