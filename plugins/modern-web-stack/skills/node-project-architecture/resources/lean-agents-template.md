<!--VITE PLUS START-->

## Vite+ Guidelines

This project uses Vite+ to manage development tools. Always use `vp` (or `vpr` shorthand for `vp run`) to run commands:

- `vpr <script>` (or `vp run <script>`): Run scripts from `package.json`
- `vp install`: Install dependencies
- `vp update`: Update dependencies
- `vp test`: Run Vitest tests
- `vp build`: Build production bundles
- `vp check`: Run linter, typecheck, format checks
- `vp fmt`: Run formatter
- `vp lint`: Run linter

<!--VITE PLUS END-->

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
- **Pre-Edit Tool Verification**: Before editing `package.json`, `pnpm-workspace.yaml`, `tsconfig*.json`, or `vite.config.*`, inspect `vp lint --rules`, `vp lint --print-config`, local `.d.ts` files, and two-stage `llms.txt` -> `.md` docs.
- **Dependency Version Pinning**: Keep `saveExact: true` in `pnpm-workspace.yaml` to prevent upstream version drift.
- **Protected Generated Files**: Never edit auto-generated files such as `src/routeTree.gen.ts`.

---

## 3. Execution & Verification Shortcuts

- **Gate**: `vpr agent:verify:gate` (`unit` -> `build` -> `e2e`) or `vpr verify`
- **Inner Loop**: `vpr agent:verify:inner` (`vpr typecheck && vp lint && vpr lint:tailwind`)
- **Tests**: `vpr agent:test:unit` and `vpr agent:test:e2e` (`--reporter=tap-flat --no-color`)
- **Diagnostics & Formatting**: `vp lint -f agent`, `vp fmt <files>`, `vpr lint:ci` (`actionlint`), `vp list --json`
- **Task Caching**: Inspect Vite+ task cache status with `vpr --last-details`, or bypass with `vpr --no-cache` / `vp cache clean`.

---

## 4. Git Workflow & Commit Restrictions

- Never execute `git commit` or `git push`. Stage verified, formatted files with `git add <files>` and output the Conventional Commit command (`git commit -m "..."`) for manual execution.
