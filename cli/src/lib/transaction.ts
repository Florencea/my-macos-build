import path from "node:path";
import { ExecutionError, type CommandContext } from "./context.ts";

export interface BranchTransactionController {
  setStep(stepLabel: string): void;
  getStep(): string;
}

export interface BranchTransactionOptions {
  readonly tempBranch: string;
  readonly baseBranch?: string;
  readonly cwd?: string;
  readonly initialStep?: string;
  readonly onRollback?: () => Promise<void>;
}

export interface ProjectManifestRollbackSpec {
  readonly lockTrackedBefore: boolean;
  readonly lockExistedBefore: boolean;
}

async function isDirectory(fsPort: CommandContext["fs"], dirPath: string): Promise<boolean> {
  try {
    const stats = await fsPort.stat(dirPath);
    return stats.isDirectory();
  } catch {
    return false;
  }
}

/**
 * Moves `node_modules` to `.node_modules.bak` before non-Vite+ lockfile regeneration.
 */
export async function backupNodeModules(
  fsPort: CommandContext["fs"],
  projectDir: string,
): Promise<boolean> {
  const nodeModulesDir = path.join(projectDir, "node_modules");
  if (!(await isDirectory(fsPort, nodeModulesDir))) {
    return false;
  }
  const backupDir = path.join(projectDir, ".node_modules.bak");
  await fsPort.rm(backupDir, { recursive: true, force: true }).catch(() => {});
  await fsPort.rename(nodeModulesDir, backupDir);
  return true;
}

/**
 * Restores `.node_modules.bak` back to `node_modules` if present after a failed upgrade.
 */
export async function restoreNodeModulesBackup(
  fsPort: CommandContext["fs"],
  projectDir: string,
): Promise<boolean> {
  const backupDir = path.join(projectDir, ".node_modules.bak");
  if (!(await isDirectory(fsPort, backupDir))) {
    return false;
  }
  const nodeModulesDir = path.join(projectDir, "node_modules");
  await fsPort.rm(nodeModulesDir, { recursive: true, force: true }).catch(() => {});
  await fsPort.rename(backupDir, nodeModulesDir);
  return true;
}

/**
 * Deletes `.node_modules.bak` after a successful dependency sync.
 */
export async function removeNodeModulesBackup(
  fsPort: CommandContext["fs"],
  projectDir: string,
): Promise<void> {
  const backupDir = path.join(projectDir, ".node_modules.bak");
  await fsPort.rm(backupDir, { recursive: true, force: true }).catch(() => {});
}

/**
 * Restores `package.json` and `pnpm-lock.yaml` in a project directory to their pre-operation state.
 */
export async function restoreProjectManifest(
  ctx: Pick<CommandContext, "runner" | "fs">,
  projectDir: string,
  spec: ProjectManifestRollbackSpec,
): Promise<void> {
  await ctx.runner.exec("git", ["-C", projectDir, "checkout", "-q", "--", "package.json"]);
  if (spec.lockTrackedBefore) {
    await ctx.runner.exec("git", ["-C", projectDir, "checkout", "-q", "--", "pnpm-lock.yaml"]);
  } else if (!spec.lockExistedBefore) {
    const lockPath = path.join(projectDir, "pnpm-lock.yaml");
    await ctx.fs.rm(lockPath, { force: true }).catch(() => {});
  }
}

/**
 * Executes work on an isolated temporary Git branch, fast-forward merging back on success
 * or resetting and rolling back to `baseBranch` on any failure or interrupt.
 */
export async function runBranchTransaction<T>(
  ctx: Pick<CommandContext, "runner" | "stderr" | "cwd" | "isTty">,
  options: BranchTransactionOptions,
  work: (tx: BranchTransactionController) => Promise<T>,
): Promise<T> {
  const workDir = options.cwd ?? ctx.cwd;
  const baseBranch = options.baseBranch ?? "main";
  let currentStep = options.initialStep ?? "Verification";

  const controller: BranchTransactionController = {
    setStep(stepLabel: string): void {
      currentStep = stepLabel;
    },
    getStep(): string {
      return currentStep;
    },
  };

  const checkoutBranchRes = await ctx.runner.exec(
    "git",
    ["checkout", "-q", "-b", options.tempBranch],
    { cwd: workDir },
  );
  if (checkoutBranchRes.exitCode !== 0) {
    throw new ExecutionError(
      `Error: Failed to create transaction branch '${options.tempBranch}'`,
      checkoutBranchRes.exitCode,
    );
  }

  const rollback = async (): Promise<void> => {
    await ctx.runner.exec("git", ["reset", "--hard", "-q"], { cwd: workDir }).catch(() => {});
    await ctx.runner.exec("git", ["checkout", "-q", baseBranch], { cwd: workDir }).catch(() => {});
    await ctx.runner
      .exec("git", ["branch", "-D", options.tempBranch], { cwd: workDir })
      .catch(() => {});
    if (options.onRollback !== undefined) {
      await options.onRollback().catch(() => {});
    }
  };

  let result: T;
  try {
    result = await work(controller);
  } catch (err) {
    if (ctx.isTty) {
      ctx.stderr("\r\x1b[K");
    }
    ctx.stderr(
      `Error: Pre-checks failed at step '${currentStep}'. Rolling back changes to '${baseBranch}'...\n`,
    );
    await rollback();
    throw err;
  }

  const checkoutMainRes = await ctx.runner.exec("git", ["checkout", "-q", baseBranch], {
    cwd: workDir,
  });
  if (checkoutMainRes.exitCode !== 0) {
    await rollback();
    throw new ExecutionError(
      `Error: Failed to checkout '${baseBranch}' after transaction`,
      checkoutMainRes.exitCode,
    );
  }

  const mergeRes = await ctx.runner.exec("git", ["merge", "--ff-only", "-q", options.tempBranch], {
    cwd: workDir,
  });
  if (mergeRes.exitCode !== 0) {
    await rollback();
    throw new ExecutionError(
      `Error: Failed to fast-forward '${baseBranch}' from '${options.tempBranch}'`,
      mergeRes.exitCode,
    );
  }

  await ctx.runner.exec("git", ["branch", "-D", "-q", options.tempBranch], { cwd: workDir });
  return result;
}
