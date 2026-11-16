---
trigger: glob
globs: "cli/src/**, scripts/sync-cli-bins.ts"
description: Rules for authoring, registering, and verifying Vite+ TypeScript CLI commands under cli/src/.
---

# Vite+ TypeScript CLI Rules

## 1. Architecture & Loader Isolation

- **Source & Registry**:
  - Implement each CLI command under `cli/src/commands/<command>.ts` using `defineCommand` from `cli/src/lib/cli-framework.ts`.
  - Export shared domain logic in `cli/src/lib/*.ts` (`cli-framework.ts`, `context.ts`, `fs-utils.ts`, `github-actions.ts`, `media.ts`, `node-toolchain.ts`, `process.ts`, `spinner.ts`, `transaction.ts`, `webread-parser.ts`) and ambient type declarations in `cli/src/types/*.d.ts`.
  - Register all commands in `cli/src/registry.ts` (`CLI_COMMANDS`, `COMMAND_NAMES`) invoked by `cli/src/main.ts`.
  - Reuse `mapWithConcurrency` and `runSequentially` from `cli/src/lib/process.ts`, `isFile` / `isDirectory` / `pathExists` from `cli/src/lib/fs-utils.ts`, `formatErrorMessage` from `cli/src/lib/context.ts`, and `withMediaInputSource` from `cli/src/lib/media.ts` instead of duplicating loop recursion or filesystem helpers.
- **Generated Entrypoints (`cli/bin/`)**:
  - Never hand-edit `cli/bin/*`. Regenerate POSIX shims (`0o755`, LF) and Windows wrappers (`*.cmd`) after any change to `cli/src/registry.ts` via `vpr cli:sync-bins`.
  - POSIX shims resolve the physical repository root with `realpath "$0"` and execute `exec "$vpx_bin" "$repo_root/cli/src/main.ts" "<cmd>" "$@"`; Windows `.cmd` wrappers execute `vpx "%REPO_ROOT%\cli\src\main.ts" "<cmd>" %*`.

---

## 2. Hexagonal `CommandContext` Ports & Declarative CLI Contracts

- **Dependency Injection (`cli/src/lib/context.ts`)**:
  - Command handlers must use injected `ctx` ports (`runner`, `fs`, `fetch`, `dns`, `env`, `cwd`, `platform`, `repoRoot`, `stdout`, `stderr`, `isTty`, `dryRun`, `now`) rather than calling global `node:child_process` or mutating `process.env` directly, keeping Vitest suites deterministic and offline.
- **Declarative Argument & Error Handling (`cli/src/lib/cli-framework.ts`)**:
  - Parse flags via `node:util` `parseArgs` backed by Zod `optionsSchema` and `positionals` min/max bounds.
  - Reject unknown flags and invalid positional counts with `UsageError` (exit code `2`) and missing external binaries with `MissingDependencyError` (exit code `127`).
  - Support `--help` / `-h` (auto-generated from the command definition) and `--dry-run` (`supportsDryRun: true`) consistently.
- **Signal Cleanup Under `vpx`**:
  - When manipulating TTY cursor visibility, creating temporary files, or spawning child processes, register `SIGINT`/`SIGTERM` cleanup handlers (and `try/finally`) to restore terminal state (`\x1b[?25h`), terminate active child processes, and remove temporary directories.

---

## 3. System Exposure & Zsh Completion Parity

- **macOS**: `scripts/install.sh` symlinks `cli/bin/*` (excluding `*.cmd`) into `~/.local/bin/<cmd>` and prunes stale broken symlinks pointing into `cli/`.
- **Windows 11 / 10 LTSC**: `scripts/windows/WindowsProvisioning.psm1` (`Register-RepositoryCliPath`) adds `cli\bin` to User `PATH` and removes legacy `cli` path entries.
- **Zsh Completions**: Keep `configs/zsh/completions/_<cmd>` flags synchronized with `cli/src/commands/<cmd>.ts` (enforced by `tests/contract/cli-commands.test.ts`).

---

## 4. TypeScript Hygiene & Verification Gates

- Enforce `erasableSyntaxOnly`, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, `node:` protocol imports, Zod `safeParse` at boundaries, `process.exitCode` over `process.exit`, and zero lint/type suppression directives.
- Format edited files with `vpx oxfmt <files>` and verify via `vpr agent:verify:inner` (fast loop), `vpr agent:verify:unit`, and `vpr agent:verify:gate` before staging.
