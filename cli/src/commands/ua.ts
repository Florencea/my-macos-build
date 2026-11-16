import os from "node:os";
import path from "node:path";
import { z } from "zod";
import { assertRequiredCommands, defineCommand } from "../lib/cli-framework.ts";
import { formatNativeErrorDetail, type CommandContext } from "../lib/context.ts";
import {
  isWorkspaceNodeSyncTarget,
  resolveLatestPnpmVersionFromJson,
  syncGlobalOxfmt,
  withWindowsMachinePath,
} from "../lib/node-toolchain.ts";
import { mapWithConcurrency } from "../lib/process.ts";

const GIT_PULL_CONCURRENCY = 6;
const PNPM_LOCK_CONFLICT_RE =
  /ERR_PNPM_OUTDATED_LOCKFILE|ERR_PNPM_FROZEN_LOCKFILE_WITH_OUTDATED_LOCKFILE/;

const UaOptionsSchema = z.object({
  "skip-brew": z.boolean().default(false),
  "skip-winget": z.boolean().default(false),
  "skip-vite": z.boolean().default(false),
  "skip-git": z.boolean().default(false),
});

interface GitRepoEntry {
  readonly name: string;
  readonly dir: string;
}

interface GitPullResult {
  readonly name: string;
  readonly dir: string;
  readonly success: boolean;
  readonly updated: boolean;
  readonly output: string;
}

