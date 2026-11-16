# PowerShell and .NET to Vite+ Migration Plan

Temporary cross-conversation tracking document for migrating cross-platform CLI utilities and verification scripts from PowerShell 7 and .NET to Vite+ (`vpx`, TypeScript, and Vitest). Remove this file in Stage 5 after all checklist items are verified and legacy PowerShell CLI files are deleted.

## 1. Architecture and Loader Contract

### Execution Boundary

- **Vite+ (`vpx` + TypeScript + Vitest)**: All 12 user-facing CLI tools (`clall`, `ebk`, `mdig`, `mkclp`, `mkgif`, `mmb`, `rea`, `ua`, `unodev`, `up`, `upnpmv`, `webread`), shell verification (`tests/verify-shell.ts`), and unit/contract tests (`tests/unit/`, `tests/contract/`).
- **PowerShell + Zsh (OS Bootstrap Only)**: `scripts/install.sh`, `scripts/install.ps1`, `scripts/windows/*`, `tests/verify-ps-fast.ps1`, `tests/verify-ps-lint.ps1`, `tests/verify-ps-compat.ps1`, and `tests/VerifyCommon.psm1`. These run before `vp` exists on fresh machines.

### Core Design Invariants

- **Loader Isolation (`cli/bin/` + `vpx`)**:
  - POSIX entrypoint `cli/bin/<cmd>` (`0o755`, LF) resolves its physical repo root via `realpath "$0"` and executes `exec "$vpx_bin" "$repo_root/cli/src/main.ts" "<cmd>" "$@"`.
  - Windows entrypoint `cli/bin/<cmd>.cmd` executes `vpx "%REPO_ROOT%\cli\src\main.ts" "<cmd>" %*`.
  - Passing `"$repo_root/cli/src/main.ts"` before `"<cmd>" "$@"` guarantees `vpx` resolves `tsconfig.json` from the repository root regardless of caller `cwd`, never misinterprets script flags as `vpx` options, and never attempts remote package resolution.
- **Hexagonal `CommandContext` Ports (`cli/src/lib/context.ts`)**:
  - Inject `runner` (`exec`, `pipe`, `spawnInteractive`), `fs`, `fetch`, `dns`, `env`, `cwd`, `platform`, `repoRoot`, `stdout`, `stderr`, `isTty`, `dryRun`, and `now`.
  - Command handlers never call global `child_process` or mutate `process.env` directly outside adapters, keeping unit tests deterministic and offline.
- **Declarative CLI Framework (`cli/src/lib/cli-framework.ts`)**:
  - Use `node:util` `parseArgs` with Zod `optionsSchema` and `positionals` bounds.
  - Auto-generate `--help` text from the command definition, handle `--dry-run` uniformly, and reject unknown flags (`UsageError`, exit code `2`) or missing binaries (`MissingDependencyError`, exit code `127`).
- **Signal Cleanup Under `vpx`**:
  - Under `vpx` / Node.js, `SIGINT` and `SIGTERM` terminate immediately unless handled. Always register cleanup handlers on `process.on("SIGINT")` and `process.on("SIGTERM")` (and `try/finally`) to restore terminal cursor (`\x1b[?25h`), terminate active child processes, and remove temporary files.
- **TypeScript and Lint Hygiene**:
  - Strict `erasableSyntaxOnly`, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, `node:` protocol imports, `Zod` `safeParse` at boundaries, `process.exitCode` over `process.exit`, zero lint/type suppressions.
  - Run `vpx oxfmt` on edited `.ts`, `.json`, `.md` files and `vpr cli:sync-bins` whenever `cli/src/registry.ts` changes.

---

## 2. Next-Conversation Resume Protocol

At the start of a new conversation:

1. Read `MIGRATION_PLAN.md` and `AGENTS.md`.
2. Run baseline verification to confirm repo health before editing:
   - `git status`
   - `vpr agent:verify:gate`
3. Locate the earliest stage with unchecked `- [ ]` items in Section 3.
4. Implement that stage completely, add unit/contract tests covering every mapped item in Section 4, run `vpx oxfmt` and `vpr agent:verify:gate`, update checkboxes in `MIGRATION_PLAN.md`, `git add` modified files (never `git commit`), and provide the prompt for the next stage.

