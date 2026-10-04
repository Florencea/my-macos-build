---
name: modern-typescript
description: Strict TypeScript standards (TS 5+), zero suppression directives, Zod runtime validation, and high-performance Oxlint + Oxfmt toolchain for agentic development. Use when writing, refactoring, or type-checking TypeScript code, configuring tsconfig or .oxlintrc.json, and resolving type errors.
compatibility: TypeScript 5+, Oxlint, Oxfmt, Vite+, Zod
---

# Strict TypeScript Guidelines

**🚨 AGENT INSTRUCTION (CRITICAL):** This project strictly enforces zero-warning `oxlint` linting, automated `oxfmt` formatting, and strict compiler checks (`tsc --noEmit`). You MUST write clean, type-safe TypeScript code that passes on the first attempt without regressions.

---

## 1. Type Safety & Linting Decision Tree

Before writing or refactoring TypeScript code, apply this decision tree to prevent defects:

- **Handling Boundary / Untrusted Data (API, JSON, Env, Files)**:
  - ❌ NEVER cast with `as unknown as Type` or raw `as Type`.
  - ✅ Define a Zod schema and run `schema.safeParse(data)`. Infer the type via `z.infer<typeof schema>`.
- **Handling Diagnostics & Lint Errors**:
  - ❌ NEVER suppress with `// @ts-ignore`, `// @ts-expect-error`, or `/* oxlint-disable */`.
  - ❌ NEVER downgrade rules or add global ignores in configuration files.
  - ✅ Narrow types with control flow (`typeof`, `instanceof`, `in`), use discriminated unions, or adjust type declarations.
- **Conditionals & Truthiness**:
  - Always evaluate explicit boolean values (`strict-boolean-expressions`).
  - ❌ `if (str)` / `if (arr.length)` / `if (obj)`
  - ✅ `if (str !== '')` / `if (arr.length > 0)` / `if (obj !== null)`
- **Map Lookups**:
  - Perform a single `.get()` and check against `undefined`. NEVER use `Map.has()` followed by `Map.get()`.
  - ❌ `if (map.has(key)) { const v = map.get(key); }`
  - ✅ `const v = map.get(key); if (v !== undefined) { ... }`
- **Type Modeling (Static vs Dynamic)**:
  - Static configs, mock data, known keys $\rightarrow$ `satisfies Type` (validates shape while preserving narrow literal inference).
  - Dynamic maps, API dictionaries $\rightarrow$ `: Record<K, V>` or `Map<K, V>` (widens type so defensive `undefined` checks are required).
- **Template Literals**:
  - Only interpolate primitive types (`string`, `number`, `boolean`).
  - Explicitly convert complex objects or arrays using `JSON.stringify(...)` or custom formatters.
- **Async Execution & Promises**:
  - ALL promises must be awaited, returned, or explicitly marked with `void` (`no-floating-promises`).
- **Null Safety**:
  - NEVER use the non-null assertion operator (`!`). Handle `null`/`undefined` via control flow, `?.`, or `??`.
- **Unknown vs Any**:
  - The `any` type is STRICTLY FORBIDDEN. Use `unknown` and perform runtime schema validation (Zod) or narrow with guards.

---

## 2. Anti-Patterns & Positive Refactoring Guide

### Anti-Pattern 1: Bypassing Errors via Suppression Directives

- **❌ Violation**:
  ```ts
  // @ts-ignore: bypass type error
  const id = user.profile.id;

  // oxlint-disable-next-line
  if (data) process(data);
  ```
- **✅ Positive Refactoring**:
  ```ts
  // Use optional chaining and explicit truthiness check
  const id = user.profile?.id;
  if (id !== undefined) {
    process(id);
  }
  ```

### Anti-Pattern 2: Type Smuggling via `as unknown as Type`

- **❌ Violation**:
  ```ts
  // DANGEROUS: Type system is bypassed; crashes at runtime if schema changes
  const payload = (await res.json()) as unknown as UserPayload;
  ```
- **✅ Positive Refactoring with Zod**:
  ```ts
  import { z } from "zod";

  export const UserPayloadSchema = z.object({
    id: z.string().uuid(),
    username: z.string().min(1),
    email: z.string().email(),
    roles: z.array(z.string()).default([]),
  });

  export type UserPayload = z.infer<typeof UserPayloadSchema>;

  const rawJson: unknown = await res.json();
  const result = UserPayloadSchema.safeParse(rawJson);

  if (!result.success) {
    // Graceful error reporting with structured field issues
    console.error("Payload validation failed:", result.error.flatten());
    throw new Error("Invalid user payload received from API");
  }

  const payload: UserPayload = result.data; // Fully safe, zero assertions
  ```

