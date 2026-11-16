import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { COMMAND_NAMES } from "../cli/src/registry.ts";

export function renderPosixShim(commandName: string): string {
  return [
    "#!/usr/bin/env sh",
    "set -eu",
    'script_path="$(realpath "$0")"',
    'repo_root="$(cd "$(dirname "$script_path")/../.." && pwd)"',
    'vpx_bin="$(command -v vpx 2>/dev/null || printf \'%s\\n\' "${VP_HOME:-$HOME/.local/share/vite-plus}/bin/vpx")"',
    'if [ ! -x "$vpx_bin" ]; then',
    "  printf 'Error: vpx not found. Install Vite+ first.\\n' >&2",
    "  exit 127",
    "fi",
    'if [ ! -d "$repo_root/node_modules/zod" ]; then',
    '  printf \'Error: node_modules missing in %s (run: vp -C "%s" install)\\n\' "$repo_root" "$repo_root" >&2',
    "  exit 1",
    "fi",
    `exec "$vpx_bin" "$repo_root/cli/src/main.ts" "${commandName}" "$@"`,
    "",
  ].join("\n");
}

export function renderWindowsShim(commandName: string): string {
  return [
    "@echo off",
    "setlocal",
    'set "REPO_ROOT=%~dp0..\\.."',
    'set "VPX_BIN="',
    "for /f \"delims=\" %%I in ('where vpx 2^>nul') do (",
    '  set "VPX_BIN=%%I"',
    "  goto :found_vpx",
    ")",
    "if defined VP_HOME (",
    '  if exist "%VP_HOME%\\bin\\vpx.exe" set "VPX_BIN=%VP_HOME%\\bin\\vpx.exe"',
    '  if not defined VPX_BIN if exist "%VP_HOME%\\bin\\vpx.cmd" set "VPX_BIN=%VP_HOME%\\bin\\vpx.cmd"',
    ")",
    "if not defined VPX_BIN (",
    '  if exist "%USERPROFILE%\\.vite-plus\\bin\\vpx.exe" set "VPX_BIN=%USERPROFILE%\\.vite-plus\\bin\\vpx.exe"',
    '  if not defined VPX_BIN if exist "%USERPROFILE%\\.vite-plus\\bin\\vpx.cmd" set "VPX_BIN=%USERPROFILE%\\.vite-plus\\bin\\vpx.cmd"',
    ")",
    "if not defined VPX_BIN (",
    "  echo Error: vpx not found. Install Vite+ first. 1>&2",
    "  exit /b 127",
    ")",
    ":found_vpx",
    'if not exist "%REPO_ROOT%\\node_modules\\zod" (',
    '  echo Error: node_modules missing in "%REPO_ROOT%" ^(run: vp -C "%REPO_ROOT%" install^) 1>&2',
    "  exit /b 1",
    ")",
    `"%VPX_BIN%" "%REPO_ROOT%\\cli\\src\\main.ts" "${commandName}" %*`,
    "",
  ].join("\n");
}

export async function syncCliBins(
  repoRoot: string,
  commands: readonly string[] = COMMAND_NAMES,
): Promise<{ readonly written: readonly string[]; readonly removed: readonly string[] }> {
  const binDir = path.join(repoRoot, "cli", "bin");
  await fs.mkdir(binDir, { recursive: true });

  const expectedFiles = new Set<string>();
  const written: string[] = [];
  const removed: string[] = [];

  const writeTasks: Promise<void>[] = [];
  for (const commandName of commands) {
    const posixName = commandName;
    const cmdName = `${commandName}.cmd`;
    expectedFiles.add(posixName);
    expectedFiles.add(cmdName);

    const posixPath = path.join(binDir, posixName);
    const posixContent = renderPosixShim(commandName);
    writeTasks.push(
      fs
        .writeFile(posixPath, posixContent, { encoding: "utf8", mode: 0o755 })
        .then(() => fs.chmod(posixPath, 0o755)),
    );
    written.push(posixName);

    const cmdPath = path.join(binDir, cmdName);
    const cmdContent = renderWindowsShim(commandName);
    writeTasks.push(fs.writeFile(cmdPath, cmdContent, { encoding: "utf8" }));
    written.push(cmdName);
  }
  await Promise.all(writeTasks);

  const existingEntries = await fs.readdir(binDir, { withFileTypes: true });
  const staleEntries = existingEntries.filter((entry) => !expectedFiles.has(entry.name));
  await Promise.all(
    staleEntries.map(async (entry) => {
      await fs.rm(path.join(binDir, entry.name), { recursive: true, force: true });
      removed.push(entry.name);
    }),
  );

  return { written, removed };
}

const isEntryPoint =
  process.argv[1] !== undefined && import.meta.filename === path.resolve(process.argv[1]);
if (isEntryPoint) {
  const repoRoot = path.resolve(import.meta.dirname, "..");
  const result = await syncCliBins(repoRoot);
  process.stdout.write(
    `Synced cli/bin: ${result.written.length.toString()} written, ${result.removed.length.toString()} removed.\n`,
  );
}