---

## 3. Stage Migration Checklist (Stage 1 to Stage 5)

### Stage 1: Foundation, `cli/bin/` Generator, `mmb`, and `verify-shell.ts`

- [x] Create `MIGRATION_PLAN.md`
- [x] Update `tsconfig.json` `"include"` with `"cli/src/**/*.ts"` and `"scripts/**/*.ts"`
- [x] Add `"cli:sync-bins": "vpx scripts/sync-cli-bins.ts"` to `package.json`
- [x] Create `cli/src/lib/context.ts` and `cli/src/lib/process.ts`
- [x] Create `cli/src/lib/spinner.ts` and `cli/src/lib/cli-framework.ts`
- [x] Create `cli/src/commands/mmb.ts`, `cli/src/registry.ts`, `cli/src/main.ts`, and `scripts/sync-cli-bins.ts`
- [x] Generate `cli/bin/mmb` and `cli/bin/mmb.cmd` via `vpr cli:sync-bins`
- [x] Create `tests/verify-shell.ts` and switch `vite.config.ts` `lint:shell` to `vpx tests/verify-shell.ts`
- [x] Update `vite.config.ts` test project globs (`tests/unit/**/*.test.ts`, `tests/contract/**/*.test.ts`), `untrackedEnv` (`DOTNET_ROOT`, `DOTNET_ROOT_ARM64` for `pwsh` tasks), and ignore patterns (`cli/bin/**`)
- [x] Create `tests/unit/test-helpers.ts`, `tests/unit/cli-framework.test.ts`, `tests/unit/mmb.test.ts`, and `tests/contract/cli-bins.test.ts`
- [x] Verify `vpr agent:verify:gate` passes

### Stage 2: Independent Commands Batch 1 (`webread`, `mdig`, `rea`, `ebk`)

- [ ] Move `cli/helpers/webread-parser.ts` to `cli/src/lib/webread-parser.ts` (keep 1-line re-export at `cli/helpers/webread-parser.ts` until Stage 5)
- [ ] Implement `cli/src/commands/webread.ts` (in-process `parseWebContent`, `--llms`, `--jina`, GitHub blob rewrite, `--raw`, `--max-chars`, `-o/--output`)
- [ ] Implement `cli/src/commands/mdig.ts` (pure `node:dns/promises` `Resolver` parallel `A`/`AAAA` queries)
- [ ] Implement `cli/src/commands/rea.ts` (single `.mkv` + `.ass` pairing validation, root/multi-mkv guards, `--dry-run`)
- [ ] Implement `cli/src/commands/ebk.ts` (6 extension backup rules, native JSON formatting, dedup cleanup, Git commit/push, `--dry-run`)
- [ ] Register all Stage 2 commands in `cli/src/registry.ts` and run `vpr cli:sync-bins`
- [ ] Add `tests/unit/webread.test.ts`, `tests/unit/mdig.test.ts`, `tests/unit/rea.test.ts`, and `tests/unit/ebk.test.ts`
- [ ] Verify `vpr agent:verify:gate` passes

### Stage 3: Media Pipelines and GitHub Cloner (`media.ts`, `mkclp`, `mkgif`, `clall`)

- [ ] Implement `cli/src/lib/media.ts` (`parseTimeToSeconds`, `resolveYtDlpBrowser`, `downloadYtDlpSegment` with cookie-less fallback)
- [ ] Implement `cli/src/commands/mkclp.ts` (stream copy vs `hevc_videotoolbox` / `libx264`)
- [ ] Implement `cli/src/commands/mkgif.ts` (`ctx.runner.pipe()` for `ffmpeg | gifski` dual exit tracking and palette fallback)
- [ ] Implement `cli/src/commands/clall.ts` (token precedence, `op://` guard, paginated GitHub `/user/repos` Zod parse, bounded parallel `git clone`)
- [ ] Register `mkclp`, `mkgif`, `clall` in `cli/src/registry.ts` and run `vpr cli:sync-bins`
- [ ] Add `tests/unit/media.test.ts`, `tests/unit/mkclp.test.ts`, `tests/unit/mkgif.test.ts`, and `tests/unit/clall.test.ts`
- [ ] Verify `vpr agent:verify:gate` passes

