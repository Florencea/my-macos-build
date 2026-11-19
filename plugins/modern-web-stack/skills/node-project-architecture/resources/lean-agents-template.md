# Agent Development Guidelines

Project-specific architecture, verification gates, and delivery constraints. Global CLI, formatting, and communication standards are inherited from `common-modern-tools`.

## 1. Architecture Map

- `src/client/components/`: Reusable React UI components
- `src/client/routes/`: TanStack Router file routes (protected route tree)
- `src/server/routes/`: OpenAPI / RPC router, Zod schemas, and request handlers
- `src/server/database/`: Drizzle / SQLite schemas and seed fixtures
- `.agents/rules/`: Modular glob-triggered domain rules
- `.agents/skills/`: On-demand repeatable workflow runbooks

---

## 2. Core SSOT & Architectural Invariants

- **Single Source of Truth (SSOT)**: Define domain contracts and schemas once (database schema or Zod DTOs) and infer downstream. Never duplicate entity types manually.
- **Zod-First & Zero Suppression**: Validate untrusted external boundaries via Zod `safeParse`. Prohibit `as unknown as`, `// @ts-ignore`, `// @ts-expect-error`, and `/* oxlint-disable */`.
- **Pre-Edit Tool Verification**: Before editing `package.json`, `tsconfig*.json`, or `vite.config.*`, inspect `npx oxlint --rules`, `npx oxlint --print-config`, local `.d.ts` files, and two-stage `llms.txt` -> `.md` docs via `curl -fsSL`.
- **Strict `.npmrc` Policy**: Keep `ignore-scripts=true`, `save-exact=true`, `install-strategy=linked`, `strict-peer-deps=true`, and `engine-strict=true` in `.npmrc` to prevent upstream drift and postinstall script execution.
- **Protected Generated Files**: Never edit auto-generated files such as `src/routeTree.gen.ts`.

---

## 3. Execution & Verification Shortcuts

- **Gate**: `npm run agent:verify:gate` (`unit` -> `build` -> `e2e`) or `npm run verify`
- **Inner Loop**: `npm run agent:verify:inner` (`typecheck` -> `oxlint` -> `lint:tailwind`)
- **Tests**: `npm run agent:test:unit` and `npm run agent:test:e2e` (`--reporter=tap-flat --no-color`)
- **Diagnostics & Formatting**: `npx oxlint -f agent`, `npx oxfmt <files>`, `npm run lint:ci` (`actionlint`), `npm ls --json`

---

## 4. Git Workflow & Commit Restrictions

- Never execute `git commit` or `git push`. Stage verified, formatted files with `git add <files>` and output the Conventional Commit command (`git commit -m "..."`) for manual execution.
