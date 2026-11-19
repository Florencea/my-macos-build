---
name: modern-nodejs
description: Modern Node.js pure ESM rules, strict .npmrc policies, two-stage llms.txt doc lookups, fnm/npm commands (npm pkg, npm ci, npx), and Zod validation. Use when writing Node.js scripts, CLIs, or managing packages.
compatibility: Node.js (Active LTS), fnm, npm, Zod, ESLint, Prettier
---

# Modern Node.js Guidelines

## 1. External SSOT & Anti-Pattern Gateways

Verify live Node.js APIs and active linter anti-patterns before authoring scripts or configurations:

- **Node.js Official API (Two-Stage `curl -fsSL`)**:
  - Stage 1 (Index): `curl -fsSL https://nodejs.org/llms.txt | head -n 120`
  - Stage 2 (Module Markdown): `curl -fsSL https://nodejs.org/docs/latest/api/<module>.md` (e.g. `sqlite.md`, `util.md`, `test.md`, `fs.md`)
- **Package Inspection & Verification (`npm` / `npx`)**:
  - Dependency checks: `npm ls --json`, `npm outdated --json`.
  - Formatting & verification: `npx prettier --write <files>`, `npx eslint --format compact`, `npm test`.
  - Runner roles: `npm run <script>` runs `package.json` scripts; `npx <pkg>` executes local or remote binaries; `node <file.ts|mjs>` runs ESM and native erasable TypeScript directly.
- **ESLint Node & ESM Anti-Patterns**:
  - Inspect enabled rules locally: `npx eslint --print-config <file>` and `eslint.config.*`.
  - Retrieve exact rule rationale and examples: `https://eslint.org/docs/latest/rules/` and `https://typescript-eslint.io/rules/`.

---

## 2. Strict `.npmrc` Security & Supply-Chain Policy

Global and project `.npmrc` configurations enforce deterministic, supply-chain-safe installs:

```ini
audit=false
engine-strict=true
fund=false
ignore-scripts=true
install-strategy=linked
save-exact=true
strict-peer-deps=true
```

- Always use `npm ci` in CI and clean syncs; update `package.json` + `package-lock.json` cleanly via `npm install`.
- Because `ignore-scripts=true` blocks arbitrary postinstall scripts, execute required binary setup (such as Playwright Chromium download) through explicit scripts like `npm run test:setup`.

---

## 3. Zero-Dependency Native Selection Tree

Prioritize Node.js built-ins over third-party dependencies, verifying exact exports in `nodejs.org/docs/latest/api/<module>.md` before use:

- CLI argument parsing and terminal styling -> `node:util`
- File system globbing and async I/O -> `node:fs/promises`
- Embedded SQLite storage -> `node:sqlite`
- Standard Web Globals -> `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`
- Unit testing and assertions -> `node:test` and `node:assert/strict` (or `vitest`)
- Environment loading -> `process.loadEnvFile()`

---

## 4. Native Manifest Operations (`npm pkg`)

Manage `package.json` through native `npm pkg` commands:

- Inspect: `npm pkg get <key>`
- Mutate: `npm pkg set <key>=<value>` (pass `--json` for arrays/objects/booleans)
- Remove: `npm pkg delete <key>`
- Standardize & normalize: `npm pkg fix`

STRICTLY FORBIDDEN to rewrite `package.json` with raw regex replacements or `jq` file swaps.

---

## 5. Cross-Platform Portability & Process Safety Invariants

- **Pure ESM & `node:` Protocol**: Require `"type": "module"`, prohibit CommonJS (`require`, `module.exports`, `__dirname`), prefix all built-ins with `node:`, and resolve paths relative to `import.meta.dirname` or `fileURLToPath(import.meta.url)`.
- **Path & Glob Composition**: Use `node:path` (`path.join()`, `path.resolve()`, `path.relative()`). Never concatenate paths with `+ '/' +`. Enforce POSIX `/` in glob strings (`pattern.replace(/\\/g, "/")`).
- **Cross-Platform `package.json` Scripts**: Prohibit OS-specific shell builtins (`rm -rf`, `export`, `set`, `mkdir -p`); use Node.js one-liners (`node -e "fs.rmSync('dist', { recursive: true, force: true })"`).
- **Process & Stdin Safety**: Invoke subprocesses via `execFileSync` or `spawnSync` with argument arrays and `{ shell: false }`. Prefer `process.exitCode = 1` over `process.exit(1)`. Never block waiting for stdin in non-interactive automation.
