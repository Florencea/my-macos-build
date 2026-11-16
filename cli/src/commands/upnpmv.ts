import path from "node:path";
import { z } from "zod";
import { assertRequiredCommands, defineCommand } from "../lib/cli-framework.ts";
import { formatNativeErrorDetail, type CommandContext } from "../lib/context.ts";
import { isDirectory, isFile } from "../lib/fs-utils.ts";
import {
  formatProjectPackageManifest,
  isPnpmWorkspaceProject,
  parsePnpmPackageManagerSpec,
  readPackageJsonManifest,
  resolveLatestPnpmVersionFromJson,
  withWindowsMachinePath,
} from "../lib/node-toolchain.ts";
import { runSequentially } from "../lib/process.ts";
import { restoreProjectManifest } from "../lib/transaction.ts";

const EmptyOptionsSchema = z.object({});

interface WorkspacePnpmProject {
  readonly name: string;
  readonly dir: string;
}

async function discoverPnpmProjects(
  fsPort: CommandContext["fs"],
  projectsDir: string,
): Promise<readonly WorkspacePnpmProject[]> {
  const entries = await fsPort.readdir(projectsDir, { withFileTypes: true });
  const dirs = entries
    .filter((entry) => entry.isDirectory())
    .toSorted((a, b) => a.name.localeCompare(b.name));

  const checks = await Promise.all(
    dirs.map(async (entry) => {
      const dir = path.join(projectsDir, entry.name);
      return (await isPnpmWorkspaceProject(fsPort, dir)) ? { name: entry.name, dir } : undefined;
    }),
  );

  return checks.filter((item): item is WorkspacePnpmProject => item !== undefined);
}

