---
name: modern-react-tailwind
description: Modern React architectural invariants (Actions, Effect discipline, direct ref prop), Tailwind v4 @theme tokens, @shadcn/lint contracts, and two-stage .md doc gateways. Use when building React UI or Tailwind styles.
compatibility: React, Tailwind CSS, Oxlint
---

# Modern React & Tailwind CSS Guidelines

## 1. External SSOT Lookup Gateways (Required Before Coding)

`react.dev` HTML routes return empty anti-bot pages; always resolve React docs via `.md` endpoints from `llms.txt`:

- **React Core & API Reference** (Two-Stage `.md`):
  - Stage 1: `curl -fsSL https://react.dev/llms.txt | head -n 120`
  - Stage 2: `curl -fsSL https://react.dev/<path>.md` (e.g. `https://react.dev/reference/react.md`, `https://react.dev/learn/you-might-not-need-an-effect.md`)
- **React & Accessibility Oxlint Rules**:
  - Inspect enabled rules: `npx oxlint --rules` (filter `react`, `react_perf`, `jsx_a11y`).
  - Rule details & examples: `curl -fsSL https://oxc.rs/docs/guide/usage/linter/rules/react/<rule>.md` (e.g. `set-state-in-effect.md`, `exhaustive-deps.md`, `forward-ref-uses-ref.md`).
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

## 3. Tailwind CSS Design Tokens & `@shadcn/lint` Contracts

- **Design Token SSOT (`@theme`)**: Define CSS tokens centrally in root CSS (`@import "tailwindcss";` + `@theme { ... }`) and bind third-party UI library theme tokens to those CSS variables.
- **Enforced Component Contracts (`npx oxlint`)**:
  - `shadcn/no-raw-colors`: Forbid hardcoded hex/rgb values outside `@theme`.
  - `shadcn/no-arbitrary-values`: Ban unmapped arbitrary brackets (e.g. `w-[321px]`).
  - `shadcn/no-inline-styles`: Forbid `style={{ ... }}`; bind CSS variables or variants.
  - `shadcn/no-restyle`: External callers may pass layout/positioning utilities (`allow: ["layout"]`) or declared variants only; never restyle internal typography or borders from outside.
- **Verification & Sorting Split**: Run `npx oxfmt <files>` and `npx oxlint -f agent` for Oxc formatting and `@shadcn/lint` contracts; run `npm run lint:tailwind` / `npm run lint:tailwind:fix` (via `tailwindcss-language-server`) for Tailwind CSS utility diagnostics and canonical class sorting.
