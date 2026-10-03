---
name: modern-nodejs
description: Modern Node.js standards (Node 22/24+, pure ESM, zero-dependency built-ins) for Agentic Development
trigger: always_on
---

# Modern Node.js Guidelines

## 1. Modern Node.js Scripting (Node 22/24+ LTS)

- **Module System**: Always use pure ESM (`.mjs` or `"type": "module"`). Never write CommonJS (`require`, `module.exports`, `__dirname`, `__filename`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g., `import fs from 'node:fs/promises'`).
- **Path Resolution**: Use Node 20.11+ built-in `import.meta.dirname` and `import.meta.filename` instead of `fileURLToPath` hacks.
- **Top-Level Await**: Use top-level `await` freely in ESM scripts without wrapping.
- **Zero-Dependency CLI First (Batteries-Included)**:
  - **CLI Arguments**: Use `node:util` `parseArgs({ options, allowPositionals })`. Avoid external packages like `commander`, `yargs`, or `minimist`.
  - **Terminal Styling**: Use `node:util` `styleText('color', text)`. Avoid `chalk` or `colorette`.
  - **File Globbing**: Use `node:fs/promises` `glob(pattern)`. Avoid `fast-glob` or `glob`.
  - **Native Web APIs**: Use native global `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`, `AbortController`. Avoid `axios`, `node-fetch`, `uuid`, `lodash`.
  - **Embedded Database**: Use native `node:sqlite` (`DatabaseSync`) for local persistence instead of external native SQLite bindings.
  - **Testing**: Use native `node:test` and `node:assert/strict`.
- **Process & Execution Safety**: In `node:child_process`, prefer `execFileSync` or `spawnSync` with an array of arguments and `shell: false` to prevent shell injection. Signal failure by assigning `process.exitCode = 1` rather than abruptly calling `process.exit(1)`, allowing pending async streams/logs to flush.

## 2. Global Vite+ (`vp`) Toolchain Integration

- **Runtime Management**: Node.js runtimes (Active LTS) are managed globally via Vite+ (`vp env default lts`, `vp env install lts`), eliminating manual tarball setups or NVM/asdf overhead.
- **Task Runner & Scripts**: Prefer `vp run <task>` (or `vpr <task>`) for executing `package.json` scripts and workspace tasks with automatic task caching.
- **Binary Runner**: Prefer `vpx -s <package-binary>` over `npx` for executing uninstalled tools with zero delay and cached runtime resolution.
- **Deterministic Dependencies**: Use `vp install --lockfile-only` for fast lockfile generation and `vp install --frozen-lockfile` for deterministic CI and sandbox dependency restores.
- **Clean Automation Logging**: Set `VP_LOG=error` in non-interactive scripts or automated workflows to prevent `tracing_subscriber` diagnostic chatter from polluting stdout/stderr.
