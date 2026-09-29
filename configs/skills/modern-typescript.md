---
name: modern-typescript
description: Strict TypeScript standards (TS V6/V7) and typescript-eslint best practices for Agentic Development
trigger: always_on
---

# Strict TypeScript Guidelines

**🚨 AGENT INSTRUCTION (CRITICAL):** This project strictly enforces `@typescript-eslint/strictTypeChecked` and `@typescript-eslint/stylisticTypeChecked`. You MUST write code that passes these strict linting rules on the first attempt to avoid wasting development cycles.

## 1. Strict & Stylistic TypeScript Rules (CRITICAL)

To pass `strictTypeChecked` and `stylisticTypeChecked`, you MUST adhere to the following rules in your code generation:

- **Strict Boolean Expressions**: NEVER evaluate non-boolean values in `if` or conditional expressions.
  - ❌ `if (str)` / `if (arr.length)` / `if (obj)`
  - ✅ `if (str !== '')` / `if (arr.length > 0)` / `if (obj !== null)`
- **No Double Map Lookups (Avoid Anti-pattern)**: NEVER use `Map.has(key)` followed by `Map.get(key)`. `Map.has()` does not narrow types in TypeScript, leaving `Map.get()` to return `T | undefined`. Perform a single `.get()` and explicitly check for `!== undefined`.
  - ❌ `if (map.has(key)) { const v = map.get(key); }`
  - ✅ `const v = map.get(key); if (v !== undefined) { }`
- **Safe Template Literals**: NEVER interpolate objects, arrays, promises, or `unknown` into template strings. Only primitive types (`string`, `number`, `boolean`) are allowed. Convert complex types explicitly first (e.g., `String(val)` or `JSON.stringify(val)`).
- **No Unsafe Any (`no-unsafe-*`)**: The `any` type is strictly forbidden. You must never assign, return, call, or access members on an `any` type. Use `unknown` and perform `typeof` or `instanceof` checks (or Zod validation) before operating on the data.
- **No Floating Promises**: ALL promises must be `await`ed, returned, or explicitly marked with `void`. Do not pass `async` functions where synchronous callbacks are expected (e.g., `Array.prototype.forEach`).
- **Strict Null Checks**: Never use the non-null assertion operator (`!`). Always handle `null`/`undefined` via control flow analysis, optional chaining (`?.`), or nullish coalescing (`??`).
- **Nullish Coalescing over Logical OR**: Always prefer `??` over `||` to prevent subtle bugs with `0` or `""`.
- **Consistent Type Definitions**: Prefer `interface` for object shapes and `type` for unions/aliases.

## 2. TypeScript V6/V7 & Configuration

- **TypeScript V6/V7 Compatibility**: TypeScript 7 (Go port) currently lacks the programmatic API required by `typescript-eslint`. To use TypeScript 7 for compilation alongside typed linting, install TypeScript 6 via an npm alias (`"typescript": "npm:@typescript/typescript6"`, `"@typescript/native": "npm:typescript@^7"`) and configure ESLint to use the TS 6 parser.
- **Flat Config Type-Aware Linting**: Always use `tseslint.configs.strictTypeChecked` and `tseslint.configs.stylisticTypeChecked` in your `eslint.config.js` (Flat Config).
- **Project Service**: Enable typed linting efficiently by setting `languageOptions.parserOptions.projectService: true` and `tsconfigRootDir: import.meta.dirname`. Do not use the legacy `project: true` unless required.

## 3. Modern Idiomatic TypeScript

- **Strategic Type Annotations (Record vs satisfies)**:
  - **Static Data (Configs, Mock Data, Constants)**: Use `satisfies Type` when the keys are explicitly known at compile time. This validates the structure while preserving exact literal inference, eliminating the need for defensive `undefined` checks.
  - **Dynamic Data (Dictionaries, API Maps)**: Use `: Record<K, V>` or `Map<K, V>` when keys are dynamic or arbitrary. This correctly widens the type so the Agent knows to handle potential `undefined` values during lookups safely.
- **Consistent Type Imports**: Enforce `import type { ... }` for type-only imports to support `verbatimModuleSyntax`.
- **Discriminated Unions**: Model domain states using discriminated unions with a common discriminator tag (e.g., `type: 'success' | 'error'`) rather than sprawling optional properties (`a?: string; b?: number;`).
- **Exhaustive Pattern Matching**: Ensure all cases of a union are handled using exhaustive `switch` checks or a helper like `assertNever(x: never): never`.
- **Safe Control Flow & Error Handling**: Caught errors are `unknown`. Always inspect before reading: `const message = err instanceof Error ? err.message : String(err)`.