async function pathExists(fsPort: CommandContext["fs"], targetPath: string): Promise<boolean> {
  try {
    await fsPort.stat(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function isDirectory(fsPort: CommandContext["fs"], dirPath: string): Promise<boolean> {
  try {
    const stats = await fsPort.stat(dirPath);
    return stats.isDirectory();
  } catch {
    return false;
  }
}

function writeNonEmptyLines(write: (text: string) => void, text: string): void {
  const trimmed = text.trimEnd();
  if (trimmed !== "") {
    write(`${trimmed}\n`);
  }
}

async function readNodeVersion(ctx: CommandContext): Promise<string> {
  const vpRes = await ctx.runner.exec("vp", ["node", "-v"]);
  if (vpRes.exitCode === 0 && vpRes.stdout.trim() !== "") {
    return vpRes.stdout.trim();
  }
  const nodeRes = await ctx.runner.exec("node", ["-v"]);
  return nodeRes.exitCode === 0 ? nodeRes.stdout.trim() : "";
}

async function runOsPackageUpgrade(
  ctx: CommandContext,
  options: z.infer<typeof UaOptionsSchema>,
): Promise<void> {
  if (ctx.platform === "darwin" && !options["skip-brew"]) {
    await assertRequiredCommands(ctx, ["brew"]);
    const homeDir = ctx.env["HOME"] ?? os.homedir();
    if (ctx.dryRun) {
      ctx.stdout("[dry-run] brew upgrade && brew cleanup\n");
      return;
    }
    const brewEnv = {
      HOMEBREW_NO_ENV_HINTS: "1",
      HOMEBREW_NO_ASK: "1",
      HOMEBREW_AUTO_UPDATE_QUIET: "1",
      HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS: "1",
    };
    await ctx.runner.spawnInteractive("brew", ["upgrade"], { cwd: homeDir, env: brewEnv });
    await ctx.runner.spawnInteractive("brew", ["cleanup"], { cwd: homeDir, env: brewEnv });
    return;
  }

  if (ctx.platform === "win32" && !options["skip-winget"]) {
    if (await ctx.runner.commandExists("winget")) {
      if (ctx.dryRun) {
        ctx.stdout(
          "[dry-run] winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements\n",
        );
        return;
      }
      await ctx.runner.spawnInteractive("winget", [
        "upgrade",
        "--all",
        "--include-unknown",
        "--accept-package-agreements",
        "--accept-source-agreements",
      ]);
    }
  }
}

async function runViteToolchainUpgrade(ctx: CommandContext): Promise<void> {
  await assertRequiredCommands(ctx, ["vp"]);
  if (ctx.dryRun) {
    ctx.stdout(
      "[dry-run] vp upgrade && vp env install lts && vp env install pnpm@latest && sync global oxfmt\n",
    );
    return;
  }

  const upgradeRes = await ctx.runner.exec("vp", ["upgrade"]);
  writeNonEmptyLines(ctx.stdout, upgradeRes.stdout);
  writeNonEmptyLines(ctx.stdout, upgradeRes.stderr);

  const oldNode = await readNodeVersion(ctx);
  const installLtsRes = await ctx.runner.exec("vp", ["env", "install", "lts"]);
  const newNode = await readNodeVersion(ctx);

  const nodeUpdated = oldNode !== "" && oldNode !== newNode;
  if (nodeUpdated) {
    writeNonEmptyLines(ctx.stdout, installLtsRes.stdout);
    writeNonEmptyLines(ctx.stdout, installLtsRes.stderr);
  }

  let pnpmUpdated = false;
  let pnpmVersionLabel = "";

  const pnpmRemoteRes = await ctx.runner.exec("vp", [
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
        const pnpmInstallRes = await ctx.runner.exec("vp", [
          "env",
          "install",
          `pnpm@${latestPnpm.version}`,
        ]);
        writeNonEmptyLines(ctx.stdout, pnpmInstallRes.stdout);
        writeNonEmptyLines(ctx.stdout, pnpmInstallRes.stderr);
        if (pnpmInstallRes.exitCode === 0) {
          pnpmUpdated = true;
        }
      }
    }
  }

  if (pnpmVersionLabel === "") {
    const pnpmFallbackRes = await ctx.runner.exec("vp", ["env", "install", "pnpm@latest"]);
    const combined = `${pnpmFallbackRes.stdout}\n${pnpmFallbackRes.stderr}`;
    writeNonEmptyLines(ctx.stdout, pnpmFallbackRes.stdout);
    writeNonEmptyLines(ctx.stdout, pnpmFallbackRes.stderr);
    const match = combined.match(/pnpm\s+(v\d+\.\d+\.\d+(?:-[^\s.]*)?)/);
    if (match !== null && match[1] !== undefined) {
      pnpmVersionLabel = match[1];
    }
    if (pnpmFallbackRes.exitCode === 0) {
      pnpmUpdated = true;
    }
  }

  if (nodeUpdated || pnpmUpdated) {
    await ctx.runner.exec("vp", ["env", "clean"]);
  }

  if (ctx.platform === "darwin") {
    const homeDir = ctx.env["HOME"] ?? os.homedir();
    const legacyOptDir = path.join(homeDir, ".local", "opt");
    if (await isDirectory(ctx.fs, legacyOptDir)) {
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
}

async function discoverGitRepos(
  fsPort: CommandContext["fs"],
  projectsDir: string,
): Promise<readonly GitRepoEntry[]> {
  const entries = await fsPort.readdir(projectsDir, { withFileTypes: true });
  const dirs = entries
    .filter((entry) => entry.isDirectory())
    .toSorted((a, b) => a.name.localeCompare(b.name));

  const checks = await Promise.all(
    dirs.map(async (entry) => {
      const dir = path.join(projectsDir, entry.name);
      return (await pathExists(fsPort, path.join(dir, ".git")))
        ? { name: entry.name, dir }
        : undefined;
    }),
  );

  return checks.filter((item): item is GitRepoEntry => item !== undefined);
}

async function syncWorkspaceGitRepos(ctx: CommandContext, projectsDir: string): Promise<number> {
  const repos = await discoverGitRepos(ctx.fs, projectsDir);
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
      const pullRes = await ctx.runner.exec("git", ["-C", repo.dir, "pull", "--all"]);
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

  const syncTargets: GitRepoEntry[] = [];
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
    const syncSequentially = async (index: number): Promise<void> => {
      const target = syncTargets[index];
      if (target === undefined) {
        return;
      }
      const depRes = await ctx.runner.exec(
        "vp",
        ["-C", target.dir, "install", "--frozen-lockfile", "--silent"],
        { env: { VP_LOG: "error" } },
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
      await syncSequentially(index + 1);
    };
    await syncSequentially(0);
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

    await runOsPackageUpgrade(effectiveCtx, options);

    if (!options["skip-vite"]) {
      await runViteToolchainUpgrade(effectiveCtx);
    }

    if (!options["skip-git"]) {
      return await syncWorkspaceGitRepos(effectiveCtx, projectsDir);
    }

    return 0;
  },
});
