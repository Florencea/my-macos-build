---
name: modern-typescript
description: Strict TypeScript standards (TS V6/V7) and @typescript-eslint strict/stylistic type-checked linting rules for agentic development. Use when writing, refactoring, or type-checking TypeScript code, configuring tsconfig or typescript-eslint, and resolving type errors.
compatibility: TypeScript 5.x/6.x/7.x, @typescript-eslint 8.x
---

# Strict TypeScript Guidelines

**🚨 AGENT INSTRUCTION (CRITICAL):** This project strictly enforces `@typescript-eslint/strictTypeChecked` and `@typescript-eslint/stylisticTypeChecked`. You MUST write code that passes these strict linting rules on the first attempt to avoid wasting development cycles.

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

## 2. TypeScript V6/V7 & Configuration

- **TypeScript V6/V7 Compatibility**: TypeScript 7 (Go port) currently lacks the programmatic AST API required by `typescript-eslint`. To use TypeScript 7 for compilation alongside typed linting, install TypeScript 6 via an npm alias (`"typescript": "npm:@typescript/typescript6"`, `"@typescript/native": "npm:typescript@^7"`) and configure ESLint to use the TS 6 parser.
- **Flat Config Type-Aware Linting**: Always use `tseslint.configs.strictTypeChecked` and `tseslint.configs.stylisticTypeChecked` in your `eslint.config.js` (Flat Config).
- **Project Service**: Enable typed linting efficiently by setting `languageOptions.parserOptions.projectService: true` and `tsconfigRootDir: import.meta.dirname`. Do not use the legacy `project: true` unless required.

---

## 3. Modern Idiomatic TypeScript

- **Consistent Type Imports**: Enforce `import type { ... }` for type-only imports to support `verbatimModuleSyntax`.
- **Discriminated Unions**: Model domain states using discriminated unions with a common discriminator tag (e.g., `type: 'success' | 'error'`) rather than sprawling optional properties (`a?: string; b?: number;`).
- **Exhaustive Pattern Matching**: Ensure all cases of a union are handled using exhaustive `switch` checks or a helper like `assertNever(x: never): never`.
- **Safe Control Flow & Error Handling**: Caught errors are `unknown`. Always inspect before reading: `const message = err instanceof Error ? err.message : String(err)`.

---

## 4. Authoritative Documentation & LLM References

When agents need rule definitions or compiler option references, query these authoritative endpoints:

- **TypeScript Official Reference**:
  - Documentation: `https://www.typescriptlang.org/docs/`
  - TSConfig Options: `https://www.typescriptlang.org/tsconfig/`
- **typescript-eslint Documentation**:
  - Rules Index: `https://typescript-eslint.io/rules/`
  - Key Strict Rules:
    - `strict-boolean-expressions`: `https://typescript-eslint.io/rules/strict-boolean-expressions/`
    - `no-floating-promises`: `https://typescript-eslint.io/rules/no-floating-promises/`
    - `no-unsafe-assignment`: `https://typescript-eslint.io/rules/no-unsafe-assignment/`
    - `consistent-type-imports`: `https://typescript-eslint.io/rules/consistent-type-imports/`
    - `projectService` Guide: `https://typescript-eslint.io/packages/parser#projectservice`
