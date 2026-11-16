---
name: modern-hono-drizzle
description: Type-safe Hono OpenAPI routing with Zod, Drizzle ORM schema SSOT, fail-closed RBAC routing, and llms.txt / .d.ts doc lookups. Use when building or refactoring Hono servers, REST APIs, or DB schemas.
compatibility: Node.js (Active LTS), Hono, Drizzle ORM, Zod, Vite+
---

# Modern Hono & Drizzle ORM Guidelines

## 1. External SSOT & Local Declaration Gateways

`hono.dev/docs/*` HTML pages return empty shells in `webread` and `llms-full.txt` (~134 KB) truncates under default caps. Verify Hono and Drizzle APIs using these verified channels:

- **Hono Reference**:
  - `webread https://hono.dev/llms.txt` or compact summary `webread https://hono.dev/llms-small.txt` (pass `--max-chars 140000` only if fetching `https://hono.dev/llms-full.txt` deliberately).
  - Local type declarations (SSOT for exact signatures): inspect `node_modules/hono/**/*.d.ts` and `node_modules/@hono/zod-openapi/**/*.d.ts`.
- **Drizzle ORM Reference** (Two-Stage `webread`):
  - Stage 1: `webread https://orm.drizzle.team/llms.txt`
  - Stage 2: `webread https://orm.drizzle.team/docs/<topic>` (e.g. `relations-v2`, `drizzle-kit-push`) + inspect `node_modules/drizzle-orm/**/*.d.ts`.

---

## 2. Declarative OpenAPI Routing & SSOT RPC Inference

- **Declarative Contracts (`@hono/zod-openapi`)**:
  - Define HTTP endpoint contracts with `createRoute` specifying Zod schemas for `params`, `query`, `json`, and `responses`.
  - Chain sub-routers onto a top-level router via `.route(...)` and export a single `AppType = typeof router` so frontend clients (`hc<AppType>("/")`) infer exact request/response types without code generation.

---

## 3. Drizzle ORM Schema SSOT & Code-First Push

- **Single Schema Source**: Define tables centrally in `src/server/database/schema.ts` and infer row/insert types directly via `typeof table.$inferSelect` and `typeof table.$inferInsert`. Never duplicate entity interfaces by hand.
- **Schema Sync**: Configure `"db:push": "drizzle-kit push"` in `package.json` and run `vpr db:push`.

---

## 4. Fail-Closed RBAC Security Invariant

- **Explicit Authorization**: Attach access-control middleware (`requirePermission(...)` / `authenticatedRoute`) explicitly to every non-public endpoint; unannotated endpoints must fail closed with HTTP 401/403.
- **Canary Audit Contract**: Maintain `test/canary/rbac-contract.test.ts` to inspect every route registered on `router` programmatically and fail CI if any non-public route omits an authorization middleware.
