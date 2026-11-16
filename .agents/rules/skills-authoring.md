---
trigger: glob
globs: "plugins/**, .agents/rules/**"
description: Rules for creating, structuring, and maintaining Antigravity Plugins, Skills, and Rules in this repository.
---

# Antigravity Plugins, Skills & Rules Authoring Rules

## 1. Plugin Directory Structure & Split Architecture

All Antigravity customizations are packaged under `plugins/<plugin-name>/` and deployed to `~/.gemini/config/plugins/<plugin-name>/`:

- **`plugins/common-modern-tools/`** (Shared across macOS & Windows 11):
  - `plugin.json`: Manifest for universal cross-platform CLI toolchain bundle.
  - `PSScriptAnalyzerSettings.psd1`: Synced canonical `PSScriptAnalyzer` settings across workspaces.
  - `rules/AGENTS.md`: Lean always-on invariants (tool priorities, zero throwaway script policy, evidence-first verification, token discipline, formatting, and dual-mode communication standards).
  - `skills/common-toolchain/SKILL.md` (+ `references/docs-matrix.md`): 4-tier tool selection hierarchy, progressive reconnaissance (L0-L4), custom `cli/bin/*` helpers, two-stage `webread` protocol, and progressive external doc matrix.
  - `skills/modern-powershell/SKILL.md`: Cross-platform and cross-version (`pwsh` vs `powershell.exe` 5.1) PowerShell standards, runtime introspection, 3-stage formatting/AST/lint pipeline, and zero-suppression policy.
- **`plugins/macos-modern-tools/`** (macOS only):
  - `plugin.json`, `rules/AGENTS.md` (lean Darwin execution guardrails), `skills/macos-toolchain/SKILL.md` (Zsh, APFS CoW, BSD recipes, `defaults`/`PlistBuddy`, `ResolveLinkTarget`).
- **`plugins/windows-modern-tools/`** (Windows 11 & Windows 10 IoT LTSC):
  - `plugin.json`, `rules/AGENTS.md` (lean Windows execution guardrails), `skills/windows-toolchain/SKILL.md` (double-shell quote defense, Dev Drive vs LTSC AppX delegation, array unrolling guard).
- **`plugins/modern-web-stack/`** (Shared across macOS & Windows 11):
  - `plugin.json`
  - `rules/`: Domain-split `trigger: glob` rules (`node-ts.md`, `react-ui.md`, `ci-workflows.md`) to prevent irrelevant framework injection during non-UI edits.
  - `skills/<skill-name>/SKILL.md`: `modern-nodejs`, `modern-typescript`, `modern-react-tailwind`, `modern-hono-drizzle`, `node-project-architecture` (+ `resources/`), `tanstack-router`, `modern-web-guidance`.

---

## 2. Manifest, Rule & Skill Specifications

- **Plugin Manifest (`plugins/<plugin-name>/plugin.json`)**:
  - Must conform to `https://antigravity.google/schemas/v1/plugin.json` (`additionalProperties: false`).
  - Required fields: `name` (lowercase kebab-case matching folder name), `description`.
  - Recommended fields: `"$schema"`, `displayName`, `version`, `author`, `repository`, `keywords`, `suggestedPrompts` (max 3 non-empty items).
- **Plugin Rules**:
  - `rules/AGENTS.md`: Plain Markdown **without YAML frontmatter** (always active when enabled). Keep strictly under **8 KB** (target <= 4 KB) to protect the aggregate rules budget.
  - `rules/<name>.md`: Named rule with YAML frontmatter (`trigger: glob`, comma-separated POSIX `globs` string, `description`). Focus on hard invariants and lookup gateways.
- **Plugin Skills (`plugins/<plugin-name>/skills/<skill-name>/SKILL.md`)**:
  - Required YAML frontmatter: `name` (matches parent folder), `description` (concise trigger summary), `compatibility`. NEVER set `trigger` in skills.
  - Move bulky reference tables or templates into `references/` or `resources/` and link via relative paths (`./references/...`, `./resources/...`).

---

## 3. Authoring & Sync Invariants

- **External SSOT Gateway Design**: Delegate fast-changing syntax to two-stage `webread` (`llms.txt` -> `.md`), `vpx modern-web-guidance`, `vp lint --rules`, `node_modules/**/*.d.ts`, or PowerShell introspection.
- **Zero Suppression & Zod-First**: Never recommend `@ts-ignore`, `@ts-expect-error`, `oxlint-disable`, or `SuppressMessageAttribute`; validate external boundaries with Zod `safeParse`.
- **No Fragile Version Pinning**: Cite major generations or LTS tracks (`Node.js (Active LTS)`, `TypeScript (Current)`, `PowerShell 7+`, `Vite+`).
- **Installer & Formatting Sync**: Whenever files are added, renamed, or deleted under `plugins/`, update the remote fallback fetch list in `scripts/install.sh` (`sync_plugin_dir` / `deploy_antigravity_plugins`) and verify via `vp test --project contract`. Format modified `.md` and `.json` files via `vp fmt <files>`.
