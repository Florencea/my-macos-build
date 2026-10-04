---
trigger: glob
globs: "configs/skills/**, configs/rules/**"
description: Rules for creating, structuring, and maintaining Antigravity Skills and Rules in this repository.
---

# Antigravity Skills & Rules Authoring Rules

## 1. Directory Structure Standards

- **Skills**: All skills must reside in `configs/skills/<skill-name>/SKILL.md`. Flat `.md` files under `configs/skills/` are strictly prohibited.
  - Optional subdirectories: `references/`, `scripts/`, `examples/`, `resources/`.
- **Rules**: All modular rules must reside in `configs/rules/<rule-name>.md`.

---

## 2. YAML Frontmatter Specifications

- **Skills (`configs/skills/<skill-name>/SKILL.md`)**:
  - `name` (required): Lowercase alphanumeric and hyphens only (1-64 chars), matching folder name.
  - `description` (required): Concise, high-density description detailing what the skill does and explicit trigger criteria (e.g. "Use when...").
  - `compatibility` (recommended): E.g. `macOS Darwin, Zsh 5.9+, Vite+ 1.0.0+`.
  - **Prohibited**: NEVER put `trigger: always_on` in skills.
- **Rules (`configs/rules/<rule-name>.md`)**:
  - `trigger` (required): `always_on` or `glob`.
  - `globs` (required if trigger is `glob`): Comma-separated glob patterns wrapped in quotes.
  - `description` (required): Concise explanation of what constraints the rule enforces.

---

## 3. Official Best Practices

- **Keep Skills Focused**: 1 responsibility per skill.
- **Use Scripts as Black Boxes**: Run `<tool> --help` or `<tool> -h` instead of inspecting script source codes.
- **Include Decision Trees**: Structural logic flows for tool/architecture selection.
- **Authoritative Documentation**: Verified LLM query endpoints (`llms-full.txt`, `llms.txt`, official documentation).

---

## 4. Installer Synchronization

- Update the fallback arrays in `scripts/install.sh` when adding, renaming, or removing skills or rules.
- Deploy to `$HOME/.gemini/config/skills/` and `$HOME/.gemini/config/rules/`.
- Format markdown with `vpx oxfmt <file>`.
