---
trigger: glob
globs: "**/*.tsx, **/*.jsx, **/*.html, **/*.css"
description: Web Platform Baseline priority, explicit zero-black-box UI and routing, Tailwind v4 @theme tokens, and standard browser testing invariants.
---

# Web UI, Styling & Browser Testing Guardrails

## 1. Web Platform Baseline First (`modern-web-guidance`)

- Before adding UI libraries, polyfills, or custom JS for overlays (`<dialog>`, `[popover]`), form validation states (`:user-invalid`), modern CSS layouts, view transitions, or ARIA patterns, query `npx modern-web-guidance search "<query>"` and `retrieve "<id>"`.
- Prefer native Baseline browser primitives directly; only load polyfills via runtime feature detection and dynamic `import()` when older targets strictly require them.

---

## 2. Explicit UI & Routing Architecture

- **No Hidden Rewrites or Codegen**: Do not enable React Compiler (`compiler: true`) or file-based auto-generated route trees (`routeTree.gen.ts`). When client-side routing is needed, declare routes explicitly in source code and validate search parameters with Zod.
- **Standard Component Hygiene**: Pass `ref` directly as a prop (forbid `React.forwardRef` and `React.FC`). Compute derived state during render instead of syncing local state in `useEffect`. For static prerendering with React 19, use `react-dom/static` `prerender` rather than legacy `renderToString`.

---

## 3. Minimal Styling Contract & Verification

- **Tailwind v4 `@theme` SSOT**: Define design tokens centrally via `@import "tailwindcss";` and `@theme { ... }`. Avoid hardcoded hex/rgb values outside `@theme` and static inline `style={{ ... }}`.
- **No `tailwind-merge` or Custom LSP Scripts**: Compose conditional classes via `clsx` with mutually exclusive branches rather than `tailwind-merge`. Rely on `prettier-plugin-tailwindcss` for deterministic utility sorting; never introduce custom `tailwindcss-language-server` lint scripts.
- **Verification**: Use Vitest with `@vitest/browser-playwright` (`headless: true`, `chromium`) for browser E2E tests, and verify changes with standard `npm run` commands (`lint`, `format:check`, `typecheck`, `test`, `build`).