### Stage 4: Node/Git Toolchain Automation and Transactional Rollback (`unodev`, `upnpmv`, `ua`, `up`)

- [ ] Implement `cli/src/lib/github-actions.ts`, `cli/src/lib/node-toolchain.ts`, and `cli/src/lib/transaction.ts`
- [ ] Implement `cli/src/commands/unodev.ts`, `cli/src/commands/upnpmv.ts`, `cli/src/commands/ua.ts`, and `cli/src/commands/up.ts` (including `--dry-run` and Windows `PATH` adapter)
- [ ] Register `unodev`, `upnpmv`, `ua`, `up` in `cli/src/registry.ts` and run `vpr cli:sync-bins`
- [ ] Add `tests/unit/github-actions.test.ts`, `tests/unit/node-toolchain.test.ts`, `tests/unit/unodev.test.ts`, `tests/unit/upnpmv.test.ts`, `tests/unit/ua.test.ts`, and `tests/unit/up.test.ts`
- [ ] Add `tests/contract/cli-commands.test.ts` verifying all 12 commands (`--help`, unknown option, unexpected positional, zsh completion parity)
- [ ] Confirm 100% coverage of Section 4 Legacy Parity Matrix and `vpr agent:verify:gate` passes

### Stage 5: Installer Cutover, Legacy Removal, Docs Update, and Self-Deletion

- [ ] Update `scripts/install.sh` (`link_cli_scripts` targets `cli/bin/*` excluding `*.cmd`)
- [ ] Update `scripts/windows/WindowsProvisioning.psm1` (`Register-RepositoryCliPath` registers `cli\bin` and prunes legacy `cli`)
- [ ] Update `vite.config.ts` (remove `verify:native`, `ps:lint:cli`, `ps:compat:cli`) and `tests/VerifyCommon.psm1` (scope strictly to `scripts/` and `tests/verify-ps-*.ps1`)
- [ ] Update `AGENTS.md`, `.agents/rules/cli-scripts.md`, and `README.md`
- [ ] Delete `cli/*.ps1` (12 scripts), `cli/helpers/*.psm1` (4 modules), `cli/helpers/webread-parser.ts` shim, `tests/cli.Tests.ps1`, and `tests/verify-shell.ps1`
- [ ] Run `vpr agent:verify:gate` and standalone `verify-ps-*.ps1` + `vpx tests/verify-shell.ts`
- [ ] Delete `MIGRATION_PLAN.md` and run final `vpr agent:verify:gate` check

---

## 4. Legacy 133-Assertion Parity Matrix (`tests/cli.Tests.ps1`)

Every section from `tests/cli.Tests.ps1` must have an equivalent checked Vitest replacement before Stage 5 decommissions `tests/cli.Tests.ps1`:

