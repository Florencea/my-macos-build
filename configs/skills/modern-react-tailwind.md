---
name: modern-react-tailwind
description: Modern React (React 19) and Tailwind CSS v4 strict best practices for Agentic Development
trigger: always_on
---

# Modern React & Tailwind CSS Guidelines

**CRITICAL:** Enforce React 19 paradigms and Tailwind CSS v4 patterns across all generated code.

## 1. React 19 Best Practices

- **Direct Ref Passing:** Pass `ref` directly as a regular prop. Never use `React.forwardRef`; destructure `{ ref, ...props }` in component signatures.
- **Server Actions for Forms:** Prefer `<form action={serverAction}>`. Avoid legacy `onSubmit` handlers paired with `e.preventDefault()`.
- **Modern React Hooks:**
  - **Form & Async Transitions:** Use `useActionState` and `useFormStatus`.
  - **Resource Fetching:** Use `use()` to unwrap Promises or Contexts. Do not use `useEffect` for initial data fetching.
  - **Optimistic UI:** Use `useOptimistic` for instantaneous UI state updates.
- **Explicit Component Typing:** Never use `React.FC` or `React.FunctionComponent`. Explicitly declare prop types (e.g., `interface ButtonProps`) and type `children` as `React.ReactNode`.
- **Server/Client Boundaries:** Default all components to React Server Components (RSC). Add `"use client"` only when accessing browser APIs, hooks, or event listeners.

## 2. Tailwind CSS v4 Rules

- **No Dynamic Class Interpolation:** Never dynamically interpolate classes (e.g.,`bg-blue-${shade}`). Use full class literals or record maps so the scanner detects them.
- **Merge Classes Reliably:** Never concatenate class strings manually. Use `clsx` and `tailwind-merge` (typically wrapped as `cn()`) to resolve specificity conflicts.
- **Native CSS Variables & `@theme`:** Leverage Tailwind v4 `@theme` directives and CSS custom properties instead of legacy JS configuration files.
- **Restrict `@apply`:** Stick to utility classes in markup. Avoid extracting utilities via `@apply` into CSS files except for base resets.
