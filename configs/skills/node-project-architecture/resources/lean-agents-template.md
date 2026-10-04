<!--VITE PLUS START-->

## Vite+ Guidelines

This project uses Vite+ to manage development tools. Always use `vp` (or `vpr` shorthand for `vp run`) to run commands:

- `vpr <script>` (or `vp run <script>`): Run scripts from `package.json`
- `vp install`: Install dependencies
- `vp update`: Update dependencies
- `vp test`: Run Vitest tests
- `vp check`: Run linter, typecheck, format checks
- `vp fmt`: Run formatter
- `vp lint`: Run linter

<!--VITE PLUS END-->

# Agent Development Guidelines

Guidelines for AI agents and human contributors working on this repository.

## 1. Quick Architecture Map

| Layer               | Path                     | Responsibility                                          |
| :------------------ | :----------------------- | :------------------------------------------------------ |
| **Frontend UI**     | `src/client/components/` | Reusable React UI components                            |
| **Frontend Routes** | `src/client/routes/`     | TanStack Router file routes (protected route tree)      |
| **API Endpoints**   | `src/server/routes/`     | OpenAPI / RPC router, Zod schemas, and request handlers |
| **Database**        | `src/server/database/`   | Drizzle / SQLite schemas and seed fixtures              |
| **Domain Rules**    | `.agents/rules/`         | Modular glob-triggered domain rules                     |
| **Project Skills**  | `.agents/skills/`        | On-demand repeatable workflow runbooks                  |

---

## 2. Core SSOT & Architectural Invariants

- **Single Source of Truth (SSOT)**: Domain contracts and schemas are defined once (e.g. database schema or Zod DTOs) and inferred downstream. Never duplicate types manually.
- **Zod-First Boundary Defense**: Untrusted external data (API responses, JSON inputs, environment variables) MUST be validated using Zod (`safeParse`). Never use `as unknown as Type` assertions.
- **Zero Suppression Policy**: NEVER use `// @ts-ignore`, `// @ts-expect-error`, or `/* oxlint-disable */` to bypass errors. All type issues must be resolved through proper type narrowing or schema definitions.
- **Configuration Pre-Verification**: Before editing package or tool configuration files (`package.json`, `tsconfig*.json`, `vite.config.*`), inspect current versions and query official documentation or `llms.txt`. Never guess syntax from memory.
- **Protected Files**: Never manually edit auto-generated files (e.g. `routeTree.gen.ts`).

---

## 3. Frictionless Execution (Whitelist-First)

Prioritize `vpr agent:*` commands matching Antigravity's pre-approved execution whitelist:

- **Verification Gate**: `vpr agent:verify:gate` (unit -> build -> e2e)
- **Unit Verification**: `vpr agent:verify:unit` (inner loop + unit tests)
- **Inner Loop**: `vpr agent:verify:inner` (typecheck + lint)
- **Type Check**: `vpr agent:typecheck` (`tsc -b --pretty false`)
- **Lint & Fix**: `vpr agent:lint:fix` (`vp lint --fix`)
- **CI Lint**: `vpr agent:lint:ci` (`actionlint` 0 errors/warnings)
- **Unit Tests**: `vpr agent:test:unit` (`vp test run --reporter=tap-flat --no-color`)

---

## 4. Git Workflow & Commit Restrictions

- **NEVER execute `git commit` directly**: AI direct commits are prohibited.
- **Protocol**: Stage changes with `git add <files>` and output the exact `git commit -m "..."` command following Conventional Commits for manual execution by the user.

---

## 5. Language & Planning Standards

- **Traditional Chinese for Plans & Responses**: All implementation plans (`/plan`), walkthrough artifacts, design documents, and chat responses must strictly be written in **Traditional Chinese (繁體中文)**.
- **Code Artifacts**: Source code, inline comments, commit messages, and automated tests must use concise English.
