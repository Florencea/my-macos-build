---
name: modern-react-tailwind
description: Modern React architectural invariants (Actions, Effect discipline, direct ref prop), Tailwind v4 @theme tokens, ESLint/Prettier workflows, and two-stage .md doc gateways. Use when building React UI or Tailwind styles.
compatibility: React, Tailwind CSS, ESLint, Prettier
---

# Modern React & Tailwind CSS Guidelines

## 1. External SSOT Lookup Gateways (Required Before Coding)

`react.dev` HTML routes return empty anti-bot pages; always resolve React docs via `.md` endpoints from `llms.txt`:

- **React Core & API Reference** (Two-Stage `.md`):
  - Stage 1: `curl -fsSL https://react.dev/llms.txt | head -n 120`
  - Stage 2: `curl -fsSL https://react.dev/<path>.md` (e.g. `https://react.dev/reference/react.md`, `https://react.dev/learn/you-might-not-need-an-effect.md`)
- **React & Accessibility ESLint Rules**:
  - Inspect enabled rules: `npx eslint --print-config <file>` (`eslint-plugin-react-hooks`, `eslint-plugin-jsx-a11y`).
  - Rule details & examples: `https://eslint.org/docs/latest/rules/` and `https://react.dev/reference/eslint-plugin-react-hooks`.
- **Tailwind CSS Documentation**:
  - Fetch `https://tailwindcss.com/docs/theme` (or `/docs/<topic>`) and inspect local CSS `@theme` definitions.
- **Web Platform Capabilities (Delegate Strictly to MWG)**:
  - Before implementing `<dialog>`, `[popover]`, anchor positioning, View Transitions, Container Queries, `:user-invalid`, or ARIA behaviors, query `npx modern-web-guidance search "<query>"` and `retrieve "<id>"`.

---

## 2. React Architectural Invariants

- **Server vs Client Boundary**: Default components to React Server Components (RSC). Add `"use client"` strictly when browser APIs, interactive state hooks, or event handlers are needed.
- **Direct `ref` Prop & Function Components**: Pass `ref` directly as a prop (`function Input({ ref, ...props }: InputProps)`). STRICTLY PROHIBITED: `React.forwardRef`, `React.FC`, `React.FunctionComponent`.
- **Actions & Async Unwrapping**: Prefer form actions (`useActionState`, `useFormStatus`, `useOptimistic`) over manual `onSubmit` + `e.preventDefault()`, and `use(Promise)` / `use(Context)` over fetching inside `useEffect`.
- **Effect Synchronization Discipline**: Effects are strictly for synchronizing with external systems (DOM widgets, WebSockets, external stores). Never use `useEffect` for derived state, expensive memoized calculations, prop-change resets, or user event chains; consult `https://react.dev/learn/you-might-not-need-an-effect.md` when in doubt.

---

## 3. Tailwind CSS Design Tokens & Component Contracts

- **Design Token SSOT (`@theme`)**: Define CSS tokens centrally in root CSS (`@import "tailwindcss";` + `@theme { ... }`) and bind third-party UI library theme tokens to those CSS variables.
- **Component Styling Contracts**:
  - Forbid hardcoded hex/rgb values outside `@theme`.
  - Avoid unmapped arbitrary bracket dimensions (e.g. `w-[321px]`) where design tokens apply.
  - Forbid inline `style={{ ... }}` for theme colors or static styles; bind CSS variables or variants.
  - External callers may pass layout/positioning utilities or declared variants only; never restyle internal typography or borders from outside.
- **Verification & Sorting Split**: Run `npx prettier --write <files>` and `npx eslint --format compact` for formatting and lint checks; run `npm run lint:tailwind` / `npm run lint:tailwind:fix` (via `tailwindcss-language-server`) for Tailwind CSS utility diagnostics and canonical class sorting.
