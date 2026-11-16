import os from "node:os";
import path from "node:path";

import { z } from "zod";

import { assertRequiredCommands, defineCommand } from "../lib/cli-framework.ts";
import { formatNativeErrorDetail, type CommandContext } from "../lib/context.ts";
import { isDirectory, pathExists } from "../lib/fs-utils.ts";
import {
  discoverWorkspaceProjects,
  isWorkspaceNodeSyncTarget,
  resolveActiveNodeVersion,
  resolveGlobalVpExecutable,
  resolveLatestPnpmVersionFromJson,
  syncGlobalOxfmt,
  withWindowsMachinePath,
  type WorkspaceProjectEntry,
} from "../lib/node-toolchain.ts";
import { mapWithConcurrency, runSequentially } from "../lib/process.ts";

const GIT_PULL_CONCURRENCY = 6;
const PNPM_LOCK_CONFLICT_RE =
  /ERR_PNPM_OUTDATED_LOCKFILE|ERR_PNPM_FROZEN_LOCKFILE_WITH_OUTDATED_LOCKFILE/;
const WINGET_NO_APPLICABLE_UPDATE_SIGNED = -1978335189;
const WINGET_NO_APPLICABLE_UPDATE_UNSIGNED = 2316632107;

const UaOptionsSchema = z.object({
  "skip-brew": z.boolean().default(false),
  "skip-winget": z.boolean().default(false),
  "skip-vite": z.boolean().default(false),
  "skip-git": z.boolean().default(false),
});

interface GitPullResult {
  readonly name: string;
  readonly dir: string;
  readonly success: boolean;
  readonly updated: boolean;
  readonly output: string;
}

function writeNonEmptyLines(write: (text: string) => void, text: string): void {
  const trimmed = text.trimEnd();
  if (trimmed !== "") {
    write(`${trimmed}\n`);
  }
}

async function runOsPackageUpgrade(
  ctx: CommandContext,
  options: z.infer<typeof UaOptionsSchema>,
): Promise<boolean> {
  if (ctx.platform === "darwin" && !options["skip-brew"]) {
    await assertRequiredCommands(ctx, ["brew"]);
    const homeDir = ctx.env["HOME"] ?? os.homedir();
    if (ctx.dryRun) {
      ctx.stdout("[dry-run] brew upgrade && brew cleanup\n");
      return true;
    }
    const brewEnv = {
      HOMEBREW_NO_ENV_HINTS: "1",
      HOMEBREW_NO_ASK: "1",
      HOMEBREW_AUTO_UPDATE_QUIET: "1",
      HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS: "1",
    };
    const upgradeCode = await ctx.runner.spawnInteractive("brew", ["upgrade"], {
      cwd: homeDir,
      env: brewEnv,
      signal: ctx.signal,
    });
    if (upgradeCode !== 0) {
      ctx.stderr(`Error: brew upgrade failed (exit code ${upgradeCode.toString()})\n`);
      return false;
    }
    const cleanupCode = await ctx.runner.spawnInteractive("brew", ["cleanup"], {
      cwd: homeDir,
      env: brewEnv,
      signal: ctx.signal,
    });
    if (cleanupCode !== 0) {
      ctx.stderr(`Error: brew cleanup failed (exit code ${cleanupCode.toString()})\n`);
      return false;
    }
    return true;
  }

  if (ctx.platform === "win32" && !options["skip-winget"]) {
    if (await ctx.runner.commandExists("winget")) {
      if (ctx.dryRun) {
        ctx.stdout(
          "[dry-run] winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements\n",
        );
        return true;
      }
      const wingetCode = await ctx.runner.spawnInteractive(
        "winget",
        [
          "upgrade",
          "--all",
          "--include-unknown",
          "--accept-package-agreements",
          "--accept-source-agreements",
        ],
        { signal: ctx.signal },
      );
      if (
        wingetCode !== 0 &&
        wingetCode !== WINGET_NO_APPLICABLE_UPDATE_SIGNED &&
        wingetCode !== WINGET_NO_APPLICABLE_UPDATE_UNSIGNED
      ) {
        ctx.stderr(`Error: winget upgrade failed (exit code ${wingetCode.toString()})\n`);
        return false;
      }
    }
  }
  return true;
}