- [ ] **Sec 1 (`CliCommon.psm1`)**: `Convert-TimeToSecond` (HH:MM:SS.ms, MM:SS, seconds, rejects negative / >=60 / non-positive / invalid) -> `tests/unit/media.test.ts` (`Stage 3`)
- [x] **Sec 1 (`CliCommon.psm1`)**: `ConvertTo-ValidatedInt` (valid, non-int, out-of-range) -> `tests/unit/cli-framework.test.ts` (`Stage 1`)
- [x] **Sec 1 (`CliCommon.psm1`)**: `Format-ByteSize` (KB, MB, GB) -> `tests/unit/cli-framework.test.ts` (`Stage 1`)
- [x] **Sec 1 (`CliCommon.psm1`)**: `Test-RequiredCommand` (present vs missing) -> `tests/unit/cli-framework.test.ts` (`Stage 1`)
- [ ] **Sec 2 (`Symlink Resolution`)**: Extensionless symlink `--help` exits 0 and prints usage from outside repo -> `tests/contract/cli-bins.test.ts` (`Stage 1` verified for `mmb`, remaining 11 in `Stage 4`)
- [ ] **Sec 3 (`All cli/*.ps1 --help & unknown option`)**: All 12 commands `--help` exit 0 + usage, `--unknown-flag-test` exit non-zero + stderr -> `tests/contract/cli-commands.test.ts` (`Stage 4`)
- [ ] **Sec 4 (`rea.ps1`)**: Reject directory with multiple `.mkv` files without deleting directory -> `tests/unit/rea.test.ts` (`Stage 2`)
- [ ] **Sec 5 (`webread.ps1`)**: Reject non-integer `--max-chars` -> `tests/unit/webread.test.ts` (`Stage 2`)
- [ ] **Sec 6 (`NodeToolchain.psm1`)**: `Resolve-PlaywrightSyncStep` (6 cases: `test:setup`, unrelated `test:setup`, `@vitest/browser-playwright`, `playwright-core`, `.cmd` shim, non-Playwright) -> `tests/unit/node-toolchain.test.ts` (`Stage 4`)
- [ ] **Sec 7 (`NodeToolchain.psm1`)**: `Resolve-ProjectVerifyStep` (4 cases: `agent:verify:gate`, fallback `unit -> build -> e2e`, unit-only, empty) -> `tests/unit/node-toolchain.test.ts` (`Stage 4`)
- [ ] **Sec 8 (`NodeToolchain.psm1`)**: `Test-WorkspaceNodeSyncTarget` (5 cases: missing `package.json`, missing lockfile, fresh clone missing `node_modules`, unchanged with `node_modules`, updated with `node_modules`) -> `tests/unit/node-toolchain.test.ts` (`Stage 4`)
- [x] **Sec 9 (`Format-NativeErrorDetail` & `clall`)**: Error line joining, blank fallback (`tests/unit/cli-framework.test.ts`, `Stage 1`); git error formatting & `clall` `op://` rejection (`tests/unit/clall.test.ts`, `Stage 3`)
- [ ] **Sec 10 (`Resolve-GitHubRepoList`)**: Empty array, null, single item, filtering missing `ssh_url` -> `tests/unit/clall.test.ts` (`Stage 3`)
- [ ] **Sec 11 (`MediaCommon.psm1`)**: `Resolve-YtDlpBrowser` (default `chrome`, blank, `YT_DLP_BROWSER`, explicit override) + `mkclp`/`mkgif` `--help` browser doc -> `tests/unit/media.test.ts` + `tests/contract/cli-commands.test.ts` (`Stage 3` & `Stage 4`)
- [ ] **Sec 12 (`verify-ps-fast.ps1`)**: AST contract regression checks for OS Bootstrap PowerShell -> Remains covered by `tests/verify-ps-fast.ps1` self-test or Stage 5 OS-bootstrap contract check (`Stage 5`)
- [ ] **Sec 13 (`upnpmv` & pnpm helpers)**: `--help`, unknown flag, positional arg rejection, `Resolve-LatestPnpmVersionFromJson`, `Get-PnpmPackageManagerSpec`, `Test-PnpmWorkspaceProject`, `Format-ProjectPackageManifest` -> `tests/unit/node-toolchain.test.ts` & `tests/unit/upnpmv.test.ts` (`Stage 4`)
- [ ] **Sec 14 (`GitHubActions.psm1`)**: `ConvertFrom-GitHubActionVersion`, `Compare-GitHubActionVersion`, `Get-GitHubActionUpdate`, `Update-GitHubActionFile` (CRLF + comment preservation, out-of-range error) -> `tests/unit/github-actions.test.ts` (`Stage 4`)
- [ ] **Sec 15 (`NodeToolchain.psm1`)**: `Get-VitePlusOxfmtSpec` -> `tests/unit/node-toolchain.test.ts` (`Stage 4`)
- [ ] **Sec 16 (`Packages.psd1`)**: Windows manifest non-empty sections -> Kept in OS Bootstrap PowerShell contract check (`Stage 5`)
- [ ] **Sec 17 (`VerifyCommon.psm1`)**: `Resolve-VerifyTargetFile` install group discovery -> Kept in OS Bootstrap PowerShell contract check (`Stage 5`)
