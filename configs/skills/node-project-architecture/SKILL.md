---
name: node-project-architecture
description: Architecture blueprint, rules splitting standards, and workspace layout for Node.js projects with package.json. Use when creating a new Node.js project, refactoring a bloated AGENTS.md, designing .agents/rules and .agents/skills, or configuring agent:* package scripts.
compatibility: Node.js (Active LTS), Vite+, Antigravity
---

# Node.js Project Architecture & Rules Splitting Guidelines

This skill defines the canonical project structure, VSCode integration, CI workflows, and rules splitting standards for Node.js / Vite web applications operating in Google Antigravity, patterned after production-proven templates (`vite-start-antd` and `vite-hono`).

## 1. Modern Workspace Layout (Antigravity Standards)

Avoid monolithic, multi-thousand-line `AGENTS.md` files at the project root. Instead, adopt the modular Antigravity workspace layout:

```text
<project-root>/
├── package.json              # Central scripts with three-tier agent:* gates
├── AGENTS.md                 # Lean project overview, SSOT invariants, architecture map (< 3 KB)
├── .vscode/                  # Standardized editor toolchain configuration
│   ├── settings.json         # Oxc formatter, Vite+ script runner, ESLint/Prettier disabled
│   └── extensions.json       # Oxc + Vite+ extension recommendations
├── .github/
│   └── workflows/
│       ├── ci.yml            # Fast gatekeeper CI using voidzero-dev/setup-vp@v1
│       └── node-canary.yml   # Node.js runtime canary check
└── .agents/
    ├── rules/                # Modular domain rules with glob triggers
    │   ├── api-routes.md     # trigger: glob -> "src/server/routes/**, src/api/**"
    │   ├── database.md       # trigger: glob -> "src/server/database/**, src/db/**"
    │   ├── ui-styling.md     # trigger: glob -> "src/client/components/**, src/components/**"
    │   ├── routing.md        # trigger: glob -> "src/client/routes/**"
    │   ├── testing.md        # trigger: glob -> "test/**, **/*.test.*"
    │   ├── locales.md        # trigger: glob -> "src/locales/**"
    │   └── ci-workflows.md   # trigger: glob -> ".github/workflows/**" (actionlint 0 errors)
    └── skills/               # Project-specific repeatable workflows (on-demand runbooks)
        ├── scaffold-feature/
        │   └── SKILL.md      # Step-by-step feature generator
        └── database-seed/
            └── SKILL.md      # Database schema sync and test fixtures generator
```

---

## 2. Editor Integration (`.vscode/`)

Standardize editor ergonomics to ensure seamless human-agent pair programming and eliminate linter conflicts:

- **`.vscode/settings.json`**:
  - **Oxc Formatter & Linter**: Set `editor.defaultFormatter` to `oxc.oxc-vscode` and enable `source.fixAll.oxc: explicit`.
  - **Disable Legacy Linters**: Explicitly set `"eslint.enable": false` and `"prettier.enable": false` to prevent duplicate diagnostics and editor lag.
  - **Vite+ Script Runner**: Set `"npm.scriptRunner": "vp"` so VS Code runs tasks via `vp`.
  - **Single Root Config**: Set `"oxc.disableNestedConfig": true` and `"oxc.fmt.disableNestedConfig": true`.
  - **TypeScript Import Preferences**: Set `"js/ts.preferences.preferTypeOnlyAutoImports": true` to support `verbatimModuleSyntax`.
  - **Exclude Auto-Generated Files**: Exclude generated files (e.g. `**/routeTree.gen.ts`) from formatting, file watchers, and searches.
- **`.vscode/extensions.json`**:
  - Recommendations: `oxc.oxc-vscode`, `VoidZero.vite-plus-extension-pack`, `bradlc.vscode-tailwindcss`, `typescriptteam.native-preview`.
  - Unwanted: `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`.

See reference template: [vscode-settings-template.json](./resources/vscode-settings-template.json).

---

## 3. Continuous Integration & Local Verification (`.github/`)

- **Vite+ Action**: Use `voidzero-dev/setup-vp@v1` with `node-version-file: package.json` and `cache: true` for deterministic runtime resolution and sub-second dependency restoration.
- **Gatekeeper Pipeline**: Sequential execution in CI:
  1. `vp install`
  2. `vpr agent:typecheck`
  3. `vp check` (Oxlint & Oxfmt)
  4. `vpr agent:test:unit`
  5. `vp build`
  6. `vpr agent:test:e2e` (if browser tests exist)
- **Local Shift-Left CI Verification (`actionlint`)**:
  - Whenever `.github/workflows/` files are created or modified, run `vpr agent:lint:ci` (or `actionlint`) locally.
  - Must pass with **0 errors and 0 warnings** before staging (`git add`).
  - **Offline Invariant**: `actionlint` is strictly a local shift-left guardrail; NEVER embed `actionlint` steps into remote GitHub Actions YAML files.