async function runViteToolchainUpgrade(ctx: CommandContext): Promise<boolean> {
  const vpExe = await resolveGlobalVpExecutable(ctx);
  await assertRequiredCommands(ctx, [vpExe]);
  if (ctx.dryRun) {
    ctx.stdout(
      "[dry-run] vp upgrade && vp env install lts && vp env install pnpm@latest && sync global oxfmt\n",
    );
    return true;
  }

  let hasError = false;
  const upgradeRes = await ctx.runner.exec(vpExe, ["upgrade"], { signal: ctx.signal });
  writeNonEmptyLines(ctx.stdout, upgradeRes.stdout);
  if (upgradeRes.exitCode !== 0) {
    writeNonEmptyLines(ctx.stderr, upgradeRes.stderr);
    ctx.stderr(`Error: vp upgrade failed (exit code ${upgradeRes.exitCode.toString()})\n`);
    hasError = true;
  } else {
    writeNonEmptyLines(ctx.stdout, upgradeRes.stderr);
  }

  const oldNode = await resolveActiveNodeVersion(ctx);
  const installLtsRes = await ctx.runner.exec(vpExe, ["env", "install", "lts"], {
    signal: ctx.signal,
  });
  const newNode = await resolveActiveNodeVersion(ctx);

  const nodeUpdated = oldNode !== "" && oldNode !== newNode;
  if (installLtsRes.exitCode !== 0) {
    writeNonEmptyLines(ctx.stderr, installLtsRes.stdout);
    writeNonEmptyLines(ctx.stderr, installLtsRes.stderr);
    ctx.stderr(
      `Error: vp env install lts failed (exit code ${installLtsRes.exitCode.toString()})\n`,
    );
    hasError = true;
  } else if (nodeUpdated) {
    writeNonEmptyLines(ctx.stdout, installLtsRes.stdout);
    writeNonEmptyLines(ctx.stdout, installLtsRes.stderr);
  }

  let pnpmUpdated = false;
  let pnpmVersionLabel = "";

  const pnpmRemoteRes = await ctx.runner.exec(vpExe, [
    "env",
    "list-remote",
    "--json",
    "--sort",
    "desc",
    "pnpm",
  ]);
  if (pnpmRemoteRes.exitCode === 0) {
    const latestPnpm = resolveLatestPnpmVersionFromJson(pnpmRemoteRes.stdout);
    if (latestPnpm !== null) {
      pnpmVersionLabel = `v${latestPnpm.version}`;
      if (!latestPnpm.installed) {
        const pnpmInstallRes = await ctx.runner.exec(vpExe, [
          "env",
          "install",
          `pnpm@${latestPnpm.version}`,
        ]);
        if (pnpmInstallRes.exitCode === 0) {
          writeNonEmptyLines(ctx.stdout, pnpmInstallRes.stdout);
          writeNonEmptyLines(ctx.stdout, pnpmInstallRes.stderr);
          pnpmUpdated = true;
        } else {
          writeNonEmptyLines(ctx.stderr, pnpmInstallRes.stdout);
          writeNonEmptyLines(ctx.stderr, pnpmInstallRes.stderr);
          ctx.stderr(
            `Error: vp env install pnpm@${latestPnpm.version} failed (exit code ${pnpmInstallRes.exitCode.toString()})\n`,
          );
          hasError = true;
        }
      }
    }
  }

  if (pnpmVersionLabel === "") {
    const pnpmFallbackRes = await ctx.runner.exec(vpExe, ["env", "install", "pnpm@latest"]);
    const combined = `${pnpmFallbackRes.stdout}\n${pnpmFallbackRes.stderr}`;
    if (pnpmFallbackRes.exitCode === 0) {
      writeNonEmptyLines(ctx.stdout, pnpmFallbackRes.stdout);
      writeNonEmptyLines(ctx.stdout, pnpmFallbackRes.stderr);
      pnpmUpdated = true;
    } else {
      writeNonEmptyLines(ctx.stderr, pnpmFallbackRes.stdout);
      writeNonEmptyLines(ctx.stderr, pnpmFallbackRes.stderr);
      ctx.stderr(
        `Error: vp env install pnpm@latest failed (exit code ${pnpmFallbackRes.exitCode.toString()})\n`,
      );
      hasError = true;
    }
    const match = combined.match(/pnpm\s+(v\d+\.\d+\.\d+(?:-[^\s.]*)?)/);
    if (match !== null && match[1] !== undefined) {
      pnpmVersionLabel = match[1];
    }
  }

  if (nodeUpdated || pnpmUpdated) {
    const cleanRes = await ctx.runner.exec(vpExe, ["env", "clean"]);
    if (cleanRes.exitCode !== 0) {
      const detail = formatNativeErrorDetail([cleanRes.stderr, cleanRes.stdout], cleanRes.exitCode);
      ctx.stderr(`Warning: vp env clean failed (${detail})\n`);
    }
  }

  if (ctx.platform === "darwin") {
    const homeDir = ctx.env["HOME"] ?? os.homedir();
    const legacyOptDir = path.join(homeDir, ".local", "opt");
    if (await isDirectory(legacyOptDir, ctx.fs)) {
      const optEntries = await ctx.fs.readdir(legacyOptDir, { withFileTypes: true });
      await Promise.all(
        optEntries
          .filter((entry) => entry.name.startsWith("node"))
          .map((entry) =>
            ctx.fs
              .rm(path.join(legacyOptDir, entry.name), { recursive: true, force: true })
              .catch(() => {}),
          ),
      );
    }
  }

  await syncGlobalOxfmt(ctx);

  ctx.stdout(`\nnode: ${newNode}\n`);
  if (pnpmVersionLabel !== "") {
    ctx.stdout(`pnpm: ${pnpmVersionLabel}\n\n`);
  } else {
    ctx.stdout("\n");
  }
  return !hasError;
}

