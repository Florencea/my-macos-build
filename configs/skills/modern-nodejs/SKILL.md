---
name: modern-nodejs
description: Modern Node.js standards (Active LTS, pure ESM, zero-dependency built-ins), config pre-verification, Zod runtime validation, and Vite+ runtime integration for agentic development. Use when writing Node.js scripts, managing dependencies, configuring runtimes, or building CLI utilities.
compatibility: Node.js (Active LTS), Vite+, Zod
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

## 2. Configuration Syntax Pre-Verification Mandate

> [!CRITICAL]
> **Strict Verification Before Editing Configuration Files**: Node.js ecosystem configurations (`package.json`, `pnpm-workspace.yaml`, `.npmrc`, conditional export maps) change rapidly between major versions. Agents must never configure these files using pre-training memory alone.

### Verification Workflow:

1. **Detect Tool & Runtime Generation**:
   - Inspect active versions: Run `vp toolchain` or check `engines.node` in `package.json`.
2. **Query Official Reference Endpoints**:
   - Package manager / Vite+: `https://viteplus.dev/llms-full.txt`
   - Node.js APIs: `https://nodejs.org/docs/latest-v24.x/api/`
3. **Verify CLI Syntax**:
   - Run `<tool> --help` to confirm CLI flags before executing non-standard commands.

---

## 3. Zod-First Runtime Validation (Env & Boundary Inputs)

Never assume `process.env` or external JSON input contains correct types or defined values. Always parse with Zod `safeParse`:

```ts
import { z } from "zod";

const EnvSchema = z.object({
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  DATABASE_URL: z.string().url(),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
});

export type Env = z.infer<typeof EnvSchema>;

const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
  console.error("Invalid environment variables:\n", parsed.error.flatten());
  process.exitCode = 1;
  throw new Error("Environment configuration error");
}

export const env: Env = parsed.data;
```

---

## 4. Modern Node.js Scripting Standards (Active LTS)

- **Module System**: Always use pure ESM (`.mjs` or `"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`, `__filename`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g., `import fs from 'node:fs/promises'`).
- **Path Resolution**: Use native built-in `import.meta.dirname` and `import.meta.filename` instead of `fileURLToPath` workarounds.
- **Top-Level Await**: Use top-level `await` freely in ESM scripts without wrapper functions.
- **Process & Execution Safety**: In `node:child_process`, prefer `execFileSync` or `spawnSync` with an array of arguments and `shell: false` to prevent shell injection. Signal failure by assigning `process.exitCode = 1` rather than abruptly calling `process.exit(1)`, allowing pending async streams and logs to flush.

---

## 5. Global Vite+ (`vp`) Toolchain & Agent-Friendly Output Formats

All Node.js runtimes and tasks are managed via Vite+ (`vp`). When executing tools in agent workflows, use token-efficient formats:

| Task / Domain          | Standard Command | Agent-Friendly Format                        | Purpose                                              |
| :--------------------- | :--------------- | :------------------------------------------- | :--------------------------------------------------- |
| **Linting**            | `vp lint`        | `vp lint -f agent`                           | Minimalist error-location format without ANSI frames |
| **Combined Check**     | `vp check`       | `vp check --quiet`                           | Suppresses cosmetic warnings, only outputs errors    |
| **Installed Packages** | `vp list`        | `vp list --json`                             | Machine-readable dependency graph                    |
| **Outdated Packages**  | `vp outdated`    | `vp outdated --format json`                  | Structured upgrade candidate inspection              |
| **Toolchain Graph**    | `vp toolchain`   | `vp toolchain --json`                        | Detailed active toolchain JSON report                |
| **Test Execution**     | `vp test`        | `vp test run --reporter=tap-flat --no-color` | Linear TAP flat output, eliminates spinners          |

- **Clean Automation Logging**: Set `VP_LOG=error` in non-interactive scripts to prevent `tracing_subscriber` diagnostic logs from cluttering output.
- **Deterministic Dependencies**: Use `vp install --frozen-lockfile` in CI / automated verification runs.

---

## 6. Authoritative Documentation & LLM References

When inspecting Node.js API syntax or runtime options, query these authoritative endpoints:

- **Node.js Official Documentation (v24 LTS)**:
  - API Index: `https://nodejs.org/docs/latest-v24.x/api/` (or `https://nodejs.org/docs/latest/api/`)
  - `parseArgs`: `https://nodejs.org/docs/latest-v24.x/api/util.html#utilparseargsconfig`
  - `styleText`: `https://nodejs.org/docs/latest-v24.x/api/util.html#utilstyletextformat-text-options`
  - `node:sqlite`: `https://nodejs.org/docs/latest-v24.x/api/sqlite.html`
  - `node:test`: `https://nodejs.org/docs/latest-v24.x/api/test.html`
- **Vite+ Toolchain Manual**:
  - Full LLM Manual: `https://viteplus.dev/llms-full.txt` (covers `vp env`, `vp run`, `vpr`, `vpx`, package manager flags)
  - Topic Index: `https://viteplus.dev/llms.txt`
