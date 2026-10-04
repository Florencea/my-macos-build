---
trigger: glob
globs: "**/*.tsx, **/*.jsx, **/*.css"
description: React 19 paradigms and Tailwind CSS v4 styling rules.
---

# Modern React 19 & Tailwind CSS v4 Rules

## 1. React 19 Paradigms

- **Direct Ref Passing**: Pass `ref` directly as a regular prop. NEVER use `React.forwardRef`. Destructure `{ ref, ...props }` in component parameter lists.
- **Explicit Component Typing**: Never use `React.FC` or `React.FunctionComponent`. Declare custom prop interfaces (e.g. `interface ButtonProps`) and type `children` as `React.ReactNode`.
- **Server Actions for Mutations**: Prefer `<form action={serverAction}>` paired with `useActionState` and `useFormStatus`. Avoid legacy `onSubmit` handlers paired with `e.preventDefault()`.
- **Async Resource Unwrapping**: Use `use(Promise)` or `use(Context)` to unwrap resources. NEVER use `useEffect` for initial data fetching.
- **Optimistic UI**: Use `useOptimistic` for instantaneous UI state updates before action completion.
- **Automatic Memoization (React Compiler)**: When `@vitejs/plugin-react` has `compiler: true` (paired with `oxc-transform-react`), NEVER manually add `useMemo`, `useCallback`, or `React.memo` unless handling explicit compiler bailouts. Trust the compiler's automated fine-grained memoization.
- **Server/Client Boundaries**: Default components to React Server Components (RSC). Add `"use client"` only when accessing browser APIs, state hooks, or event listeners.

---

## 2. Tailwind CSS v4 Rules

- **Design Token SSOT (`@theme`)**: Tailwind CSS v4 `@theme` in the root CSS file is the sole source of truth for design tokens. Bridge tokens to UI libraries (e.g. Ant Design tokens, Spectrum) via CSS variables. Never hardcode magic colors or use inline `style={{ ... }}` overrides.
- **Canonical Class Validation**: Maintain zero warnings on `vpr lint:tailwind`. All classes must conform to Tailwind v4 canonical syntax.
- **No Dynamic Class Interpolation**: NEVER dynamically interpolate class strings (e.g. `bg-blue-${shade}`). Use complete class literals or lookup record maps so the scanner detects them.
- **Merge Classes Reliably**: NEVER concatenate class strings manually. Always use `clsx` and `tailwind-merge` (typically wrapped as `cn(...)`) to resolve CSS specificity conflicts.
- **Native CSS Variables & `@theme`**: Leverage Tailwind v4 `@theme` directives and CSS custom properties instead of legacy JS configuration files (`tailwind.config.js`).
- **Restrict `@apply`**: Stick to utility classes directly in markup. Avoid extracting utilities via `@apply` into CSS files except for base resets.