async function updateProjectPnpmVersion(
  ctx: CommandContext,
  project: WorkspacePnpmProject,
  targetVersion: string,
): Promise<boolean> {
  const pkg = await readPackageJsonManifest(ctx.fs, project.dir);
  if (pkg === null) {
    ctx.stderr(`packageManager ${project.name}: unable to read package.json\n`);
    return false;
  }

  const pmSpec = parsePnpmPackageManagerSpec(pkg.packageManager);
  const targetSpec = `pnpm@${targetVersion}`;
  const lockPath = path.join(project.dir, "pnpm-lock.yaml");
  const [hasLockfile, hasNodeModules] = await Promise.all([
    isFile(lockPath, ctx.fs),
    isDirectory(path.join(project.dir, "node_modules"), ctx.fs),
  ]);

  const vpEnv = { VP_LOG: "error" };
  const needsPin = !(pmSpec.isPnpm && pmSpec.version === targetVersion);

  if (!needsPin && hasLockfile) {
    const frozenCheckRes = await ctx.runner.exec(
      "vp",
      ["-C", project.dir, "install", "--frozen-lockfile", "--lockfile-only", "--silent"],
      { env: vpEnv },
    );
    if (frozenCheckRes.exitCode === 0) {
      if (!hasNodeModules) {
        if (ctx.dryRun) {
          ctx.stdout(`[dry-run] Sync node_modules with ${targetSpec} for ${project.name}\n`);
          return true;
        }
        const syncRes = await ctx.runner.exec(
          "vp",
          ["-C", project.dir, "install", "--frozen-lockfile", "--silent"],
          { env: vpEnv },
        );
        if (syncRes.exitCode !== 0) {
          const detail = formatNativeErrorDetail(
            [syncRes.stderr, syncRes.stdout],
            syncRes.exitCode,
          );
          ctx.stderr(`packageManager ${project.name}: failed to sync node_modules (${detail})\n`);
          return false;
        }
        ctx.stdout(`packageManager ${project.name}: ${targetSpec} (node_modules synced) ok\n`);
        return true;
      }

      ctx.stdout(`packageManager ${project.name}: ${targetSpec} ok\n`);
      return true;
    }
  }

  if (ctx.dryRun) {
    ctx.stdout(`[dry-run] Pin ${targetSpec} and sync lockfile/node_modules for ${project.name}\n`);
    return true;
  }

  const dirtyRes = await ctx.runner.exec("git", [
    "-C",
    project.dir,
    "status",
    "--porcelain",
    "--",
    "package.json",
    "pnpm-lock.yaml",
  ]);
  if (dirtyRes.exitCode !== 0) {
    const detail = formatNativeErrorDetail([dirtyRes.stderr, dirtyRes.stdout], dirtyRes.exitCode);
    ctx.stderr(`packageManager ${project.name}: git status failed (${detail})\n`);
    return false;
  }

  const hasDirtyFiles = dirtyRes.stdout.split(/\r?\n/).some((line) => line.trim() !== "");
  if (hasDirtyFiles) {
    ctx.stderr(
      `packageManager ${project.name}: working tree has uncommitted changes in package.json or pnpm-lock.yaml\n`,
    );
    return false;
  }

  const lsFilesRes = await ctx.runner.exec("git", [
    "-C",
    project.dir,
    "ls-files",
    "--error-unmatch",
    "pnpm-lock.yaml",
  ]);
  const rollbackSpec = {
    lockTrackedBefore: lsFilesRes.exitCode === 0,
    lockExistedBefore: hasLockfile,
  };

  if (needsPin) {
    const pinRes = await ctx.runner.exec(
      "vp",
      [
        "-C",
        project.dir,
        "env",
        "pin",
        targetSpec,
        "--target",
        "package-manager",
        "--force",
        "--no-install",
      ],
      { env: vpEnv },
    );
    if (pinRes.exitCode !== 0) {
      await restoreProjectManifest(ctx, project.dir, rollbackSpec);
      const detail = formatNativeErrorDetail([pinRes.stderr, pinRes.stdout], pinRes.exitCode);
      ctx.stderr(`packageManager ${project.name}: failed to pin ${targetSpec} (${detail})\n`);
      return false;
    }
  }

  const installRes = await ctx.runner.exec("vp", ["-C", project.dir, "install", "--silent"], {
    env: vpEnv,
  });
  if (installRes.exitCode !== 0) {
    await restoreProjectManifest(ctx, project.dir, rollbackSpec);
    const detail = formatNativeErrorDetail(
      [installRes.stderr, installRes.stdout],
      installRes.exitCode,
    );
    ctx.stderr(`packageManager ${project.name}: vp install failed (${detail})\n`);
    return false;
  }

  if (needsPin) {
    const fmtRes = await formatProjectPackageManifest(ctx, project.dir);
    if (!fmtRes.success) {
      await restoreProjectManifest(ctx, project.dir, rollbackSpec);
      ctx.stderr(
        `packageManager ${project.name}: failed to format package.json (${fmtRes.errorDetail})\n`,
      );
      return false;
    }
  }

  const verifyRes = await ctx.runner.exec(
    "vp",
    ["-C", project.dir, "install", "--frozen-lockfile", "--lockfile-only", "--silent"],
    { env: vpEnv },
  );
  if (verifyRes.exitCode !== 0) {
    await restoreProjectManifest(ctx, project.dir, rollbackSpec);
    const detail = formatNativeErrorDetail(
      [verifyRes.stderr, verifyRes.stdout],
      verifyRes.exitCode,
    );
    ctx.stderr(`packageManager ${project.name}: frozen lockfile verification failed (${detail})\n`);
    return false;
  }

  const statusRes = await ctx.runner.exec("git", [
    "-C",
    project.dir,
    "status",
    "--short",
    "--",
    "package.json",
    "pnpm-lock.yaml",
  ]);
  const hasGitChanges = statusRes.stdout.split(/\r?\n/).some((line) => line.trim() !== "");
  if (!hasGitChanges) {
    ctx.stdout(`packageManager ${project.name}: ${targetSpec} ok\n`);
    return true;
  }

  const filesToStage = ["package.json"];
  if (await isFile(lockPath, ctx.fs)) {
    filesToStage.push("pnpm-lock.yaml");
  }

  const addRes = await ctx.runner.exec("git", ["-C", project.dir, "add", "--", ...filesToStage]);
  if (addRes.exitCode !== 0) {
    await restoreProjectManifest(ctx, project.dir, rollbackSpec);
    ctx.stderr(`packageManager ${project.name}: failed to stage package.json / pnpm-lock.yaml\n`);
    return false;
  }

  const commitMsg = !needsPin
    ? `chore(pnpm): Sync lockfile for ${targetSpec}`
    : pmSpec.isPnpm
      ? `chore(pnpm): Update packageManager ${pmSpec.raw} -> ${targetSpec}`
      : `chore(pnpm): Pin packageManager ${targetSpec}`;

  const commitRes = await ctx.runner.exec("git", [
    "-C",
    project.dir,
    "commit",
    "-q",
    "-m",
    commitMsg,
  ]);
  if (commitRes.exitCode !== 0) {
    await ctx.runner.exec("git", ["-C", project.dir, "reset", "-q", "HEAD", "--", ...filesToStage]);
    await restoreProjectManifest(ctx, project.dir, rollbackSpec);
    ctx.stderr(`packageManager ${project.name}: failed to commit\n`);
    return false;
  }

  const upstreamRes = await ctx.runner.exec("git", [
    "-C",
    project.dir,
    "rev-parse",
    "--abbrev-ref",
    "@{u}",
  ]);
  if (upstreamRes.exitCode === 0) {
    const pushRes = await ctx.runner.exec("git", ["-C", project.dir, "push", "-q"]);
    if (pushRes.exitCode !== 0) {
      ctx.stderr(`packageManager ${project.name}: failed to push\n`);
      return false;
    }
  }

  if (pmSpec.isPnpm && needsPin) {
    ctx.stdout(`packageManager ${project.name}: ${pmSpec.raw} -> ${targetSpec} ok\n`);
  } else {
    ctx.stdout(`packageManager ${project.name}: ${targetSpec} ok\n`);
  }
  return true;
}

