---
trigger: glob
globs: "**/*.js, **/*.mjs, **/*.cjs, **/package.json, **/pnpm-workspace.yaml"
description: Modern Node.js pure ESM standards, config pre-verification, Zod runtime validation, and zero-dependency built-in rules.
---

# Modern Node.js Execution Rules

## 1. Configuration Syntax Pre-Verification Mandate

- **Strict Requirement Before Modifying Configs**: Prior to writing or modifying any configuration files (`package.json`, `pnpm-workspace.yaml`, `.npmrc`, lockfiles, toolchain settings), agents MUST verify the exact schema and options:
  - Check current tool/runtime version: Run `vp toolchain` or inspect `engines.node` / dependencies.
  - Query live documentation: Check `https://viteplus.dev/llms-full.txt` or relevant official manuals.
  - NEVER guess syntax, package fields (e.g. `exports`, `imports`, `type`), or CLI flags from memory.

---

## 2. Environment Variables & Runtime Data Validation (Zod First)

- **Mandatory Validation for `process.env`**: Never use unvalidated environment variables or type casts:
  - ❌ `const port = Number(process.env.PORT) || 3000;`
  - ❌ `const secret = process.env.SECRET as string;`
- **Safe Zod Parsing**: Validate environment variables with Zod `safeParse` at process startup:
  ```ts
  import { z } from "zod";

  const EnvSchema = z.object({
    PORT: z.coerce.number().default(3000),
    NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
    DATABASE_URL: z.string().url(),
  });

  const parsedEnv = EnvSchema.safeParse(process.env);
  if (!parsedEnv.success) {
    console.error("Invalid environment variables:", parsedEnv.error.flatten());
    process.exitCode = 1;
    throw new Error("Environment configuration error");
  }
  export const env = parsedEnv.data;
  ```

---

## 3. Pure ESM & Module System

- **Pure ESM Only**: Always use pure ESM (`.mjs` or `"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`, `__filename`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g. `import fs from 'node:fs/promises'`).
- **Native Path Resolution**: Use native built-in `import.meta.dirname` and `import.meta.filename` instead of `fileURLToPath` workarounds.
- **Top-Level Await**: Use top-level `await` freely in ESM scripts without wrapper functions.

---

## 4. Zero-Dependency Built-In Tooling (Batteries-Included)

- **CLI Argument Parsing**: Always use `node:util` `parseArgs({ options, allowPositionals })`. Avoid `commander`, `yargs`, or `minimist`.
- **Terminal Styling & Colors**: Always use `node:util` `styleText('color', text)`. Avoid `chalk` or `colorette`.
- **File System Globbing**: Always use `node:fs/promises` `glob(pattern)`. Avoid `fast-glob` or `glob`.
- **Embedded Database**: Always use native `node:sqlite` (`DatabaseSync`) for local persistence instead of external native C-binding SQLite packages.
- **Native Web Standards**: Always use global `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`, `AbortController`. Avoid `axios`, `uuid`, `lodash`.
- **Unit Testing**: Always use native `node:test` and `node:assert/strict`.

---

## 5. Process & Execution Safety

- **Process Execution**: In `node:child_process`, prefer `execFileSync` or `spawnSync` with an array of arguments and `shell: false` to prevent shell injection.
- **Clean Exit**: Signal failure by setting `process.exitCode = 1` rather than abruptly calling `process.exit(1)`, allowing pending asynchronous streams and stdout/stderr buffers to flush cleanly.

---

## 6. Agent-Friendly Vite+ Execution Formats

When running Node.js or Vite+ package manager commands as an agent, use token-efficient structured formats:

- **Installed Packages**: `vp list --json` (or `vp pm list --json`)
- **Outdated Dependencies**: `vp outdated --format json`
- **Toolchain Status**: `vp toolchain --json`
- **Test Runner**: `vp test run --reporter=tap-flat --no-color` (or `vp test run --json`)
