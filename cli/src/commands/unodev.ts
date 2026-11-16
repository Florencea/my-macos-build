import path from "node:path";
import { z } from "zod";
import { assertRequiredCommands, defineCommand } from "../lib/cli-framework.ts";
import { ExecutionError, formatNativeErrorDetail, type CommandContext } from "../lib/context.ts";
import { formatProjectPackageManifest, withWindowsMachinePath } from "../lib/node-toolchain.ts";
import { mapWithConcurrency } from "../lib/process.ts";

const EmptyOptionsSchema = z.object({});
const PROJECT_CONCURRENCY_LIMIT = 6;

interface WorkspaceNodeProject {
  readonly name: string;
  readonly dir: string;
}

async function pathExists(fsPort: CommandContext["fs"], targetPath: string): Promise<boolean> {
  try {
    await fsPort.stat(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function isFile(fsPort: CommandContext["fs"], filePath: string): Promise<boolean> {
  try {
    const stats = await fsPort.stat(filePath);
    return stats.isFile();
  } catch {
    return false;
  }
}

async function resolveLocalNodeVersion(ctx: CommandContext): Promise<string> {
  const vpNodeRes = await ctx.runner.exec("vp", ["node", "-v"], {
    env: { VP_LOG: "error" },
  });
  if (vpNodeRes.exitCode === 0 && vpNodeRes.stdout.trim() !== "") {
    return vpNodeRes.stdout.trim();
  }

  const nodeRes = await ctx.runner.exec("node", ["-v"]);
  if (nodeRes.exitCode === 0 && nodeRes.stdout.trim() !== "") {
    return nodeRes.stdout.trim();
  }

  throw new ExecutionError("Error: Unable to determine local Node.js version", 1);
}

async function discoverNodeProjects(
  fsPort: CommandContext["fs"],
  projectsDir: string,
): Promise<readonly WorkspaceNodeProject[]> {
  const entries = await fsPort.readdir(projectsDir, { withFileTypes: true });
  const dirs = entries
    .filter((entry) => entry.isDirectory())
    .toSorted((a, b) => a.name.localeCompare(b.name));

  const checks = await Promise.all(
    dirs.map(async (entry) => {
      const dir = path.join(projectsDir, entry.name);
      const [hasGit, hasPkg] = await Promise.all([
        pathExists(fsPort, path.join(dir, ".git")),
        isFile(fsPort, path.join(dir, "package.json")),
      ]);
      return hasGit && hasPkg ? { name: entry.name, dir } : undefined;
    }),
  );

  return checks.filter((item): item is WorkspaceNodeProject => item !== undefined);
}

async function syncProjectNodeEngine(
  ctx: CommandContext,
  project: WorkspaceNodeProject,
  targetVersion: string,
): Promise<boolean> {
  const vpEnv = { VP_LOG: "error" };
  const oldVerRes = await ctx.runner.exec(
    "vp",
    ["-C", project.dir, "pm", "pkg", "get", "engines.node"],
    {
      env: vpEnv,
    },
  );
  const oldVer = oldVerRes.exitCode === 0 ? oldVerRes.stdout.trim().replace(/^"|"$/g, "") : "";

  if (oldVer === targetVersion) {
    ctx.stdout(`engines.node ${project.name}: ${oldVer} ok\n`);
    return true;
  }

  if (ctx.dryRun) {
    const label = oldVer !== "" ? oldVer : "(unset)";
    ctx.stdout(`[dry-run] engines.node ${project.name}: ${label} -> ${targetVersion}\n`);
    return true;
  }

  const dirtyRes = await ctx.runner.exec("git", [
    "-C",
    project.dir,
    "status",
    "--porcelain",
    "--",
    "package.json",
  ]);
  if (dirtyRes.exitCode !== 0) {
    const detail = formatNativeErrorDetail([dirtyRes.stderr, dirtyRes.stdout], dirtyRes.exitCode);
    ctx.stderr(`engines.node ${project.name}: git status failed (${detail})\n`);
    return false;
  }

  const hasDirtyLines = dirtyRes.stdout.split(/\r?\n/).some((line) => line.trim() !== "");
  if (hasDirtyLines) {
    ctx.stderr(
      `engines.node ${project.name}: working tree has uncommitted changes in package.json\n`,
    );
    return false;
  }

  const setRes = await ctx.runner.exec(
    "vp",
    ["-C", project.dir, "pm", "pkg", "set", `engines.node=${targetVersion}`],
    { env: vpEnv },
  );
  if (setRes.exitCode !== 0) {
    await ctx.runner.exec("git", ["-C", project.dir, "checkout", "-q", "--", "package.json"]);
    ctx.stderr(`engines.node ${project.name}: failed to update package.json\n`);
    return false;
  }

  const fmtRes = await formatProjectPackageManifest(ctx, project.dir);
  if (!fmtRes.success) {
    await ctx.runner.exec("git", ["-C", project.dir, "checkout", "-q", "--", "package.json"]);
    ctx.stderr(
      `engines.node ${project.name}: failed to format package.json (${fmtRes.errorDetail})\n`,
    );
    return false;
  }

  const statusRes = await ctx.runner.exec("git", [
    "-C",
    project.dir,
    "status",
    "--short",
    "package.json",
  ]);
  if (statusRes.stdout.trim() === "") {
    ctx.stdout(`engines.node ${project.name}: ${oldVer} -> ${targetVersion} ok\n`);
    return true;
  }

  const addRes = await ctx.runner.exec("git", ["-C", project.dir, "add", "--", "package.json"]);
  if (addRes.exitCode !== 0) {
    ctx.stderr(`engines.node ${project.name}: failed to stage package.json\n`);
    return false;
  }

  const commitRes = await ctx.runner.exec("git", [
    "-C",
    project.dir,
    "commit",
    "-q",
    "-m",
    `chore(node): Update engines.node ${oldVer} -> ${targetVersion}`,
  ]);
  if (commitRes.exitCode !== 0) {
    ctx.stderr(`engines.node ${project.name}: failed to commit\n`);
    return false;
  }

  const pushRes = await ctx.runner.exec("git", ["-C", project.dir, "push", "-q"]);
  if (pushRes.exitCode !== 0) {
    ctx.stderr(`engines.node ${project.name}: failed to push\n`);
    return false;
  }

  ctx.stdout(`engines.node ${project.name}: ${oldVer} -> ${targetVersion} ok\n`);
  return true;
}

/**
 * Syncs and updates `engines.node` in `package.json` across all local workspace Git+Node projects.
 */
export const unodevCommand = defineCommand({
  name: "unodev",
  summary:
    "Sync and update Node.js version in package.json engines.node for all local workspace projects",
  usage: "unodev [options]",
  examples: ["unodev", "unodev --dry-run"],
  flags: {},
  optionsSchema: EmptyOptionsSchema,
  positionals: { min: 0, max: 0, label: "" },
  supportsDryRun: true,
  async run({ ctx }) {
    const effectiveCtx = await withWindowsMachinePath(ctx);
    await assertRequiredCommands(effectiveCtx, ["git", "vp"]);

    const currentLocalVersion = await resolveLocalNodeVersion(effectiveCtx);
    effectiveCtx.stdout(`\nnode: ${currentLocalVersion}\n\n`);
    const nodeVersion = currentLocalVersion.replace(/^v+/, "");

    const projectsDir = path.dirname(effectiveCtx.repoRoot);
    const projects = await discoverNodeProjects(effectiveCtx.fs, projectsDir);
    if (projects.length === 0) {
      return 0;
    }

    const outcomes = await mapWithConcurrency(
      projects,
      PROJECT_CONCURRENCY_LIMIT,
      async (project) => await syncProjectNodeEngine(effectiveCtx, project, nodeVersion),
    );

    return outcomes.includes(false) ? 1 : 0;
  },
});
