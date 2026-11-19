---
trigger: glob
globs: "plugins/**, .agents/rules/**"
description: Rules for creating, structuring, and maintaining Antigravity Plugins, Skills, and Rules in this repository.
---

# Antigravity Plugins, Skills & Rules Authoring Rules

## 1. Plugin Directory Structure & Split Architecture

All Antigravity customizations are packaged under `plugins/<plugin-name>/` and deployed to `~/.gemini/config/plugins/<plugin-name>/`:

- **`plugins/common-modern-tools/`**:
  - `plugin.json`: Manifest for core CLI toolchain bundle.
  - `rules/AGENTS.md`: Lean always-on invariants (tool priorities, zero throwaway script policy, evidence-first verification, token discipline, formatting, and dual-mode communication standards).
  - `skills/common-toolchain/SKILL.md` (+ `references/docs-matrix.md`): Core CLI binaries, L0-L3 recon, `cli/*.sh` helpers, `fnm`/`npm` workflows, and two-stage `llms.txt` lookups.
- **`plugins/macos-modern-tools/`**:
  - `plugin.json`, `rules/AGENTS.md` (Darwin execution guardrails), `skills/macos-toolchain/SKILL.md` (Bash 3.2, Fish, Zsh, APFS CoW, BSD recipes, `defaults`/`PlistBuddy`).
- **`plugins/modern-web-stack/`**:
  - `plugin.json`
  - `rules/`: Domain-split `trigger: glob` rules (`node-ts.md`, `react-ui.md`, `ci-workflows.md`).
  - `skills/<skill-name>/SKILL.md`: `modern-nodejs`, `modern-typescript`, `modern-react-tailwind`, `modern-hono-drizzle`, `node-project-architecture` (+ `resources/`), `tanstack-router`, `modern-web-guidance`.

---

## 2. Manifest, Rule & Skill Specifications

- **Plugin Manifest (`plugins/<plugin-name>/plugin.json`)**:
  - Must conform to `https://antigravity.google/schemas/v1/plugin.json` (`additionalProperties: false`).
  - Required fields: `name` (lowercase kebab-case matching folder name), `description`.
  - Recommended fields: `"$schema"`, `displayName`, `version`, `author`, `repository`, `keywords`, `suggestedPrompts` (max 3 non-empty items).
- **Plugin Rules**:
  - `rules/AGENTS.md`: Plain Markdown **without YAML frontmatter** (always active when enabled). Keep strictly under **8 KB** (target <= 4 KB) to protect the aggregate rules budget.
  - `rules/<name>.md`: Named rule with YAML frontmatter (`trigger: glob`, comma-separated POSIX `globs` string, `description`).
- **Plugin Skills (`plugins/<plugin-name>/skills/<skill-name>/SKILL.md`)**:
  - Required YAML frontmatter: `name` (matches parent folder), `description`, `compatibility`. NEVER set `trigger` in skills.
  - Move bulky reference tables or templates into `references/` or `resources/` and link via relative paths (`./references/...`, `./resources/...`).

---

## 3. Authoring & Sync Invariants

- **External SSOT Gateway Design**: Delegate fast-changing syntax to `<tool> --help`, `node_modules/**/*.d.ts`, or two-stage `curl -fsSL` (`llms.txt` -> `.md`).
- **Zero Suppression & Zod-First**: Never recommend `@ts-ignore`, `@ts-expect-error`, `oxlint-disable`, or `eslint-disable`; validate external boundaries with Zod `safeParse`.
- **No Fragile Version Pinning**: Cite major generations or LTS tracks (`Node.js (Active LTS)`, `TypeScript (Current)`, `fnm`, `npm`).
- **Installer & Formatting Sync**: Whenever files are added, renamed, or deleted under `plugins/`, update the remote fallback fetch list in `scripts/install.sh` (`sync_plugin_dir` / `deploy_antigravity_plugins`). Validate JSON files via `jq empty` and enforce LF line endings.
