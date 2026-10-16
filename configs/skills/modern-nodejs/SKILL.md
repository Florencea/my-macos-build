---
name: modern-nodejs
description: Modern Node.js pure ESM standards, config pre-verification, Zod runtime validation, and zero-dependency built-in rules. Use when writing Node.js scripts, managing dependencies, configuring runtimes, or building CLI utilities.
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

## 2. Pre-Execution Config Verification & Native Manifest Operations

- **Pre-Verification Mandate**: Before authoring or updating configuration files (`package.json`, `pnpm-workspace.yaml`, toolchain settings), query authoritative endpoints:
  - Toolchain Status: Run `vp toolchain` to inspect runtime version and active tools dynamically.
  - Live Documentation: Run `webread --llms https://viteplus.dev` (or query `https://viteplus.dev/llms-full.txt`).
  - NEVER guess syntax, package fields, or flags from outdated memory.
- **Unified Vite+ Toolchain Mandate**:
  - Always use `vp`, `vpx`, and `vpr` across all Node.js projects.
  - STRICTLY PROHIBITED to invoke package-manager specific runners (`npx`, `pnpm dlx`, `bunx`, `npm run`).
  - One-off tool execution: `vpx <tool>` (e.g. `vpx oxlint`, `vpx oxfmt`).
  - Script execution: `vpr <script>` (or `vp run <script>`).
  - Dependency management: `vp install`, `vp update`, `vp add`, `vp remove`.
- **Native Manifest Operations (`vp pm pkg`)**:
  - Querying fields: `vp pm pkg get <key>` (or `vp -C <dir> pm pkg get <key>`)
  - Mutating fields: `vp pm pkg set <key>=<value>` (use `--json` for objects/booleans/arrays)
  - Removing fields: `vp pm pkg delete <key>`
  - Standardizing & fixing: `vp pm pkg fix`
  - STRICTLY FORBIDDEN to use raw regex replacements or `jq` intermediate file swapping (`package.json.tmp && mv`).

---

## 3. Zod-First Boundary Validation Pattern

Validate environment variables and untrusted runtime inputs with Zod schemas:

```ts
import { z } from "zod";

const ConfigSchema = z.object({
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  DATABASE_URL: z.string().url(),
});

const parsed = ConfigSchema.safeParse(process.env);
if (!parsed.success) {
  console.error("Configuration error:", parsed.error.flatten());
  process.exitCode = 1;
  throw new Error("Invalid environment configuration");
}
export const config = parsed.data;
```

---

## 4. Native Built-In Usage Examples

### Native CLI Argument Parsing (`node:util`):

```ts
import { parseArgs } from "node:util";

const { values, positionals } = parseArgs({
  options: {
    verbose: { type: "boolean", short: "v", default: false },
    output: { type: "string", short: "o" },
  },
  allowPositionals: true,
});
```

### Native Terminal Colors (`node:util`):

```ts
import { styleText } from "node:util";

console.log(styleText("green", "✔ Operation completed successfully"));
console.log(styleText(["bold", "red"], "✖ Fatal error encountered"));
```

### Native SQLite Persistence (`node:sqlite`):

```ts
import { DatabaseSync } from "node:sqlite";

const db = new DatabaseSync("app.db");
db.exec(`
  CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    value REAL NOT NULL
  )
`);
const insert = db.prepare("INSERT INTO metrics (name, value) VALUES (?, ?)");
insert.run("cpu_usage", 42.5);
```

### Native File Globbing (`node:fs/promises`):

```ts
import { glob } from "node:fs/promises";

for await (const entry of glob("src/**/*.ts")) {
  console.log("Found:", entry);
}
```