/**
 * Pins and upgrades `packageManager` (`pnpm`) in `package.json` and syncs lockfiles across workspace projects.
 */
export const upnpmvCommand = defineCommand({
  name: "upnpmv",
  summary:
    "Pin and upgrade packageManager (pnpm) in package.json, sync pnpm-lock.yaml and node_modules across all local workspace projects",
  usage: "upnpmv [options]",
  examples: ["upnpmv", "upnpmv --dry-run"],
  flags: {},
  optionsSchema: EmptyOptionsSchema,
  positionals: { min: 0, max: 0, label: "" },
  supportsDryRun: true,
  async run({ ctx }) {
    const effectiveCtx = await withWindowsMachinePath(ctx);
    await assertRequiredCommands(effectiveCtx, ["git", "vp"]);

    const vpEnv = { VP_LOG: "error" };
    const remoteRes = await effectiveCtx.runner.exec(
      "vp",
      ["env", "list-remote", "--json", "--sort", "desc", "pnpm"],
      { env: vpEnv },
    );
    if (remoteRes.exitCode !== 0) {
      const detail = formatNativeErrorDetail(
        [remoteRes.stderr, remoteRes.stdout],
        remoteRes.exitCode,
      );
      effectiveCtx.stderr(`Error: Failed to query remote pnpm versions (${detail})\n`);
      return 1;
    }

    const latestPnpm = resolveLatestPnpmVersionFromJson(remoteRes.stdout);
    if (latestPnpm === null) {
      effectiveCtx.stderr("Error: Unable to determine latest pnpm version from Vite+.\n");
      return 1;
    }

    const targetVersion = latestPnpm.version;
    if (!latestPnpm.installed) {
      if (effectiveCtx.dryRun) {
        effectiveCtx.stdout(`[dry-run] vp env install pnpm@${targetVersion}\n`);
      } else {
        const installRes = await effectiveCtx.runner.exec(
          "vp",
          ["env", "install", `pnpm@${targetVersion}`],
          { env: vpEnv },
        );
        if (installRes.exitCode !== 0) {
          const detail = formatNativeErrorDetail(
            [installRes.stderr, installRes.stdout],
            installRes.exitCode,
          );
          effectiveCtx.stderr(`Error: Failed to install pnpm@${targetVersion} (${detail})\n`);
          return 1;
        }
      }
    }

    effectiveCtx.stdout(`\npnpm: v${targetVersion}\n\n`);

    const projectsDir = path.dirname(effectiveCtx.repoRoot);
    const projects = await discoverPnpmProjects(effectiveCtx.fs, projectsDir);
    if (projects.length === 0) {
      return 0;
    }

    let allSucceeded = true;
    await runSequentially(projects, async (project) => {
      const ok = await updateProjectPnpmVersion(effectiveCtx, project, targetVersion);
      if (!ok) {
        allSucceeded = false;
      }
    });
    return allSucceeded ? 0 : 1;
  },
});
