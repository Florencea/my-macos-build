---
name: modern-typescript
description: Strict TypeScript standards (TS 5+) and high-performance Oxlint + Oxfmt toolchain for agentic development. Use when writing, refactoring, or type-checking TypeScript code, configuring tsconfig or .oxlintrc.json, and resolving type errors.
compatibility: TypeScript 5+, Oxlint, Oxfmt, Vite+
---

# Strict TypeScript Guidelines

**🚨 AGENT INSTRUCTION (CRITICAL):** This project strictly enforces zero-warning `oxlint` linting, automated `oxfmt` formatting, and strict compiler checks (`tsc --noEmit`). You MUST write clean, type-safe TypeScript code that passes on the first attempt without regressions.

## 1. Type Safety & Linting Decision Tree

Before generating code, apply this decision tree to prevent linting failures:

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
  - The `any` type is STRICTLY FORBIDDEN. Use `unknown` and perform `typeof`, `instanceof`, or schema validation (e.g. Zod).

---

## 2. High-Performance Oxlint & Oxfmt Toolchain

Modern agentic projects eliminate legacy ESLint and Prettier overhead in favor of Rust-powered tools:

- **Oxlint Integration (`vp lint` / `vpx oxlint`)**: Oxlint analyzes TypeScript ASTs up to 50–100x faster than ESLint. It catches syntax errors, bad idioms, and security vulnerabilities without blocking development loops.
- **Agent Output Format (`--format=agent`)**: When verifying code in agentic loops, use the dedicated agent reporter:
  ```bash
  npx oxlint --deny-warnings --format=agent
  ```
- **Type Checking Decoupling (`tsc --noEmit`)**: Oxlint performs fast static linting; full type validation is handled separately by `tsc --noEmit` (or `vp check`). This decoupling avoids AST bridge bottlenecks and ensures seamless compatibility with modern TypeScript compiler generations.
- **Oxfmt Automated Formatting (`vpx oxfmt` / `vp fmt`)**: Replaces Prettier completely. Runs instantly and enforces consistent styling:
  - Format in-place: `vpx oxfmt` (or `vp fmt`)
  - Check formatting without editing: `vpx oxfmt --check`
  - Migrate Prettier configuration: `vpx oxfmt --migrate prettier`
- **Configuration (`.oxlintrc.json`)**: Use standard JSON configuration when custom rule overrides are needed:
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

## 3. Modern Idiomatic TypeScript

- **Consistent Type Imports**: Enforce `import type { ... }` for type-only imports to support `verbatimModuleSyntax`.
- **Discriminated Unions**: Model domain states using discriminated unions with a common discriminator tag (e.g., `type: 'success' | 'error'`) rather than sprawling optional properties (`a?: string; b?: number;`).
- **Exhaustive Pattern Matching**: Ensure all cases of a union are handled using exhaustive `switch` checks or a helper like `assertNever(x: never): never`.
- **Safe Control Flow & Error Handling**: Caught errors are `unknown`. Always inspect before reading: `const message = err instanceof Error ? err.message : String(err)`.

---

## 4. Authoritative Documentation & LLM References

When agents need rule definitions or compiler option references, query these authoritative endpoints:

- **Oxc & Oxlint Official Reference**:
  - Oxc LLM Full Reference: `https://oxc.rs/llms.txt`
  - Oxlint Official Documentation: `https://oxc.rs/docs/guide/usage/linter.html`
  - Oxlint Rules Manual: `https://oxc.rs/docs/guide/usage/linter/rules.html`
  - Oxfmt Formatter Guide: `https://oxc.rs/docs/guide/usage/formatter.html`
  - Coding Agents Guide: `https://oxc.rs/docs/guide/usage/coding-agents.md`
- **TypeScript Official Reference**:
  - Documentation: `https://www.typescriptlang.org/docs/`
  - TSConfig Options: `https://www.typescriptlang.org/tsconfig/`
