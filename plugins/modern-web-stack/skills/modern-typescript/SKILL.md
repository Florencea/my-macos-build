---
name: modern-typescript
description: Strict TypeScript standards, Oxlint/Oxfmt gateways (npx oxlint -f agent, npx oxfmt), zero suppression directives, and Zod boundary validation. Use when writing, refactoring, or type-checking TypeScript.
compatibility: TypeScript (Current), Oxlint, Oxfmt, Zod
---

# Strict TypeScript Guidelines

## 1. External SSOT & Anti-Pattern Gateways

Verify compiler flags, Zod APIs, and Oxlint rules before modifying TypeScript code or configs:

- **Oxlint & Oxfmt Diagnostics** (query locally first, fetch Markdown on demand):
  - List active rules/config: `npx oxlint --rules` (filter `typescript`, `oxc`, `unicorn`, `promise`) and `npx oxlint --print-config`.
  - Token-efficient lint diagnostics: `npx oxlint -f agent`; format via `npx oxfmt <files>` (`npx oxfmt --check <files>` in CI).
  - Rule rationale & examples (`incorrect` / `correct`): Stage 1 `curl -fsSL https://oxc.rs/llms.txt | head -n 120` -> Stage 2 `curl -fsSL https://oxc.rs/docs/guide/usage/linter/rules/<plugin>/<rule>.md`.
- **TypeScript Compiler & Declarations** (`typescriptlang.org` lacks `/llms.txt`):
  - Local first: `npx tsc --help`, `npx tsc -b --pretty false`, and inspect `node_modules/typescript/lib/*.d.ts`.
  - Handbook fallback: inspect via web search or `https://www.typescriptlang.org/docs/handbook/<topic>.html`.
- **Zod Schema API**:
  - Stage 1 `curl -fsSL https://zod.dev/llms.txt | head -n 120` -> Stage 2 `curl -fsSL https://zod.dev/api` (or inspect `node_modules/zod/**/*.d.ts` to verify current constructors vs deprecated methods).

---

## 2. Zero Suppression & Structural Type Invariants

- **Strict Ban on Suppression Directives**:
  - STRICTLY PROHIBITED: `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`, `/* oxlint-disable */`, `// eslint-disable`, `// biome-ignore`.
  - Never downgrade rules in `tsconfig.json` or lint configs. Resolve errors structurally.
- **Ban on Unsafe Casts & Assertions**:
  - Prohibit double assertions (`as unknown as TargetType`) and unverified raw casts. Narrow via control flow (`typeof`, `instanceof`, `in`), discriminated unions, or Zod `safeParse`.
- **Strict Boolean Expressions & Single Map Lookups**:
  - Require explicit boolean comparisons (`str !== ""`, `arr.length > 0`, `obj !== null`).
  - Lookup maps once: `const value = map.get(key); if (value !== undefined) { ... }` (never `has` + `get`).
- **Type Modeling (`satisfies` vs `Record`)**:
  - Known static objects -> `satisfies Type` to preserve literal inference.
  - Dynamic dictionaries -> `: Record<K, V>` or `Map<K, V>` with `undefined` checks.
- **Template Literals & Native Execution Hygiene**:
  - Interpolate only primitives (`string`, `number`, `boolean`); explicitly convert complex objects.
  - Enforce `import type { ... }` (`verbatimModuleSyntax`), await or return all promises, prefer `??` over `||`, and write erasable syntax (`erasableSyntaxOnly`) compatible with direct Node.js execution.

---

## 3. Zod-First Runtime Boundary Validation

Validate all untrusted boundary data (API responses, `JSON.parse`, config files, `process.env`) via `safeParse` and infer static types via `z.infer<typeof Schema>`:

```ts
import { z } from "zod";

export const UserSchema = z.object({
  id: z.string().min(1),
  role: z.enum(["admin", "user"]).default("user"),
});

export type User = z.infer<typeof UserSchema>;

export function parseUserData(raw: unknown): User | null {
  const result = UserSchema.safeParse(raw);
  return result.success ? result.data : null;
}
```
