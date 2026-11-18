import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";

import { describe, expect, it } from "vite-plus/test";
import { z } from "zod";

import { ExecErrorSchema } from "../unit/test-helpers.ts";

const execFileAsync = promisify(execFile);
const REPO_ROOT = path.resolve(import.meta.dirname, "../..");

const BootstrapInspectionSchema = z.object({
  manifestCounts: z.object({
    CliPackages: z.int().positive(),
    DesktopPackages: z.int().positive(),
    InternalRootCAs: z.int().positive(),
    AntigravityPlugins: z.int().positive(),
  }),
  installTargets: z.array(z.string()),
  allTargets: z.array(z.string()),
});

describe("OS bootstrap PowerShell and installer contracts", () => {
  it("enforces verify-ps-fast.ps1 --path and AST contract regression checks (Sec 12)", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-ps-contract-"));
    try {
      const fastVerifyScript = path.join(REPO_ROOT, "tests", "verify-ps-fast.ps1");
      const installScript = path.join(REPO_ROOT, "scripts", "install.ps1");
      const badContractScript = path.join(tempDir, "bad_contract.ps1");

      const badScriptText = [
        "Set-StrictMode -Version Latest",
        "$ErrorActionPreference = 'Stop'",
        "$p = $env:Path",
        "Write-Output $p",
        "Stop-Job -Name 'nonexistent' -Force -ErrorAction SilentlyContinue",
        "",
      ].join("\n");
      await fs.writeFile(badContractScript, badScriptText, "utf8");

      const validPromise = execFileAsync("pwsh", [
        "-NoLogo",
        "-NoProfile",
        "-File",
        fastVerifyScript,
        "--path",
        installScript,
      ]);

      let badExitCode = 0;
      let badStderr = "";
      const badPromise = execFileAsync("pwsh", [
        "-NoLogo",
        "-NoProfile",
        "-File",
        fastVerifyScript,
        "--path",
        badContractScript,
      ]).catch((err: unknown) => {
        const parsed = ExecErrorSchema.safeParse(err);
        if (parsed.success) {
          badExitCode = Number(parsed.data.code);
          badStderr = parsed.data.stderr;
        }
      });

      const [validResult] = await Promise.all([validPromise, badPromise]);
      expect(validResult.stdout).toContain("PowerShell fast check passed");
      expect(badExitCode).not.toBe(0);
      expect(badStderr).toMatch(/invalid parameter -Force/);
      expect(badStderr).toMatch(/uppercase \$env:PATH/);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("validates Packages.psd1 sections and VerifyCommon.psm1 target discovery (Sec 16, Sec 17)", async () => {
    const psCommand = [
      "$ErrorActionPreference = 'Stop'",
      "Import-Module -Name (Join-Path $env:MMB_REPO_ROOT 'tests' 'VerifyCommon.psm1') -Force",
      "$manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $env:MMB_REPO_ROOT 'scripts' 'windows' 'Packages.psd1')",
      "$installTargets = @(Resolve-VerifyTargetFile -RepoRoot $env:MMB_REPO_ROOT -TargetGroup 'install' | ForEach-Object { [System.IO.Path]::GetRelativePath($env:MMB_REPO_ROOT, $_.FullName) -replace '\\\\', '/' })",
      "$allTargets = @(Resolve-VerifyTargetFile -RepoRoot $env:MMB_REPO_ROOT -TargetGroup 'all' | ForEach-Object { [System.IO.Path]::GetRelativePath($env:MMB_REPO_ROOT, $_.FullName) -replace '\\\\', '/' })",
      "$payload = @{",
      "  manifestCounts = @{",
      "    CliPackages = @($manifest['CliPackages']).Count",
      "    DesktopPackages = @($manifest['DesktopPackages']).Count",
      "    InternalRootCAs = @($manifest['InternalRootCAs']).Count",
      "    AntigravityPlugins = @($manifest['AntigravityPlugins']).Count",
      "  }",
      "  installTargets = $installTargets",
      "  allTargets = $allTargets",
      "}",
      "$payload | ConvertTo-Json -Depth 4 -Compress",
    ].join("\n");

    const { stdout } = await execFileAsync(
      "pwsh",
      ["-NoLogo", "-NoProfile", "-Command", psCommand],
      {
        env: { ...process.env, MMB_REPO_ROOT: REPO_ROOT },
      },
    );

    const parsedJson: unknown = JSON.parse(stdout.trim());
    const validated = BootstrapInspectionSchema.safeParse(parsedJson);
    expect(validated.success).toBe(true);
    if (!validated.success) {
      return;
    }
    const result = validated.data;

    expect(result.manifestCounts.CliPackages).toBeGreaterThan(0);
    expect(result.manifestCounts.DesktopPackages).toBeGreaterThan(0);
    expect(result.manifestCounts.InternalRootCAs).toBeGreaterThan(0);
    expect(result.manifestCounts.AntigravityPlugins).toBeGreaterThan(0);

    expect(result.installTargets).toContain("scripts/install.ps1");
    expect(result.installTargets).toContain("scripts/windows/WinGetBootstrap.psm1");
    expect(result.installTargets).toContain("scripts/windows/WindowsProvisioning.psm1");

    expect(result.allTargets).toContain("tests/VerifyCommon.psm1");
    expect(result.allTargets).toContain("tests/verify-ps-fast.ps1");
    expect(result.allTargets).toContain("tests/verify-ps-lint.ps1");
    expect(result.allTargets).toContain("tests/verify-ps-compat.ps1");
    expect(result.allTargets).toContain("scripts/install.ps1");
    expect(
      result.allTargets.some(
        (relPath) =>
          relPath.startsWith("cli/") ||
          relPath === "tests/cli.Tests.ps1" ||
          relPath === "tests/verify-shell.ps1",
      ),
    ).toBe(false);
  });

  it("cuts over macOS and Windows installers from legacy cli/ to cli/bin/", async () => {
    const [installSh, winProvisioning] = await Promise.all([
      fs.readFile(path.join(REPO_ROOT, "scripts", "install.sh"), "utf8"),
      fs.readFile(path.join(REPO_ROOT, "scripts", "windows", "WindowsProvisioning.psm1"), "utf8"),
    ]);

    expect(installSh).toContain('"$repo_dir/cli/bin"');
    expect(installSh).toContain("*.cmd");
    expect(installSh).not.toContain('"$cli_dir"/*.ps1');

    expect(winProvisioning).toContain("Join-Path $RepoRoot 'cli\\bin'");
    expect(winProvisioning).toContain("$legacyCliDir");
    expect(winProvisioning).toContain("$_ -eq $legacyCliDir");
  });

  it.skipIf(process.platform === "win32")(
    "executes install.sh link_cli_scripts and sync_plugin_dir idempotently in isolated HOME",
    async () => {
      const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-install-sh-"));
      try {
        const localBinDir = path.join(tempHome, ".local", "bin");
        await fs.mkdir(localBinDir, { recursive: true });
        await fs.symlink(
          path.join(REPO_ROOT, "cli", "up.ps1"),
          path.join(localBinDir, "stale-legacy-cmd"),
        );

        const installSh = await fs.readFile(path.join(REPO_ROOT, "scripts", "install.sh"), "utf8");
        const withoutMain = installSh.replace(/\nmain "\$@"\s*$/, "\n");
        const scriptRunner = [
          withoutMain,
          'link_cli_scripts "$MMB_REPO_ROOT"',
          'sync_plugin_dir "$MMB_REPO_ROOT" "common-modern-tools"',
          'link_cli_scripts "$MMB_REPO_ROOT"',
          'sync_plugin_dir "$MMB_REPO_ROOT" "common-modern-tools"',
        ].join("\n");

        await execFileAsync("zsh", ["-c", scriptRunner], {
          env: { ...process.env, HOME: tempHome, MMB_REPO_ROOT: REPO_ROOT },
        });

        await expect(fs.lstat(path.join(localBinDir, "stale-legacy-cmd"))).rejects.toThrow(
          /ENOENT/,
        );
        const linkedEntries = await fs.readdir(localBinDir);
        expect(linkedEntries).toHaveLength(12);
        expect(linkedEntries.some((name) => name.endsWith(".cmd"))).toBe(false);
        const webreadTarget = await fs.readlink(path.join(localBinDir, "webread"));
        expect(webreadTarget).toBe(path.join(REPO_ROOT, "cli", "bin", "webread"));

        const pluginManifest = await fs.readFile(
          path.join(tempHome, ".gemini", "config", "plugins", "common-modern-tools", "plugin.json"),
          "utf8",
        );
        expect(pluginManifest).toContain("common-modern-tools");
      } finally {
        await fs.rm(tempHome, { recursive: true, force: true });
      }
    },
  );

  it("validates WindowsProvisioning.psm1 Test-DirectoryContentEqual idempotency helper", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-win-prov-"));
    try {
      const srcDir = path.join(tempDir, "src");
      const dstDir = path.join(tempDir, "dst");
      await fs.mkdir(path.join(srcDir, "sub"), { recursive: true });
      await fs.mkdir(path.join(dstDir, "sub"), { recursive: true });
      await fs.writeFile(path.join(srcDir, "sub", "a.txt"), "hello\n", "utf8");
      await fs.writeFile(path.join(dstDir, "sub", "a.txt"), "hello\n", "utf8");
      await fs.writeFile(path.join(dstDir, ".DS_Store"), "junk", "utf8");

      const provPath = path.join(REPO_ROOT, "scripts", "windows", "WindowsProvisioning.psm1");
      const psScript = [
        "$ErrorActionPreference = 'Stop'",
        `Import-Module -Name '${provPath.replace(/'/g, "''")}' -Force`,
        `& (Get-Module WindowsProvisioning) { param($s, $d) Test-DirectoryContentEqual -SourceDir $s -DestinationDir $d } '${srcDir.replace(/'/g, "''")}' '${dstDir.replace(/'/g, "''")}'`,
      ].join("\n");

      const equalRun = await execFileAsync("pwsh", ["-NoLogo", "-NoProfile", "-Command", psScript]);
      expect(equalRun.stdout.trim()).toBe("True");

      await fs.writeFile(path.join(dstDir, "sub", "a.txt"), "changed\n", "utf8");
      const diffRun = await execFileAsync("pwsh", ["-NoLogo", "-NoProfile", "-Command", psScript]);
      expect(diffRun.stdout.trim()).toBe("False");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("executes WindowsProvisioning.psm1 Vite+ state checks idempotently across PS 7+ and PS 5.1", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-win-vp-"));
    try {
      const vpHomeUpToDate = path.join(tempDir, "vp-up-to-date");
      const vpHomeOutdated = path.join(tempDir, "vp-outdated");
      const repoDir = path.join(tempDir, "repo");
      await fs.mkdir(vpHomeUpToDate, { recursive: true });
      await fs.mkdir(vpHomeOutdated, { recursive: true });
      await fs.mkdir(repoDir, { recursive: true });
      await fs.writeFile(
        path.join(vpHomeUpToDate, "config.json"),
        '{"defaultNodeVersion":"lts"}\n',
        "utf8",
      );
      await fs.writeFile(path.join(repoDir, "package.json"), '{"name":"demo"}\n', "utf8");
      await fs.writeFile(path.join(repoDir, "pnpm-lock.yaml"), "lockfileVersion: '9.0'\n", "utf8");

      const provPath = path.join(REPO_ROOT, "scripts", "windows", "WindowsProvisioning.psm1");
      const psScript = [
        "$ErrorActionPreference = 'Stop'",
        `Import-Module -Name '${provPath.replace(/'/g, "''")}' -Force`,
        "& (Get-Module WindowsProvisioning) {",
        `  param($upHome, $oldHome, $repo)`,
        "  $script:vpCalls = [System.Collections.Generic.List[string]]::new()",
        "  $script:mockInstalled = $true",
        '  $script:mockGlobalPkgsJson = \'[{"name":"oxfmt","version":"0.79.0"}]\'',
        "  function Sync-SessionPath { param([string[]]$ExtraPaths = @()) }",
        "  function vp {",
        "    $global:LASTEXITCODE = 0",
        "    $joined = $args -join ' '",
        "    $script:vpCalls.Add($joined)",
        "    if ($joined -eq 'env list-remote --lts --json --sort desc') {",
        '      return (\'{"node":[{"version":"26.13.1","latest_lts":true,"installed":\' + $script:mockInstalled.ToString().ToLowerInvariant() + \'}]}\')',
        "    }",
        "    if ($joined -eq 'env list-remote --json --sort desc pnpm') {",
        '      return (\'{"package_managers":{"pnpm":[{"version":"12.22.0","latest":true,"installed":\' + $script:mockInstalled.ToString().ToLowerInvariant() + \'}]}}\')',
        "    }",
        "    if ($joined -eq 'toolchain --global --json oxfmt') {",
        '      return \'{"nodes":[{"id":"oxfmt","version":"0.79.0"}]}\'',
        "    }",
        "    if ($joined -eq 'list -g --json') {",
        "      return $script:mockGlobalPkgsJson",
        "    }",
        "    return ''",
        "  }",
        "  $oxfmtState = Get-VpOxfmtState",
        "  $upToDateOut = @(Sync-VpToolchainState -VpHome $upHome -RepoRoot $repo)",
        "  $upToDateCalls = @($script:vpCalls)",
        "  $script:vpCalls.Clear()",
        "  $script:mockInstalled = $false",
        "  $script:mockGlobalPkgsJson = '[]'",
        "  $outdatedOut = @(Sync-VpToolchainState -VpHome $oldHome -RepoRoot $repo)",
        "  $outdatedCalls = @($script:vpCalls)",
        "  $payload = @{",
        "    oxfmtTarget = $oxfmtState.TargetVersion",
        "    oxfmtCurrent = $oxfmtState.CurrentVersion",
        "    upToDateOut = $upToDateOut",
        "    upToDateCalls = $upToDateCalls",
        "    outdatedOut = $outdatedOut",
        "    outdatedCalls = $outdatedCalls",
        "  }",
        "  $payload | ConvertTo-Json -Depth 4 -Compress",
        `} '${vpHomeUpToDate.replace(/'/g, "''")}' '${vpHomeOutdated.replace(/'/g, "''")}' '${repoDir.replace(/'/g, "''")}'`,
      ].join("\n");

      const shells = process.platform === "win32" ? ["pwsh", "powershell"] : ["pwsh"];
      const PayloadSchema = z.object({
        oxfmtTarget: z.string(),
        oxfmtCurrent: z.string(),
        upToDateOut: z.array(z.string()),
        upToDateCalls: z.array(z.string()),
        outdatedOut: z.array(z.string()),
        outdatedCalls: z.array(z.string()),
      });

      const shellResults = await Promise.all(
        shells.map((shellExe) =>
          execFileAsync(shellExe, ["-NoLogo", "-NoProfile", "-Command", psScript]),
        ),
      );

      for (const { stdout } of shellResults) {
        const parsedJson: unknown = JSON.parse(stdout.trim());
        const validated = PayloadSchema.safeParse(parsedJson);
        expect(validated.success).toBe(true);
        if (!validated.success) {
          return;
        }
        const res = validated.data;

        expect(res.oxfmtTarget).toBe("0.79.0");
        expect(res.oxfmtCurrent).toBe("0.79.0");

        expect(res.upToDateOut).toContain(
          "[3/9] Vite+ toolchain is up to date (Node v26.13.1, pnpm v12.22.0, oxfmt 0.79.0).",
        );
        expect(res.upToDateCalls).not.toContain("env default lts");
        expect(res.upToDateCalls).not.toContain("env install lts");
        expect(res.upToDateCalls.some((c) => c.startsWith("env install pnpm"))).toBe(false);
        expect(res.upToDateCalls).not.toContain("env clean");
        expect(res.upToDateCalls.some((c) => c.startsWith("install -g"))).toBe(false);
        expect(res.upToDateCalls).toContain(`-C ${repoDir} install --frozen-lockfile`);

        expect(res.outdatedOut).toContain("[3/9] Updating Vite+ toolchain...");
        expect(res.outdatedCalls).toContain("env default lts");
        expect(res.outdatedCalls).toContain("env install lts");
        expect(res.outdatedCalls).toContain("env install pnpm@12.22.0");
        expect(res.outdatedCalls).toContain("env clean");
        expect(res.outdatedCalls).toContain("install -g oxfmt@0.79.0");
        expect(res.outdatedCalls).toContain(`-C ${repoDir} install --frozen-lockfile`);
      }
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
