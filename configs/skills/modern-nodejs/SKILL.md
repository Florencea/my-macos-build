---
name: modern-nodejs
description: Modern Node.js standards (Active LTS, pure ESM, zero-dependency built-ins) and Vite+ runtime integration for agentic development. Use when writing Node.js scripts, managing dependencies, configuring runtimes, or building CLI utilities.
compatibility: Node.js (Active LTS), Vite+
---

# Modern Node.js Guidelines

## 1. Native API Selection Decision Tree

When building Node.js CLI tools and scripts, prioritize zero-dependency native built-ins over third-party packages:

- **CLI Argument Parsing**:
  - Always use `node:util` `parseArgs({ options, allowPositionals })`.
  - Avoid `commander`, `yargs`, or `minimist`.
- **Terminal Styling & Colors**:
  - Always use `node:util` `styleText('color', text)`.
  - Avoid `chalk`, `picocolors`, or `colorette`.
- **File System Globbing**:
  - Always use `node:fs/promises` `glob(pattern)`.
  - Avoid `fast-glob` or `glob`.
- **Embedded Database**:
  - Always use native `node:sqlite` (`DatabaseSync`) for local persistence.
  - Avoid external native C-binding SQLite packages (`better-sqlite3`, `sqlite3`).
- **Standard Web Utilities**:
  - Always use native globals: `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`, `AbortController`.
  - Avoid `axios`, `node-fetch`, `uuid`, `lodash`.
- **Unit Testing & Assertions**:
  - Always use native `node:test` and `node:assert/strict`.

---

## 2. Modern Node.js Scripting Standards (Active LTS)

- **Module System**: Always use pure ESM (`.mjs` or `"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`, `__filename`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g., `import fs from 'node:fs/promises'`).
- **Path Resolution**: Use native built-in `import.meta.dirname` and `import.meta.filename` instead of `fileURLToPath` workarounds.
- **Top-Level Await**: Use top-level `await` freely in ESM scripts without wrapper functions.
- **Process & Execution Safety**: In `node:child_process`, prefer `execFileSync` or `spawnSync` with an array of arguments and `shell: false` to prevent shell injection. Signal failure by assigning `process.exitCode = 1` rather than abruptly calling `process.exit(1)`, allowing pending async streams and logs to flush.

---

## 3. Global Vite+ (`vp`) Toolchain Integration

- **Runtime Management**: Node.js runtimes (Active LTS, v24.x) are managed globally via Vite+ (`vp env default lts`, `vp env install lts`), eliminating manual tarball setups or NVM/asdf overhead.
- **Task Runner & Scripts**: All tasks and package scripts are managed via Vite+; prefer `vp run <task>` (or `vpr <task>`) for executing `package.json` scripts and workspace tasks with automatic task caching. Avoid `npm run`.
- **Binary Runner**: Prefer `vpx` (or `vpx -s <package-binary>`) over `npx` for executing uninstalled tools with zero delay and cached runtime resolution.
- **Deterministic Dependencies**: Use `vp install --lockfile-only` for fast lockfile generation and `vp install --frozen-lockfile` for deterministic CI and sandbox dependency restores.
- **Clean Automation Logging**: Set `VP_LOG=error` in non-interactive scripts or automated workflows to prevent `tracing_subscriber` diagnostic chatter from polluting stdout/stderr.

---

## 4. Authoritative Documentation & LLM References

When inspecting Node.js API syntax or runtime options, query these authoritative endpoints:

- **Node.js Official Documentation (v24 LTS)**:
  - API Index: `https://nodejs.org/docs/latest-v24.x/api/` (or `https://nodejs.org/docs/latest/api/`)
  - Submodules:
    - `parseArgs`: `https://nodejs.org/docs/latest-v24.x/api/util.html#utilparseargsconfig`
    - `styleText`: `https://nodejs.org/docs/latest-v24.x/api/util.html#utilstyletextformat-text-options`
    - `node:sqlite`: `https://nodejs.org/docs/latest-v24.x/api/sqlite.html`
    - `node:test`: `https://nodejs.org/docs/latest-v24.x/api/test.html`
- **Vite+ Toolchain Manual**:
  - Full LLM Manual: `https://viteplus.dev/llms-full.txt` (covers `vp env`, `vp run`, `vpr`, `vpx`)
  - Topic Index: `https://viteplus.dev/llms.txt`
