# React Note

## Quick Links

- [Vite Note](vite.md)
- [UmiJS Note](umi.md)

## ESLint and Prettier Guide

- <https://github.com/AlloyTeam/eslint-config-alloy/blob/master/README.zh-CN.md>

### For Next.js

- **Do not need ESLint Config Alloy!**
- `package.json`

```json
{
  "prettier": {
    "semi": false,
    "singleQuote": true,
    "trailingComma": "none"
  }
}
```

### For Vite

```bash
npm install -D \
eslint \
typescript \
@typescript-eslint/parser \
@typescript-eslint/eslint-plugin \
eslint-plugin-react \
eslint-config-alloy
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
      "spaced-comment": [
        "error",
        "always",
        {
          "markers": ["/"]
        }
      ],
      "@typescript-eslint/no-require-imports": 0
    }
  },
  "prettier": {
    "semi": false,
    "singleQuote": true,
    "trailingComma": "none"
  }
}
```

### For Umi.js

```bash
npm install -D \
eslint \
typescript \
@typescript-eslint/parser \
@typescript-eslint/eslint-plugin \
eslint-plugin-react \
eslint-config-alloy
```

- **Do not need Prettier rules!**
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
    }
  }
}
```
