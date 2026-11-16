---
trigger: glob
globs: "**/*.tsx, **/*.jsx, **/*.html, **/*.css"
description: Modern React, Tailwind CSS, TanStack Router, Playwright browser testing, and Web Platform guidance invariants.
---

# React, Tailwind CSS & Web Platform Rules

## 1. Web Platform SSOT (`modern-web-guidance`)

- Query `vpx modern-web-guidance search "<query>"` and `retrieve "<id>"` before implementing overlays (`<dialog>`, `[popover]`), anchor positioning, view transitions, scroll-driven animations, form validation states, or ARIA patterns. Prefer native Baseline APIs over third-party polyfills.

---

## 2. React, Tailwind CSS & Routing Invariants

- **React Paradigms**: Compute derived state during render; never synchronize local state via `useEffect` without external subscriptions. Pass `ref` directly as a prop; strictly prohibit `React.forwardRef` and `React.FC`. Prefer `<form action={...}>` with `useActionState` / `useFormStatus` / `useOptimistic`.
- **Tailwind Design Tokens & Contracts**: Define tokens in root CSS via `@import "tailwindcss";` and `@theme { ... }`. Enforce `shadcn/no-raw-colors`, `shadcn/no-arbitrary-values`, and `shadcn/no-inline-styles`; external callers may pass layout utilities or declared variants only.
- **TanStack Router**: Place route files under `src/routes/`. NEVER edit generated `src/routeTree.gen.ts`. Validate search parameters with `validateSearch` and Zod schemas.

---

## 3. Verification & Docs Gateways

- **Testing & Formatting**: Use `vite-plus/test` and `vite-plus/test/browser-playwright` (`headless: true`, `chromium`) for E2E tests. Run `vp fmt <files>`, `vp check`, and `vpr lint:tailwind` (when configured).
- **Two-Stage Docs**: `react.dev` and `tanstack.com` HTML routes return empty shells; always fetch `/llms.txt` -> targeted `.md` pages (or inspect `node_modules/**/*.d.ts`).