async function syncWorkspaceGitRepos(ctx: CommandContext, projectsDir: string): Promise<number> {
  const repos = await discoverWorkspaceProjects(ctx.fs, projectsDir, (dir) =>
    pathExists(path.join(dir, ".git"), ctx.fs),
  );
  const total = repos.length;
  if (total === 0) {
    return 0;
  }

  if (ctx.dryRun) {
    ctx.stdout(
      `[dry-run] git pull --all across ${total.toString()} repository(s) in ${projectsDir}\n`,
    );
    return 0;
  }

  await assertRequiredCommands(ctx, ["git"]);

  const results = await mapWithConcurrency(
    repos,
    GIT_PULL_CONCURRENCY,
    async (repo): Promise<GitPullResult> => {
      const pullRes = await ctx.runner.exec("git", ["-C", repo.dir, "pull", "--all"], {
        signal: ctx.signal,
      });
      const outText = [pullRes.stdout, pullRes.stderr].filter((s) => s !== "").join("\n");
      const isUpdated = /Updating |Fast-forward/.test(outText);
      return {
        name: repo.name,
        dir: repo.dir,
        success: pullRes.exitCode === 0,
        updated: isUpdated,
        output: outText,
      };
    },
  );

  let updatedCount = 0;
  let failedCount = 0;

  const syncEligibility = await Promise.all(
    results.map(async (res) => ({
      res,
      needsSync: res.success
        ? await isWorkspaceNodeSyncTarget(ctx.fs, res.dir, res.updated)
        : false,
    })),
  );

  const syncTargets: WorkspaceProjectEntry[] = [];
  for (const { res, needsSync } of syncEligibility) {
    if (!res.success) {
      const errDetail =
        res.output
          .split(/\r?\n/)
          .map((line) => line.trim())
          .find((line) => line !== "") ?? "unknown error";
      ctx.stderr(`Sync ${res.name} failed: ${errDetail}\n`);
      failedCount += 1;
      continue;
    }

    if (res.updated) {
      updatedCount += 1;
      ctx.stdout(`Sync ${res.name} updated\n`);
    }

    if (needsSync) {
      syncTargets.push({ name: res.name, dir: res.dir });
    }
  }

  if (syncTargets.length > 0) {
    await assertRequiredCommands(ctx, ["vp"]);
    await runSequentially(syncTargets, async (target) => {
      const depRes = await ctx.runner.exec(
        "vp",
        ["-C", target.dir, "install", "--frozen-lockfile", "--silent"],
        { env: { VP_LOG: "error" }, signal: ctx.signal },
      );
      if (depRes.exitCode !== 0) {
        const depErr = formatNativeErrorDetail([depRes.stderr, depRes.stdout], depRes.exitCode);
        ctx.stderr(`Sync ${target.name} dependencies failed: ${depErr}\n`);
        if (PNPM_LOCK_CONFLICT_RE.test(depErr)) {
          ctx.stderr(
            `  Hint: Run 'up' in ${target.name} or 'upnpmv' across workspace to sync lockfile.\n`,
          );
        }
        failedCount += 1;
      } else {
        ctx.stdout(`Sync ${target.name} dependencies ok\n`);
      }
    });
  }

  if (failedCount === 0) {
    if (updatedCount === 0) {
      ctx.stdout(`Sync workspace repositories ok (${total.toString()} projects up to date)\n`);
    } else {
      const upToDate = total - updatedCount;
      ctx.stdout(
        `Sync workspace repositories ok (${updatedCount.toString()} updated, ${upToDate.toString()} up to date)\n`,
      );
    }
    return 0;
  }

  return 1;
}

/**
 * Upgrades OS packages (Homebrew / winget), updates Vite+/Node.js/pnpm, and syncs workspace Git repos.
 */
export const uaCommand = defineCommand({
  name: "ua",
  summary:
    "Upgrade system packages (Homebrew / winget), update Vite+, Node.js (Active LTS), and pnpm, and sync git repositories",
  usage: "ua [options]",
  examples: ["ua", "ua --skip-brew --skip-git", "ua --dry-run"],
  flags: {
    "skip-brew": {
      type: "boolean",
      description: "Skip Homebrew upgrade (macOS)",
    },
    "skip-winget": {
      type: "boolean",
      description: "Skip winget upgrade (Windows)",
    },
    "skip-vite": {
      type: "boolean",
      description: "Skip Vite+ and Node.js LTS update",
    },
    "skip-git": {
      type: "boolean",
      description: "Skip workspace Git repositories sync",
    },
  },
  optionsSchema: UaOptionsSchema,
  positionals: { min: 0, max: 0, label: "" },
  supportsDryRun: true,
  async run({ options, ctx }) {
    const effectiveCtx = await withWindowsMachinePath(ctx);
    const projectsDir = path.dirname(effectiveCtx.repoRoot);

    const osOk = await runOsPackageUpgrade(effectiveCtx, options);
    const viteOk = options["skip-vite"] ? true : await runViteToolchainUpgrade(effectiveCtx);
    const gitExit = options["skip-git"]
      ? 0
      : await syncWorkspaceGitRepos(effectiveCtx, projectsDir);

    return osOk && viteOk && gitExit === 0 ? 0 : 1;
  },
});
