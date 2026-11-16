import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import { describe, expect, it } from "vite-plus/test";
import { z } from "zod";

const execFileAsync = promisify(execFile);
const REPO_ROOT = path.resolve(import.meta.dirname, "../..");

const ExecErrorSchema = z.object({
  code: z.union([z.number(), z.string()]),
  stderr: z.string(),
});

const BootstrapInspectionSchema = z.object({
  manifestCounts: z.object({
    CliPackages: z.number().int().positive(),
    DesktopPackages: z.number().int().positive(),
    InternalRootCAs: z.number().int().positive(),
    AntigravityPlugins: z.number().int().positive(),
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
    const result = BootstrapInspectionSchema.parse(parsedJson);

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
});
