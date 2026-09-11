# Agent Guidelines & Workflow Rules

This document outlines the development workflow, code formatting standards, and commit rules for AI agents operating in this repository.

## 1. Code Formatting Standards

Before staging or committing any files, all modified files must be formatted using the following tools:

- **Shell Scripts (`cli/*`, `scripts/*`, `*.sh`)**:
  - Formatter: `shfmt`
  - Command:
    ```bash
    shfmt -i 2 -w <modified-files>
    ```
  - Configuration: 2-space indentation.

- **Markdown Files (`*.md`)**:
  - Formatter: `prettier`
  - Command:
    ```bash
    npx prettier --write <modified-files>
    ```

## 2. Git Commit Rules

- **AI Direct Commits Prohibited**:
  - The repository enforces a pre-commit hook that rejects direct commits by AI agents (`ANTIGRAVITY_AGENT=1`).
  - Agents must **never** execute `git commit`.
  - Workflow for agents:
    1. Apply code changes.
    2. Format modified files (`shfmt` for shell scripts, `prettier` for markdown).
    3. Stage changes using `git add <files>`.
    4. Provide the exact `git commit -m "..."` command for manual execution by the user.

- **Commit Message Convention**:
  - Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.
  - Common types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`.
  - Common scopes: `cli`, `configs`, `docs`, `media`.
  - Examples:
    - `refactor(cli): optimize unodev with jq and remove npm and .node-version dependencies`
    - `style: format shell scripts using shfmt (-i 2)`
    - `fix(cli): scale yt-dlp source height by width`
