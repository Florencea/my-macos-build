import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { describe, expect, it } from "vite-plus/test";

import {
  formatProjectPackageManifest,
  isPnpmWorkspaceProject,
  isWorkspaceNodeSyncTarget,
  mergeWindowsPathSegments,
  parsePnpmPackageManagerSpec,
  resolveGlobalVpExecutable,
  resolveLatestPnpmVersionFromJson,
  resolvePlaywrightSyncStep,
  resolveProjectVerifySteps,
  syncGlobalOxfmt,
  withWindowsMachinePath,
} from "../../cli/src/lib/node-toolchain.ts";
import { createTestContext } from "./test-helpers.ts";

describe("node-toolchain utilities", () => {
  it("resolves Playwright sync steps across all 6 project variants", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-nt-pw-"));
    try {
      const emptyDir = path.join(tempDir, "pw_empty");
      await fs.mkdir(emptyDir, { recursive: true });

      await expect(
        resolvePlaywrightSyncStep(
          {
            scripts: { "test:setup": "playwright install chromium" },
            devDependencies: { playwright: "1.65.0" },
          },
          emptyDir,
          fs,
        ),
      ).resolves.toEqual({
        exe: "vpr",
        args: ["--no-cache", "test:setup"],
        stepLabel: "vpr --no-cache test:setup",
      });

      await expect(
        resolvePlaywrightSyncStep(
          {
            scripts: { "test:setup": "node scripts/seed-db.ts" },
            devDependencies: { vitest: "5.1.0" },
          },
          emptyDir,
          fs,
        ),
      ).resolves.toBeNull();

      await expect(
        resolvePlaywrightSyncStep(
          {
            devDependencies: { "@vitest/browser-playwright": "5.1.0" },
          },
          emptyDir,
          fs,
        ),
      ).resolves.toEqual({
        exe: "vp",
        args: ["exec", "playwright", "install", "chromium", "--no-progress"],
        stepLabel: "vp exec playwright install chromium",
      });

      await expect(
        resolvePlaywrightSyncStep(
          {
            dependencies: { "playwright-core": "1.65.0" },
          },
          emptyDir,
          fs,
        ),
      ).resolves.toEqual({
        exe: "vp",
        args: ["exec", "playwright-core", "install", "chromium", "--no-progress"],
        stepLabel: "vp exec playwright-core install chromium",
      });

      const shimProject = path.join(tempDir, "pw_bin");
      const shimBinDir = path.join(shimProject, "node_modules", ".bin");
      await fs.mkdir(shimBinDir, { recursive: true });
      await fs.writeFile(path.join(shimBinDir, "playwright.cmd"), "");

      await expect(
        resolvePlaywrightSyncStep(
          {
            devDependencies: { vitest: "5.1.0" },
          },
          shimProject,
          fs,
        ),
      ).resolves.toEqual({
        exe: "vp",
        args: ["exec", "playwright", "install", "chromium", "--no-progress"],
        stepLabel: "vp exec playwright install chromium",
      });

      await expect(
        resolvePlaywrightSyncStep(
          {
            devDependencies: { vitest: "5.1.0" },
          },
          emptyDir,
          fs,
        ),
      ).resolves.toBeNull();
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("resolves project verify steps across gate, fallback, unit-only, and empty scripts", () => {
    const gateSteps = resolveProjectVerifySteps({
      "agent:verify:gate": "vpr agent:verify:unit && vp build && vpr agent:test:e2e",
      "agent:verify:unit": "vpr agent:verify:inner && vpr agent:test:unit",
      "agent:test:e2e": "vp test run --project e2e",
    });
    expect(gateSteps).toHaveLength(1);
    expect(gateSteps[0]?.exe).toBe("vpr");
    expect(gateSteps[0]?.args).toEqual(["agent:verify:gate"]);

    const fallbackSteps = resolveProjectVerifySteps({
      "agent:verify:unit": "vpr agent:verify:inner && vpr agent:test:unit",
      build: "vp build",
      "agent:test:e2e": "vp test run --project e2e",
    });
    expect(fallbackSteps.map((s) => s.args[0])).toEqual([
      "agent:verify:unit",
      "build",
      "agent:test:e2e",
    ]);

    const unitOnlySteps = resolveProjectVerifySteps({
      "agent:verify:unit": "vpr agent:verify:inner && vpr agent:test:unit",
    });
    expect(unitOnlySteps).toHaveLength(1);
    expect(unitOnlySteps[0]?.args).toEqual(["agent:verify:unit"]);

    expect(resolveProjectVerifySteps({})).toEqual([]);
  });

  it("evaluates workspace node sync targets across 5 repository states", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-nt-sync-"));
    try {
      const nonNodeRepo = path.join(tempDir, "repo_non_node");
      await fs.mkdir(nonNodeRepo, { recursive: true });
      await expect(isWorkspaceNodeSyncTarget(fs, nonNodeRepo, true)).resolves.toBe(false);

      const noLockRepo = path.join(tempDir, "repo_no_lock");
      await fs.mkdir(noLockRepo, { recursive: true });
      await fs.writeFile(path.join(noLockRepo, "package.json"), "{}");
      await expect(isWorkspaceNodeSyncTarget(fs, noLockRepo, true)).resolves.toBe(false);

      const freshCloneRepo = path.join(tempDir, "repo_fresh_clone");
      await fs.mkdir(freshCloneRepo, { recursive: true });
      await fs.writeFile(path.join(freshCloneRepo, "package.json"), "{}");
      await fs.writeFile(path.join(freshCloneRepo, "pnpm-lock.yaml"), "");
      await expect(isWorkspaceNodeSyncTarget(fs, freshCloneRepo, false)).resolves.toBe(true);

      const installedRepo = path.join(tempDir, "repo_installed");
      await fs.mkdir(path.join(installedRepo, "node_modules"), { recursive: true });
      await fs.writeFile(path.join(installedRepo, "package.json"), "{}");
      await fs.writeFile(path.join(installedRepo, "pnpm-lock.yaml"), "");
      await expect(isWorkspaceNodeSyncTarget(fs, installedRepo, false)).resolves.toBe(false);
      await expect(isWorkspaceNodeSyncTarget(fs, installedRepo, true)).resolves.toBe(true);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("parses pnpm remote JSON, packageManager specs, and pnpm workspace detection", async () => {
    const remoteJson = JSON.stringify({
      package_managers: {
        pnpm: [
          { version: "12.20.0", latest: false, installed: false },
          { version: "12.21.0", latest: true, installed: true },
        ],
      },
    });
    expect(resolveLatestPnpmVersionFromJson(remoteJson)).toEqual({
      version: "12.21.0",
      installed: true,
    });
    expect(resolveLatestPnpmVersionFromJson("{bad json")).toBeNull();
    expect(resolveLatestPnpmVersionFromJson(null)).toBeNull();

    expect(parsePnpmPackageManagerSpec("pnpm@12.21.0+sha256.deadbeef")).toEqual({
      isPnpm: true,
      isOther: false,
      raw: "pnpm@12.21.0+sha256.deadbeef",
      version: "12.21.0",
    });
    expect(parsePnpmPackageManagerSpec("   ")).toEqual({
      isPnpm: false,
      isOther: false,
      raw: "",
      version: "",
    });
    expect(parsePnpmPackageManagerSpec("npm@11.0.0")).toEqual({
      isPnpm: false,
      isOther: true,
      raw: "npm@11.0.0",
      version: "",
    });

    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-nt-pnpm-"));
    try {
      const pnpmRepo = path.join(tempDir, "repo_pnpm_lock");
      await fs.mkdir(path.join(pnpmRepo, ".git"), { recursive: true });
      await fs.writeFile(path.join(pnpmRepo, "package.json"), '{"name":"a"}');
      await fs.writeFile(path.join(pnpmRepo, "pnpm-lock.yaml"), "");
      await expect(isPnpmWorkspaceProject(fs, pnpmRepo)).resolves.toBe(true);

      const otherPmRepo = path.join(tempDir, "repo_other_pm");
      await fs.mkdir(path.join(otherPmRepo, ".git"), { recursive: true });
      await fs.writeFile(
        path.join(otherPmRepo, "package.json"),
        '{"name":"b","packageManager":"npm@11.0.0"}',
      );
      await fs.writeFile(path.join(otherPmRepo, "pnpm-lock.yaml"), "");
      await expect(isPnpmWorkspaceProject(fs, otherPmRepo)).resolves.toBe(false);

      const noGitRepo = path.join(tempDir, "repo_no_git");
      await fs.mkdir(noGitRepo, { recursive: true });
      await fs.writeFile(
        path.join(noGitRepo, "package.json"),
        '{"name":"c","packageManager":"pnpm@12.21.0"}',
      );
      await expect(isPnpmWorkspaceProject(fs, noGitRepo)).resolves.toBe(false);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("formats package.json via vp fmt and reports missing or failed manifests", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-nt-fmt-"));
    try {
      const missingRun = createTestContext();
      const missingRes = await formatProjectPackageManifest(
        missingRun.ctx,
        path.join(tempDir, "missing"),
      );
      expect(missingRes.success).toBe(false);
      expect(missingRes.errorDetail).toContain("package.json not found");

      const okRepo = path.join(tempDir, "ok_repo");
      await fs.mkdir(okRepo, { recursive: true });
      await fs.writeFile(path.join(okRepo, "package.json"), '{"name":"ok"}\n');
      const okRun = createTestContext({
        runner: {
          exec: async (cmd, args) => {
            expect(cmd).toBe("vp");
            expect(args).toEqual([
              "-C",
              okRepo,
              "fmt",
              "--no-error-on-unmatched-pattern",
              "package.json",
            ]);
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(formatProjectPackageManifest(okRun.ctx, okRepo)).resolves.toEqual({
        success: true,
        errorDetail: "",
      });

      const failRun = createTestContext({
        runner: {
          exec: async () => ({ exitCode: 1, stdout: "", stderr: "invalid json" }),
        },
      });
      const failRes = await formatProjectPackageManifest(failRun.ctx, okRepo);
      expect(failRes.success).toBe(false);
      expect(failRes.errorDetail).toContain("invalid json");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("aligns global oxfmt via vp toolchain and vp list JSON contracts", async () => {
    const toolchainJson = JSON.stringify({
      schemaVersion: 1,
      nodes: [
        { id: "vite-plus", version: "1.6.0" },
        { id: "oxfmt", version: "1.2.3" },
      ],
    });

    const installedOps: string[] = [];
    const syncRun = createTestContext({
      runner: {
        commandExists: async () => true,
        exec: async (cmd, args) => {
          if (cmd === "vp" && args[0] === "toolchain") {
            return { exitCode: 0, stdout: toolchainJson, stderr: "" };
          }
          if (cmd === "vp" && args[0] === "list") {
            return {
              exitCode: 0,
              stdout: JSON.stringify([{ name: "oxfmt", version: "1.0.0" }]),
              stderr: "",
            };
          }
          if (cmd === "vp" && args[0] === "install") {
            installedOps.push(args.join(" "));
            return { exitCode: 0, stdout: "", stderr: "" };
          }
          return { exitCode: 0, stdout: "", stderr: "" };
        },
      },
    });
    await syncGlobalOxfmt(syncRun.ctx);
    expect(installedOps).toEqual(["install -g oxfmt@1.2.3"]);
    expect(syncRun.getStdout()).toBe("oxfmt: 1.0.0 -> 1.2.3\n");

    const upToDateRun = createTestContext({
      runner: {
        commandExists: async () => true,
        exec: async (cmd, args) => {
          if (cmd === "vp" && args[0] === "toolchain") {
            return { exitCode: 0, stdout: toolchainJson, stderr: "" };
          }
          if (cmd === "vp" && args[0] === "list") {
            return {
              exitCode: 0,
              stdout: JSON.stringify([{ name: "oxfmt", version: "1.2.3" }]),
              stderr: "",
            };
          }
          throw new Error(`Unexpected exec: ${cmd} ${args.join(" ")}`);
        },
      },
    });
    await syncGlobalOxfmt(upToDateRun.ctx);
    expect(upToDateRun.getStdout()).toBe("");

    const dryRun = createTestContext({
      dryRun: true,
      runner: {
        commandExists: async () => true,
        exec: async (cmd, args) => {
          if (cmd === "vp" && args[0] === "toolchain") {
            return { exitCode: 0, stdout: toolchainJson, stderr: "" };
          }
          if (cmd === "vp" && args[0] === "list") {
            return { exitCode: 0, stdout: "[]", stderr: "" };
          }
          throw new Error(`Unexpected exec in dry-run: ${cmd} ${args.join(" ")}`);
        },
      },
    });
    await syncGlobalOxfmt(dryRun.ctx);
    expect(dryRun.getStdout()).toBe("[dry-run] vp install -g oxfmt@1.2.3\n");
  });

  it("merges Windows PATH segments case-insensitively and adapts win32 CommandContext", async () => {
    expect(
      mergeWindowsPathSegments([
        "C:\\Tools;C:\\Windows\\System32",
        "c:\\tools;C:\\Users\\dev\\bin",
        "C:\\Program Files\\Git\\cmd",
      ]),
    ).toBe("C:\\Tools;C:\\Windows\\System32;C:\\Users\\dev\\bin;C:\\Program Files\\Git\\cmd");

    const { ctx: darwinCtx } = createTestContext({ platform: "darwin", env: { PATH: "/usr/bin" } });
    await expect(withWindowsMachinePath(darwinCtx)).resolves.toBe(darwinCtx);

    const { ctx: winCtx } = createTestContext({
      platform: "win32",
      env: { PATH: "C:\\Current" },
      runner: {
        exec: async (cmd) => {
          if (cmd === "powershell") {
            return {
              exitCode: 0,
              stdout: "C:\\UserBin;c:\\current\n---VP-WIN-PATH-SEP---\nC:\\MachineBin\n",
              stderr: "",
            };
          }
          return { exitCode: 0, stdout: "", stderr: "" };
        },
      },
    });
    const adapted = await withWindowsMachinePath(winCtx);
    expect(adapted.env["PATH"]).toBe("C:\\Current;C:\\UserBin;C:\\MachineBin");
  });

  it("skips local node_modules/.bin when resolving the global vp executable", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-nt-global-vp-"));
    try {
      const localBin = path.join(tempDir, "repo", "node_modules", ".bin");
      const globalBin = path.join(tempDir, "vp-home", "bin");
      await fs.mkdir(localBin, { recursive: true });
      await fs.mkdir(globalBin, { recursive: true });

      const exeName = process.platform === "win32" ? "vp.cmd" : "vp";
      const localVp = path.join(localBin, exeName);
      const globalVp = path.join(globalBin, exeName);
      await fs.writeFile(localVp, "#!/bin/sh\n", { mode: 0o755 });
      await fs.writeFile(globalVp, "#!/bin/sh\n", { mode: 0o755 });

      const sep = process.platform === "win32" ? ";" : ":";
      const resolved = await resolveGlobalVpExecutable({
        env: { PATH: `${localBin}${sep}${globalBin}` },
        platform: process.platform,
      });
      expect(resolved).toBe(globalVp);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
