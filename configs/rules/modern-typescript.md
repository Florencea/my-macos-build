---
trigger: glob
globs: "**/*.ts, **/*.tsx, **/*.mts, **/*.cts"
description: Strict TypeScript type safety rules, compiler invariants, and Oxlint enforcement.
---

# Strict TypeScript Rules & Type-Checked Invariants

**CRITICAL:** All generated TypeScript code MUST pass `oxlint` (zero warnings, zero errors) and compile cleanly under strict TypeScript (`tsc --noEmit`) on the first attempt.

## 1. Strict Boolean & Truthiness Expressions

- **Strict Booleans**: NEVER evaluate non-boolean values in `if` or conditional expressions (`strict-boolean-expressions`).
  - ❌ `if (str)` / `if (arr.length)` / `if (obj)`
  - ✅ `if (str !== '')` / `if (arr.length > 0)` / `if (obj !== null)`

---

## 2. Map Lookups & Data Access

- **No Double Map Lookups**: NEVER use `Map.has(key)` followed by `Map.get(key)`. `Map.has()` does not narrow types in TypeScript. Perform a single `.get()` and explicitly check against `undefined`.
  - ❌ `if (map.has(key)) { const v = map.get(key); }`
  - ✅ `const v = map.get(key); if (v !== undefined) { ... }`

---

## 3. Safe Template Literals & String Conversion

- **Primitive Interpolation Only**: NEVER interpolate objects, arrays, promises, or `unknown` into template strings. Only primitive types (`string`, `number`, `boolean`) are allowed.
  - Explicitly convert complex types using `String(val)` or `JSON.stringify(val)`.

---

## 4. Absolute Ban on Unsafe Any

- **The `any` Type is STRICTLY FORBIDDEN**: Never assign, return, call, or access members on an `any` type (`no-unsafe-*`).
  - Always use `unknown` and perform `typeof`, `instanceof`, or Zod validation before operating on untrusted data.

---

## 5. Async Execution & Null Safety

- **No Floating Promises**: ALL promises must be `await`ed, returned, or explicitly marked with `void` (`no-floating-promises`).
- **Strict Null Checks**: Never use the non-null assertion operator (`!`). Always handle `null`/`undefined` via control flow analysis, optional chaining (`?.`), or nullish coalescing (`??`).
- **Nullish Coalescing over Logical OR**: Always prefer `??` over `||` to prevent subtle bugs with `0` or `""`.

---

## 6. Type Annotations & Modeling

- **Static vs Dynamic Data**:
  - Static configs, mock data, known keys $\rightarrow$ use `satisfies Type` (preserves narrow literal inference).
  - Dynamic dictionaries, API maps $\rightarrow$ use `: Record<K, V>` or `Map<K, V>` (enforces defensive `undefined` checks).
- **Consistent Type Imports**: Enforce `import type { ... }` for type-only imports to support `verbatimModuleSyntax`.
- **Discriminated Unions**: Model domain states using common discriminator tags (e.g. `type: 'success' | 'error'`) rather than sprawling optional properties.
