---
trigger: glob
globs: "plugins/**"
description: Rules for creating, structuring, and maintaining Antigravity Plugins, Skills, and Rules in this repository.
---

# Antigravity Plugins, Skills & Rules Authoring Rules

## 1. Plugin Directory Structure & Split Architecture

All Antigravity customizations are packaged as **Plugins** under `plugins/<plugin-name>/` and deployed to `~/.gemini/config/plugins/<plugin-name>/`:

- **`plugins/common-modern-tools/`** (Shared across macOS & Windows 11):
  - `plugin.json`: Manifest for universal cross-platform CLI toolchain bundle.
  - `PSScriptAnalyzerSettings.psd1`: Synced canonical `PSScriptAnalyzer` settings for formatting and non-bypassable static analysis across workspaces.
  - `rules/AGENTS.md`: Always-on invariants covering CLI priorities, zero-throwaway script policy, two-stage live doc verification, token discipline, git commit safety, and dual-mode documentation standards.
  - `skills/common-toolchain/SKILL.md`: 4-tier tool selection hierarchy, progressive reconnaissance (L0-L4), custom CLI helpers (`cli/bin/*` backed by `cli/src/`), two-stage `webread` protocol, and verified documentation matrix.
  - `skills/modern-powershell/SKILL.md`: Cross-platform and cross-version (`pwsh` vs `powershell.exe` 5.1) PowerShell authoring standards, runtime introspection gate, 3-stage formatting/AST/lint pipeline, and zero-suppression policy.
- **`plugins/macos-modern-tools/`** (macOS only):
  - `plugin.json`: Manifest for macOS platform bundle.
  - `rules/AGENTS.md`: macOS Darwin execution rules, Zsh nomatch guardrails, APFS CoW cloning, BSD traps, and Darwin diagnostics.
  - `skills/macos-toolchain/SKILL.md`: Zsh glob patterns, APFS cloning, BSD workarounds, Darwin system automation, and PowerShell symlink resolution.
- **`plugins/windows-modern-tools/`** (Windows 11 & Windows 10 IoT LTSC):
  - `plugin.json`: Manifest for Windows platform bundle.
  - `rules/AGENTS.md`: Windows platform rules, double-shell quote defense, PowerShell 5.1 vs 7 isolation, and Dev Drive optimization.
  - `skills/windows-toolchain/SKILL.md`: Windows double-shell quote defense recipes, PowerShell compatibility, and array unwrapping guard.
- **`plugins/modern-web-stack/`** (Shared across macOS & Windows 11):
  - `plugin.json`: Manifest for cross-platform web development stack.
  - `rules/modern-web-stack.md`: Glob-triggered (`trigger: glob`) invariants for Node.js, TypeScript, React, Tailwind CSS, Vitest Browser testing, Oxlint/Oxfmt, and GitHub Actions CI (`actionlint`).
  - `skills/<skill-name>/SKILL.md`: `modern-nodejs`, `modern-typescript`, `modern-react-tailwind`, `modern-hono-drizzle`, `node-project-architecture`, `tanstack-router`, `modern-web-guidance`.

---

## 2. Manifest & File Specifications

- **Plugin Manifest (`plugins/<plugin-name>/plugin.json`)**:
  - Must conform to `https://antigravity.google/schemas/v1/plugin.json` (`additionalProperties: false`).
  - Required fields: `name` (lowercase kebab-case matching folder name), `description`.
  - Recommended fields: `"$schema"`, `displayName`, `version`, `author`, `repository`, `keywords`, `suggestedPrompts` (maximum 3 non-empty items).
- **Plugin Rules**:
  - `rules/AGENTS.md`: Plain Markdown **without YAML frontmatter** (always active while plugin is enabled). Must remain strictly under **8 KB (~2,500 tokens)** to protect the aggregate rules budget.
  - `rules/<name>.md`: Named rule file with YAML frontmatter (`trigger: glob`, comma-separated POSIX `globs` string, `description`). Focus exclusively on hard invariants, prohibitions, and lookup gateways.
- **Plugin Skills (`plugins/<plugin-name>/skills/<skill-name>/SKILL.md`)**:
  - YAML frontmatter required: `name` (must match parent directory name), `description`, `compatibility`.
  - NEVER put `trigger: always_on` in skills.

---

## 3. Mandatory Authoring & SSOT Gateway Invariants

- **External SSOT Gateway Design**: Avoid duplicating fast-changing API syntax or long anti-pattern lists in skills. Preserve immutable architectural invariants and delegate API syntax/examples to verified two-stage lookups (`webread https://<domain>/llms.txt` → targeted `.md`, `vpx modern-web-guidance`, `vp lint --rules` + `oxc.rs/docs/guide/usage/linter/rules/<plugin>/<rule>.md`, `node_modules/**/*.d.ts`, or PowerShell runtime introspection).
- **Zero Suppression Directives Policy**: Never recommend `@ts-ignore`, `@ts-expect-error`, `oxlint-disable`, or `[Diagnostics.CodeAnalysis.SuppressMessageAttribute]`.
- **Zod-First Runtime Validation**: Validate external boundaries with Zod `safeParse`.
- **No Fragile Version Pinning**: Reference major generations or LTS branches (`Node.js (Active LTS)`, `TypeScript (Current)`, `PowerShell 7+`, `Vite+`).
- **Formatting**: Format modified `.md` and `.json` files via `vpx oxfmt <files>`.
