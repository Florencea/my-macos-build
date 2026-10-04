---
name: modern-react-tailwind
description: Strict best practices for modern React (React 19) and Tailwind CSS v4. Use when building React components, server actions, forms, hooks, layout structures, and styling with Tailwind CSS v4.
compatibility: React 19.x, Tailwind CSS 4.x
---

# Modern React & Tailwind CSS Guidelines

**CRITICAL:** Enforce React 19 paradigms and Tailwind CSS v4 patterns across all generated code.

## 1. Architecture & Component Decision Tree

Follow this decision tree when designing components and styling:

- **Server vs Client Boundary**:
  - Default all components to **React Server Components (RSC)**.
  - Add `"use client"` ONLY when the component requires browser APIs, state hooks (`useState`, `useReducer`), event handlers (`onClick`, `onChange`), or custom interactive hooks.
- **Form Submissions & Data Mutations**:
  - Always prefer native `<form action={serverAction}>` paired with `useActionState` and `useFormStatus`.
  - Avoid legacy `onSubmit` handlers paired with `e.preventDefault()`.
- **Async Resource Unwrapping**:
  - Use `use(Promise)` or `use(Context)` to unwrap resources directly in render.
  - NEVER use `useEffect` for initial data fetching.
- **Optimistic UI**:
  - Use `useOptimistic` for instantaneous UI state updates before server action completion.
- **Class Merging & Conditional Classes**:
  - Always merge classes via `clsx` and `tailwind-merge` (typically encapsulated as `cn(...)`).
  - NEVER concatenate class strings manually (`${base} ${extra}`).
- **Theme & Design Tokens**:
  - Use native Tailwind CSS v4 `@theme` directives and CSS variables.
  - Do NOT create or edit legacy JavaScript configuration files (`tailwind.config.js`).

---

## 2. React 19 Best Practices

- **Direct Ref Passing:** Pass `ref` directly as a regular prop. Never use `React.forwardRef`; destructure `{ ref, ...props }` directly in component signatures.
- **Explicit Component Typing:** Never use `React.FC` or `React.FunctionComponent`. Explicitly declare prop types (e.g., `interface ButtonProps`) and type `children` as `React.ReactNode`.
- **Server/Client Boundaries:** Keep Client Components as lean leaves in the component tree to maximize server-side rendering and reduce client bundle size.

---

## 3. Tailwind CSS v4 Rules

- **No Dynamic Class Interpolation:** Never dynamically interpolate class names (e.g., `bg-blue-${shade}`). Use complete class string literals or record maps so the static scanner detects them.
- **Native CSS Variables & `@theme`:** Leverage Tailwind v4 `@theme` directives and CSS custom properties instead of legacy JS configuration files.
- **Restrict `@apply`:** Stick to utility classes directly in markup. Avoid extracting utilities via `@apply` into CSS files except for base resets.

---

## 4. Authoritative Documentation & LLM References

When agents need up-to-date syntax, API definitions, or migration patterns, consult these authoritative endpoints:

- **React 19 Official Documentation**:
  - LLM Topic Index: `https://react.dev/llms.txt`
  - React Reference: `https://react.dev/reference/react`
  - Specific React 19 APIs:
    - `useActionState`: `https://react.dev/reference/react/useActionState`
    - `useFormStatus`: `https://react.dev/reference/react-dom/hooks/useFormStatus`
    - `useOptimistic`: `https://react.dev/reference/react/useOptimistic`
    - `use`: `https://react.dev/reference/react/use`
- **Tailwind CSS v4 Official Documentation**:
  - Core Documentation: `https://tailwindcss.com/docs`
  - v4 Theme & Variables: `https://tailwindcss.com/docs/theme`