See reference template: [ci-workflow-template.yml](./resources/ci-workflow-template.yml) and [ci-workflows-rule-template.md](./resources/ci-workflows-rule-template.md).

---

## 4. Three-Tier Verification Gates & Frictionless `agent:*` Scripts

In `package.json`, structure `agent:*` tasks matching Antigravity's global security whitelist (`command(regex:vp run agent:.*)` and `command(regex:vpr agent:.*)`). Adopt the standard **three-tier gatekeeper architecture**:

```json
{
  "scripts": {
    "agent:verify:inner": "vpr agent:typecheck && vpr agent:lint",
    "agent:verify:unit": "vpr agent:verify:inner && vpr agent:test:unit",
    "agent:verify:gate": "vpr agent:verify:unit && vp build && vpr agent:test:e2e",
    "agent:typecheck": "tsc -b --pretty false",
    "agent:lint": "vp lint",
    "agent:lint:fix": "vp lint --fix",
    "agent:lint:ci": "actionlint",
    "agent:format": "vp fmt",
    "agent:test:unit": "vp test run --reporter=tap-flat --no-color",
    "agent:test:e2e": "playwright test --reporter=line"
  }
}
```

### Gatekeeper Hierarchy:

1. **Tier 1 (Inner Loop - `agent:verify:inner`)**: Runs `agent:typecheck` + `agent:lint`. Ultra-fast feedback loop during active editing (< 2s).
2. **Tier 2 (Unit Verification - `agent:verify:unit`)**: Runs `agent:verify:inner` + `agent:test:unit`. Validates functionality without build overhead.
3. **Tier 3 (Gatekeeper - `agent:verify:gate`)**: Runs `agent:verify:unit` + `vp build` + `agent:test:e2e`. Mandatory before finishing substantial features or opening PRs.

### Agent-Friendly Output Formatting:

- **`tsc -b --pretty false`**: Strips color codes and decorative ASCII frames for clean diagnostic parsing.
- **`vp lint -f agent`**: Uses Oxlint's dedicated agent reporter for concise error-line locations.
- **`vp test run --reporter=tap-flat --no-color`**: Emits compact, flat test results without interactive spinner clutter.
- **`vp check --quiet`**: Suppresses cosmetic warnings and reports actionable errors only.

---

## 5. Configuration Syntax Pre-Verification Mandate

> [!CRITICAL]
> **Never Rely on Stale Pre-Training Memory for Tool Configurations**: Toolchains (Vite+, Tailwind v4, TypeScript 5+, Oxlint, pnpm catalogs, ESLint flat config) evolve rapidly. Guessing config syntax leads to immediate build breaks.

### Mandatory Pre-Flight Verification SOP:

1. **Inspect Version First**: Run `vp toolchain` or check `package.json` dependencies to determine the installed major version.
2. **Query Authoritative Live Docs**:
   - Vite+ / Task runner: `https://viteplus.dev/llms-full.txt`
   - Oxc / Oxlint / Oxfmt: `https://oxc.rs/llms.txt`
   - TypeScript options: `https://www.typescriptlang.org/tsconfig/`
   - Tailwind v4: Query `@theme` and CSS-first configuration docs.
3. **Check CLI Options**: Run `<tool> --help` to verify supported flags before executing unfamiliar options.

---

## 6. Schema & Boundary Validation Layer (Zod-First Policy)

All untrusted boundary data in the project must pass through runtime schema validation rather than compile-time type assertions:

- **Boundary Data**:
  - API / fetch response payloads
  - `JSON.parse(...)` outputs
  - File reads (YAML frontmatter, JSON configs)
  - Environment variables (`process.env`)
  - CLI positional arguments and options
- **Rule of Engagement**:
  - ❌ **STRICTLY PROHIBITED**: `const user = rawData as unknown as User;` (Type smuggling / fake assertion).
  - ✅ **MANDATORY**:
    ```ts
    import { z } from "zod";

    export const UserSchema = z.object({
      id: z.string().uuid(),
      email: z.string().email(),
      name: z.string().min(1),
      roles: z.array(z.string()).default([]),
    });

    export type User = z.infer<typeof UserSchema>;

    export function parseUser(data: unknown): User {
      const result = UserSchema.safeParse(data);
      if (!result.success) {
        console.error("Validation failure:", result.error.flatten());
        throw new Error("Invalid user payload");
      }
      return result.data; // Safely typed without any type assertions!
    }
    ```

---

## 7. Templates & Reference Assets

Use the bundled templates when creating a new Node.js / Vite+ project or refactoring an existing repository:

- [Lean AGENTS.md Template](./resources/lean-agents-template.md)
- [VSCode Settings Template](./resources/vscode-settings-template.json)
- [VSCode Extensions Template](./resources/vscode-extensions-template.json)
- [GitHub Actions CI Workflow Template](./resources/ci-workflow-template.yml)
- [CI Workflows Rule Template](./resources/ci-workflows-rule-template.md)