---

## 3. High-Performance Oxlint & Vite+ Toolchain

Modern agentic workflows eliminate ESLint and Prettier overhead in favor of Rust-powered tools:

- **Agent Output Format (`vp lint -f agent` / `vpx oxlint -f agent`)**:
  - When verifying code in agentic execution loops, always use the dedicated `agent` reporter:
    ```bash
    vp lint -f agent
    ```
  - This outputs token-efficient, simplified diagnostics (`file:line:col: error rule: message`) without decorative frames or ANSI codes.
- **Type Checking (`tsc -b --pretty false` / `tsc --noEmit --pretty false`)**:
  - Pass `--pretty false` to suppress color codes and decorative ASCII formatting:
    ```bash
    tsc -b --pretty false
    ```
- **Quiet Check (`vp check --quiet`)**:
  - When running combined formatting, linting, and type checking, pass `--quiet` to suppress warnings and highlight only critical errors:
    ```bash
    vp check --quiet
    ```
- **Oxfmt Automated Formatting (`vpx oxfmt` / `vp fmt`)**:
  - Format in-place: `vpx oxfmt <file>` (or `vp fmt`)
  - Check formatting without editing: `vpx oxfmt --check`
- **All-in-One Configuration (`vite.config.ts`)**:
  - In modern Vite+ repositories, declare `lint` and `fmt` directly inside `vite.config.ts` instead of managing duplicate configuration files (`.oxlintrc.json`, `.prettierignore`):
    ```ts
    import { defineConfig } from "vite-plus";

    export default defineConfig({
      lint: {
        ignorePatterns: ["dist/**", ".cache/**", "test-results/**"],
        options: {
          typeAware: true,
          typeCheck: true,
        },
        categories: {
          correctness: "error",
          suspicious: "error",
          perf: "error",
        },
        plugins: ["react", "unicorn", "typescript", "oxc", "vitest"],
      },
      fmt: {
        ignorePatterns: ["dist/**", "pnpm-lock.yaml"],
        sortPackageJson: true,
      },
    });
    ```
- **Vitest Browser Projects Testing**:
  - Write browser tests using `vite-plus/test` and Vitest Projects (`browser.provider = playwright()`). Run via `vp test run --project <name> --reporter=tap-flat --no-color`.
- **Legacy Standalone Configuration (`.oxlintrc.json`)**:
  - Standalone JSON configuration remains supported for non-Vite+ repos or standalone toolchain setups:
    ```json
    {
      "$schema": "./node_modules/oxlint/configuration_schema.json",
      "plugins": ["typescript", "unicorn"],
      "rules": {
        "typescript/no-explicit-any": "error",
        "typescript/consistent-type-imports": "error"
      }
    }
    ```

---

## 4. Configuration Syntax Pre-Verification Mandate

Before modifying or creating any configuration files (`tsconfig.json`, `tsconfig.*.json`, `.oxlintrc.json`), agents MUST query official live references. Guessing compiler options or lint rule names from pre-training memory is strictly prohibited:

- **TypeScript TSConfig Reference**:
  - Documentation: `https://www.typescriptlang.org/docs/`
  - TSConfig Options: `https://www.typescriptlang.org/tsconfig/`
- **Oxc & Oxlint Reference**:
  - Oxc LLM Full Reference: `https://oxc.rs/llms.txt`
  - Oxlint Rules Manual: `https://oxc.rs/docs/guide/usage/linter/rules.html`
  - Coding Agents Guide: `https://oxc.rs/docs/guide/usage/coding-agents.md`

---

## 5. Modern Idiomatic TypeScript

- **Consistent Type Imports**: Enforce `import type { ... }` for type-only imports to support `verbatimModuleSyntax`.
- **Discriminated Unions**: Model domain states using discriminated unions with a common discriminator tag (e.g. `type: 'success' | 'error'`) rather than sprawling optional properties (`a?: string; b?: number;`).
- **Exhaustive Pattern Matching**: Ensure all cases of a union are handled using exhaustive `switch` checks or a helper like `assertNever(x: never): never`.
- **Safe Control Flow & Error Handling**: Caught errors are `unknown`. Always inspect before reading: `const message = err instanceof Error ? err.message : String(err)`.
