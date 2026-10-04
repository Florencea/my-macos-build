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
  - `compatibility` (recommended): E.g. `macOS Darwin, Zsh 5+, Node.js (Active LTS), Vite+`. (STRICTLY PROHIBITED to pin fragile minor/patch versions like `0.15+` or `1.0.0+`).
  - **Prohibited**: NEVER put `trigger: always_on` in skills.
- **Rules (`configs/rules/<rule-name>.md`)**:
  - `trigger` (required): `always_on` or `glob`.
  - `globs` (required if trigger is `glob`): Comma-separated glob patterns wrapped in quotes.
  - `description` (required): Concise explanation of what constraints the rule enforces.

---

## 3. Mandatory Authoring Invariants & Best Practices

- **Live Documentation First**: Before writing, refactoring, or updating any technical skill or rule, the agent MUST query authoritative endpoints (`search_web`, `read_url_content`, `https://oxc.rs/llms.txt`, `https://viteplus.dev/llms-full.txt`) to verify the latest stable CLI flags, options, and paradigms. Guessing from stale model weights or pre-training memory is strictly prohibited.
- **Zero Suppression Directives Policy**: Skills and rules must NEVER recommend or contain diagnostic suppression directives (`@ts-ignore`, `@ts-expect-error`, `oxlint-disable`, etc.). All code examples must resolve issues structurally.
- **Zod-First Runtime Validation**: Code examples dealing with external boundary data (API, JSON, env) must demonstrate runtime schema parsing via Zod (`safeParse`), never unsafe casts (`as unknown as Type`).
- **Agent-Friendly Formats**: Tool execution examples must prioritize token-efficient structured formats (`-f agent`, `--json`, `--reporter=tap-flat`, `--no-color`, `--quiet`).
- **No Fragile Version Pinning**: NEVER hardcode minor, patch, or rapidly evolving version numbers in documentation, frontmatter, or headings. Reference major generations or LTS branches instead (e.g. `TypeScript 5+`, `Node.js (Active LTS)`). Instruct agents to verify exact installed versions dynamically via `<command> --version` or `<command> --help`.
- **Keep Skills Focused**: 1 responsibility per skill.
- **Use Scripts as Black Boxes**: Run `<tool> --help` or `<tool> -h` instead of inspecting script source codes.
- **Include Decision Trees**: Structural logic flows for tool/architecture selection.
- **Authoritative Documentation**: Always include verified LLM query endpoints (`llms-full.txt`, `llms.txt`, official documentation) for deep referencing.

---

## 4. Installer Synchronization

- Update the fallback arrays in `scripts/install.sh` when adding, renaming, or removing skills or rules.
- Deploy to `$HOME/.gemini/config/skills/` and `$HOME/.gemini/config/rules/`.
- Format markdown with `vpx oxfmt <file>`.
