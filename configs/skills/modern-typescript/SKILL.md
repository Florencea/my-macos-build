---
name: modern-typescript
description: Strict TypeScript standards (TS 5+), pre-execution live verification, zero suppression directives, Zod runtime validation, and high-performance Oxlint + Oxfmt toolchain for agentic development. Use when writing, refactoring, or type-checking TypeScript code.
compatibility: TypeScript 5+, Oxlint, Oxfmt, Vite+, Zod
---

# Strict TypeScript Guidelines

**CRITICAL:** This project strictly enforces zero-warning `oxlint` linting, automated `oxfmt` formatting, and strict compiler checks (`tsc --noEmit`). Write clean, structurally safe TypeScript code that compiles on the first attempt without regressions.

---

## 1. Pre-Execution Verification & Live Query Mandate

Before troubleshooting unfamiliar type errors or adjusting compiler/linter settings, query live flags:

- Run `vpx oxlint --help` (or `vp lint --help`) or `tsc --help` to confirm valid options.
- Inspect official LLM references: `webread --llms https://oxc.rs` (or `https://oxc.rs/llms.txt`).
- NEVER guess tsconfig compiler options or linter rule names.

---

## 2. Type Safety & Linting Decision Tree

Before writing or refactoring TypeScript code, apply this decision tree to prevent defects:

- **Handling Boundary / Untrusted Data (API, JSON, Env, Files)**:
  - ❌ NEVER cast with `as unknown as Type` or raw `as Type`.
  - ✅ Define a Zod schema and run `schema.safeParse(data)`. Infer static types via `z.infer<typeof schema>`.
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
  - ❌ NEVER interpolate objects or unknown types (`${obj}`).
  - ✅ Convert explicitly: `${String(val)}` or `${JSON.stringify(val)}`.

---

## 3. Zod-First Runtime Validation Patterns

Use Zod as the authoritative boundary guard for external data:

```ts
import { z } from "zod";

export const UserProfileSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(["admin", "user"]).default("user"),
  metadata: z.record(z.unknown()).optional(),
});

export type UserProfile = z.infer<typeof UserProfileSchema>;

export async function fetchUserProfile(userId: string): Promise<UserProfile | null> {
  const res = await fetch(`/api/users/${userId}`);
  if (!res.ok) return null;

  const rawJson = (await res.json()) as unknown;
  const parsed = UserProfileSchema.safeParse(rawJson);
  if (!parsed.success) {
    console.error("Invalid user profile received:", parsed.error.flatten());
    return null;
  }
  return parsed.data; // Fully typed, 100% runtime-verified
}
```

---

## 4. All-in-One `vite.config.ts` Consolidation

In modern Vite+ applications, configure Oxlint and Oxfmt rules directly within `vite.config.ts`:

```ts
import { defineConfig } from "vite-plus";

export default defineConfig({
  lint: {
    options: {
      typeAware: true,
      typeCheck: true,
    },
    rules: {
      "typescript/no-explicit-any": "error",
      "typescript/no-floating-promises": "error",
      "typescript/strict-boolean-expressions": "error",
    },
  },
  fmt: {
    printWidth: 100,
    tabWidth: 2,
    singleQuote: false,
    trailingComma: "all",
  },
});
```
