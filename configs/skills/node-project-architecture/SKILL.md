---
name: node-project-architecture
description: Architecture blueprint, rules splitting standards, and workspace layout for Node.js projects with package.json. Use when creating a new Node.js project, refactoring a bloated AGENTS.md, designing .agents/rules and .agents/skills, or configuring agent:* package scripts.
compatibility: Node.js (Active LTS), Vite+, Antigravity
---

# Node.js Project Architecture & Rules Splitting Guidelines

This skill defines the canonical project structure and rules splitting standards for Node.js / Vite web applications operating in Google Antigravity.

## 1. Modern Workspace Layout (Antigravity Standards)

Avoid monolithic, multi-thousand-line `AGENTS.md` files at the project root. Instead, adopt the modular Antigravity 2.0 workspace layout:

```text
<project-root>/
├── package.json              # Central scripts with pre-approved agent:* entries
├── AGENTS.md                 # Lean project overview, SSOT principles, architecture map (< 3 KB)
└── .agents/
    ├── rules/                # Modular domain rules with glob triggers
    │   ├── api-routes.md     # trigger: glob -> "src/server/routes/**, src/api/**"
    │   ├── database.md       # trigger: glob -> "src/server/database/**, src/db/**"
    │   ├── ui-components.md  # trigger: glob -> "src/client/components/**, src/components/**"
    │   └── locales.md        # trigger: glob -> "src/locales/**"
    └── skills/               # Project-specific repeatable workflows (on-demand runbooks)
        ├── scaffold-feature/
        │   └── SKILL.md      # Step-by-step feature generator
        └── database-seed/
            └── SKILL.md      # Database schema sync and test fixtures generator
```

---

## 2. Refactoring Bloated `AGENTS.md` (< 3 KB Guideline)

Root `AGENTS.md` is loaded unconditionally (`always_on`) for the entire workspace. To protect the 20,000-token rules budget and prevent context pollution:

### What Belongs in Root `AGENTS.md`:

- **Project Mission & Summary**: What the project does in 2-3 sentences.
- **Single Source of Truth (SSOT)**: The core invariants (e.g. data schemas, unidirectional data flows).
- **Architecture Quick Map**: A clean Markdown table mapping folder paths to their core responsibilities.
- **Frictionless Security Whitelist**: Project-specific `agent:*` execution guidelines.
- **Language & Planning Standards**: Traditional Chinese (繁體中文) response requirements.

### What MUST Be Extracted to `.agents/rules/`:

- **API & Routing Rules** $\rightarrow$ `.agents/rules/api-routes.md` (triggered when editing server files).
- **Database ORM & Migrations** $\rightarrow$ `.agents/rules/database.md` (triggered when editing DB files).
- **UI Components & Themes** $\rightarrow$ `.agents/rules/ui-components.md` (triggered when editing React components).
- **Translations & I18n Parity** $\rightarrow$ `.agents/rules/locales.md` (triggered when editing locale files).

### What Is Already Handled Globally:

Do NOT copy-paste Git commit prohibitions, TypeScript linting rules, Node ESM guidelines, React paradigms, or Tailwind CSS rules into project `AGENTS.md`. These are automatically handled machine-wide:

- **Git Commit Prohibitions**: Globally guarded by `~/.config/git/hooks/pre-commit` and enforced by global rule `macos-execution.md` (`trigger: always_on`). Projects never need to redeclare commit restrictions.
- **Language & Runtime Rules**: Automatically provided by machine-wide global rules in `~/.gemini/config/rules/` with file glob triggers (`**/*.ts`, `**/*.tsx`, `**/*.mjs`).

---

## 3. Modular `.agents/rules/` Specification

Each modular rule in `.agents/rules/` must include YAML frontmatter with `trigger: glob`:

```markdown
---
trigger: glob
globs: "src/server/routes/**, src/api/**"
description: OpenAPI schema validation, RPC router mounting, and handler conventions.
---

# API & Routing Guidelines

1. Handler signatures must infer types from schema.
2. Route parameters must be validated using Zod.
   ...
```

---

## 4. Frictionless `agent:*` Package Scripts

In `package.json`, define pre-approved `agent:*` tasks matching Antigravity's global security whitelist (`command(regex:vp run agent:.*)` and `command(regex:vpr agent:.*)`). This eliminates intrusive confirmation dialogs:

```json
{
  "scripts": {
    "agent:verify:gate": "vp check && vp test",
    "agent:verify:inner": "vp check",
    "agent:verify:unit": "vp test run",
    "agent:format": "vpx oxfmt .",
    "agent:lint": "vp lint",
    "agent:lint:fix": "vp lint --fix",
    "agent:typecheck": "tsc --noEmit",
    "agent:test:unit": "vp test run"
  }
}
```

> [!TIP]
> **Modern Toolchain Migration (Oxlint & Oxfmt)**: Monolithic ESLint, Prettier, and `@typescript-eslint` packages are deprecated. All modern Node.js repositories standardize on Rust-powered tools: **`oxlint`** (via `vp lint`) for sub-second static analysis and **`oxfmt`** (via `vpx oxfmt .` or `vp fmt`) for formatting. Full type checking is cleanly decoupled and performed via `tsc --noEmit` (or `vp check`).

---

## 5. Templates & Reference Assets

Use the bundled template when creating a new project or splitting an existing one:

- [Lean AGENTS.md Template](./resources/lean-agents-template.md)
