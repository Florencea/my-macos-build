---
trigger: glob
globs: "**/*.js, **/*.mjs, **/*.cjs, **/package.json"
description: Modern Node.js pure ESM standards and zero-dependency built-in rules.
---

# Modern Node.js Execution Rules

## 1. Pure ESM & Module System

- **Pure ESM Only**: Always use pure ESM (`.mjs` or `"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`, `__filename`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g. `import fs from 'node:fs/promises'`).
- **Native Path Resolution**: Use Node 20.11+ built-in `import.meta.dirname` and `import.meta.filename` instead of `fileURLToPath` workarounds.
- **Top-Level Await**: Use top-level `await` freely in ESM scripts without wrapper functions.

---

## 2. Zero-Dependency Built-In Tooling (Batteries-Included)

- **CLI Argument Parsing**: Always use `node:util` `parseArgs({ options, allowPositionals })`. Avoid `commander`, `yargs`, or `minimist`.
- **Terminal Styling & Colors**: Always use `node:util` `styleText('color', text)`. Avoid `chalk` or `colorette`.
- **File System Globbing**: Always use `node:fs/promises` `glob(pattern)`. Avoid `fast-glob` or `glob`.
- **Embedded Database**: Always use native `node:sqlite` (`DatabaseSync`) for local persistence instead of external native C-binding SQLite packages.
- **Native Web Standards**: Always use global `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`, `AbortController`. Avoid `axios`, `uuid`, `lodash`.
- **Unit Testing**: Always use native `node:test` and `node:assert/strict`.

---

## 3. Process & Execution Safety

- **Process Execution**: In `node:child_process`, prefer `execFileSync` or `spawnSync` with an array of arguments and `shell: false` to prevent shell injection.
- **Clean Exit**: Signal failure by setting `process.exitCode = 1` rather than abruptly calling `process.exit(1)`, allowing pending asynchronous streams and stdout/stderr buffers to flush cleanly.
