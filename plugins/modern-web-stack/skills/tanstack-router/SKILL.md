---
name: tanstack-router
description: File-based routing, Zod validateSearch, routeTree.gen.ts protection, loaders, and Markdown SSOT lookups for TanStack Router. Use when creating or modifying client-side routes or query parameters.
compatibility: TanStack Router, React, Zod
---

# TanStack Router Guidelines

## 1. External SSOT & Local Declaration Gateways

`tanstack.com` HTML pages return empty anti-bot pages; always read `.md` endpoints listed in `llms.txt` or local `.d.ts` declarations:

- **Two-Stage `curl -fsSL` (`.md` Mandatory)**:
  - Stage 1 (Index): `curl -fsSL https://tanstack.com/router/latest/llms.txt | head -n 120`
  - Stage 2 (Targeted Markdown): `curl -fsSL https://tanstack.com/router/latest/docs/<path>.md` (e.g. `https://tanstack.com/router/latest/docs/guide/search-params.md`, `.../docs/guide/data-loading.md`, `.../docs/framework/react/overview.md`).
- **Local Declarations**: Inspect `node_modules/@tanstack/react-router/**/*.d.ts` for exact hook, `createFileRoute`, and `validateSearch` options.
- **Zod Verification**: Verify search parameter schema helpers against `https://zod.dev/llms.txt` -> `https://zod.dev/api` (or `node_modules/zod/**/*.d.ts`).

---

## 2. Routing Architecture & File Invariants

- **Route Directory SSOT**: Place all route files strictly under `src/routes/` (`__root.tsx`, `index.tsx`, `$.tsx`).
- **Protected Generated File**: `src/routeTree.gen.ts` is owned exclusively by `@tanstack/router-plugin/vite`. **STRICTLY PROHIBITED to manually edit `src/routeTree.gen.ts`**.

---

## 3. Search Parameters, Loaders & Navigation Invariants

- **Zod-First `validateSearch`**: Validate and coerce every route search query parameter through a Zod schema in `validateSearch` rather than reading `window.location.search` manually.
- **Loaders Over Effects**: Fetch initial route data inside `loader` (or prefetch with `queryClient.ensureQueryData(...)`) instead of triggering data fetches inside component `useEffect`.
- **Type-Safe Navigation**: Use type-checked `<Link>` and `useNavigate()` with route `to` and `search` contracts.
