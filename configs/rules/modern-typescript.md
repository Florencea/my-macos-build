---
trigger: glob
globs: "**/*.ts, **/*.tsx, **/*.mts, **/*.cts"
description: Strict TypeScript type safety rules, zero-suppression invariants, Zod runtime validation, and Oxlint enforcement.
---

# Strict TypeScript Rules & Type-Checked Invariants

**CRITICAL:** All generated TypeScript code MUST pass `oxlint` (zero warnings, zero errors) and compile cleanly under strict TypeScript (`tsc --noEmit` or `tsc -b --pretty false`) on the first attempt.

## 1. Zero Suppression Directives Policy (STRICTLY FORBIDDEN)

- **NEVER Suppress Compiler or Linter Diagnostics**: Suppressing diagnostics to bypass checks is strictly prohibited:
  - ❌ `// @ts-ignore` / `// @ts-expect-error` / `// @ts-nocheck`
  - ❌ `/* oxlint-disable */` / `// oxlint-disable-line` / `// oxlint-disable-next-line`
  - ❌ `/* eslint-disable */` / `// eslint-disable-next-line` / `// biome-ignore`
- **No Rule Relaxation**: Never modify `tsconfig.json` or `.oxlintrc.json` to downgrade errors to warnings or disable rules just to make problematic code compile.
- **Mandatory Structural Resolution**: All type discrepancies must be resolved via structural typing, control flow narrowing (`typeof`, `instanceof`, `in`), discriminated unions, or runtime schema validation.

---

## 2. Ban on Unsafe Assertions & Type Smuggling

- **Absolute Ban on Double Assertions**: NEVER use double type casting to force an incompatible type:
  - ❌ `data as unknown as TargetType` / `data as any as TargetType`
- **No Unsafe Single Casting**: NEVER cast raw boundary or unknown data directly:
  - ❌ `const res = (await response.json()) as UserProfile;`
- **Safe Alternatives**:
  - For external / dynamic data $\rightarrow$ Use Zod schema validation (`UserSchema.safeParse(...)`).
  - For internal known literals $\rightarrow$ Use `satisfies Type` or `as const`.

---

## 3. Zod-First Runtime Validation & Boundary Defense

- **Mandatory Runtime Validation for Boundary Data**: Untrusted data (API responses, `JSON.parse`, file reads, `process.env`, CLI inputs) MUST be validated with Zod:
  - ✅ Always define schemas: `const Schema = z.object({ ... });`
  - ✅ Derive static types automatically: `type Data = z.infer<typeof Schema>;`
- **Graceful Error Handling with `safeParse`**:
  - Prefer `schema.safeParse(data)` over `schema.parse(data)` when handling operations that must not crash abruptly:
  ```ts
  const parsed = UserSchema.safeParse(rawData);
  if (!parsed.success) {
    console.error("Validation failure:", parsed.error.flatten());
    return null; // Gracefully handle failure or return domain error
  }
  const user = parsed.data; // Safely typed without any type assertions!
  ```

---

## 4. Strict Boolean & Truthiness Expressions

- **Strict Booleans**: NEVER evaluate non-boolean values in `if` or conditional expressions (`strict-boolean-expressions`).
  - ❌ `if (str)` / `if (arr.length)` / `if (obj)`
  - ✅ `if (str !== '')` / `if (arr.length > 0)` / `if (obj !== null)`

---

## 5. Map Lookups & Data Access

- **No Double Map Lookups**: NEVER use `Map.has(key)` followed by `Map.get(key)`. `Map.has()` does not narrow types in TypeScript. Perform a single `.get()` and explicitly check against `undefined`.
  - ❌ `if (map.has(key)) { const v = map.get(key); }`
  - ✅ `const v = map.get(key); if (v !== undefined) { ... }`

---

## 6. Safe Template Literals & String Conversion

- **Primitive Interpolation Only**: NEVER interpolate objects, arrays, promises, or `unknown` into template strings. Only primitive types (`string`, `number`, `boolean`) are allowed.
  - Explicitly convert complex types using `String(val)` or `JSON.stringify(val)`.

---

## 7. Absolute Ban on Unsafe Any

- **The `any` Type is STRICTLY FORBIDDEN**: Never assign, return, call, or access members on an `any` type (`no-unsafe-*`).
  - Always use `unknown` and perform `typeof`, `instanceof`, or Zod validation before operating on untrusted data.

---

## 8. Async Execution & Null Safety

- **No Floating Promises**: ALL promises must be `await`ed, returned, or explicitly marked with `void` (`no-floating-promises`).
- **Strict Null Checks**: Never use the non-null assertion operator (`!`). Always handle `null`/`undefined` via control flow analysis, optional chaining (`?.`), or nullish coalescing (`??`).
- **Nullish Coalescing over Logical OR**: Always prefer `??` over `||` to prevent subtle bugs with `0` or `""`.

---

## 9. Type Annotations & Modeling

- **Static vs Dynamic Data**:
  - Static configs, mock data, known keys $\rightarrow$ use `satisfies Type` (preserves narrow literal inference).
  - Dynamic dictionaries, API maps $\rightarrow$ use `: Record<K, V>` or `Map<K, V>` (enforces defensive `undefined` checks).
- **Consistent Type Imports**: Enforce `import type { ... }` for type-only imports to support `verbatimModuleSyntax`.
- **Discriminated Unions**: Model domain states using common discriminator tags (e.g. `type: 'success' | 'error'`) rather than sprawling optional properties.

---

## 10. Agent Verification & Toolchain Commands

When running type checks and linters as an AI agent, use agent-optimized flags:

- **Linting**: `vp lint -f agent` (or `vpx oxlint -f agent`) for concise error lines without token-heavy decorative frames.
- **Type Checking**: `tsc -b --pretty false` (or `tsc --noEmit --pretty false`) to prevent color codes and ASCII banners.
- **Combined Check**: `vp check --quiet` to suppress cosmetic warnings.
