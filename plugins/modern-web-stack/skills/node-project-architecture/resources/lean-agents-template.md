# Agent Development Guidelines

Project-specific architecture, domain invariants, and verification commands. Universal principles, CLI rules, and communication standards are inherited from `common-modern-tools` and `modern-web-stack`.

## 1. Architecture Map

- `src/`: Application source modules (list concrete subdirectories and responsibilities here)
- `test/`: Unit and browser E2E test suites
- `.agents/rules/`: Glob-triggered domain rules specific to this repository
- `.agents/skills/`: On-demand repository runbooks (if needed)

---

## 2. Project Domain Invariants

- **Single Source of Truth (SSOT)**: State concrete data, schema, and styling token owners for this repository.
- **Explicit Architecture**: No experimental compiler previews, wrapper CLIs, or auto-generated black-box files.
- **Supply-Chain & Cooldown Governance**: Maintain strict `.npmrc` settings; batch toolchain updates quarterly/semi-annually with a 7-14 day cooldown and prioritize runtime CVEs (`npm audit --omit=dev`). Run `npx knip` on demand.

---

## 3. Shared Verification & Workflow Commands

Humans and agents share the same standard `npm run` scripts:

- **Inner-Loop Static Checks**: `npm run typecheck && npm run lint && npm run format:check`
- **Auto-Fix**: `npm run lint:fix && npm run format`
- **Tests**: `npm run test:unit` / `npm run test:e2e` (append `-- --reporter=tap-flat --no-color` for compact output)
- **Production Build**: `npm run build`
- **Full Verification Gate (DoD)**: `npm run verify`
- **CI Workflow Lint**: `actionlint` (run locally after editing `.github/workflows/*.yml`)

---

## 4. Git Workflow Restrictions

- Never execute `git commit` or `git push` directly (local commits use interactive signing). Stage verified files with `git add <files>` and output the `git commit -m "..."` command in English for manual execution.
