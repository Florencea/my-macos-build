import path from "node:path";

import { assertRequiredCommands, defineCommand } from "../lib/cli-framework.ts";
import { ExecutionError, formatErrorMessage, type CommandContext } from "../lib/context.ts";
import { isDirectory, isFile } from "../lib/fs-utils.ts";
import {
  findGitHubActionFiles,
  getGitHubActionReferences,
  getGitHubActionUpdates,
  resolveGitHubActionLatestVersions,
  restoreGitHubWorkflow,
  updateGitHubActionFiles,
  type GitHubActionVersion,
} from "../lib/github-actions.ts";
import {
  StringMapSchema,
  getGlobalVitePlusVersion,
  readPackageJsonManifest,
  resolvePlaywrightSyncStep,
  resolveProjectVerifySteps,
  withWindowsMachinePath,
} from "../lib/node-toolchain.ts";
import { runSequentially } from "../lib/process.ts";
import { withSpinner } from "../lib/spinner.ts";
import {
  backupNodeModules,
  removeNodeModulesBackup,
  restoreNodeModulesBackup,
  runBranchTransaction,
  type BranchTransactionController,
} from "../lib/transaction.ts";

const WORKFLOW_FILE_RE = /^\.github\/workflows\/[^/]+\.ya?ml$/i;

interface CiDisplayEntry {
  readonly target: string;
  readonly oldRef: string;
  readonly newRef: string;
}

class RollbackHandledError extends Error {
  constructor() {
    super("Transaction rolled back");
    this.name = "RollbackHandledError";
  }
}

class SpinnerStepError extends ExecutionError {}

async function runSpinnerStep(
  ctx: CommandContext,
  tx: BranchTransactionController,
  stepLabel: string,
  message: string,
  exe: string,
  args: readonly string[],
  extraEnv?: Readonly<Record<string, string | undefined>>,
): Promise<void> {
  tx.setStep(stepLabel);
  await withSpinner(ctx, message, async () => {
    const res = await ctx.runner.exec(exe, args, {
      cwd: ctx.cwd,
      env: { VP_LOG: "error", ...extraEnv },
      signal: ctx.signal,
    });
    if (res.exitCode !== 0) {
      const lines = [res.stdout, res.stderr]
        .join("\n")
        .split(/\r?\n/)
        .map((line) => line.trimEnd())
        .filter((line) => line !== "");
      for (const line of lines) {
        ctx.stderr(`${line}\n`);
      }
      throw new SpinnerStepError(
        `Step failed with exit code ${res.exitCode.toString()}`,
        res.exitCode,
      );
    }
  });
}

async function detectNcuUpdates(ctx: CommandContext): Promise<Record<string, string>> {
  const ncuRes = await ctx.runner.exec(
    "vpx",
    ["-s", "npm-check-updates@latest", "-t", "minor", "--install", "never", "--jsonUpgraded"],
    { cwd: ctx.cwd, signal: ctx.signal },
  );
  if (ncuRes.exitCode !== 0) {
    return {};
  }
  const trimmed = ncuRes.stdout.trim();
  if (trimmed === "" || trimmed === "{}") {
    return {};
  }
  try {
    const parsedJson: unknown = JSON.parse(trimmed);
    const validated = StringMapSchema.safeParse(parsedJson);
    return validated.success ? validated.data : {};
  } catch {
    return {};
  }
}

async function resolveVitePlusUpgrade(
  ctx: CommandContext,
  deps: Readonly<Record<string, string>>,
  devDeps: Readonly<Record<string, string>>,
): Promise<{ readonly upgraded: boolean; readonly oldVer: string; readonly newVer: string }> {
  const isVitePlus = deps["vite-plus"] !== undefined || devDeps["vite-plus"] !== undefined;
  if (!isVitePlus) {
    return { upgraded: false, oldVer: "", newVer: "" };
  }

  const globalVpVer = await getGlobalVitePlusVersion(ctx, ctx.cwd);

  let localVpVer = deps["vite-plus"] ?? devDeps["vite-plus"] ?? "";
  if (
    localVpVer === "catalog:" &&
    (await isFile(path.join(ctx.cwd, "pnpm-workspace.yaml"), ctx.fs))
  ) {
    const yqRes = await ctx.runner.exec(
      "yq",
      ['.catalog.vite-plus // .catalogs.default.vite-plus // ""', "pnpm-workspace.yaml"],
      { cwd: ctx.cwd },
    );
    if (yqRes.exitCode === 0) {
      localVpVer = yqRes.stdout.trim();
    }
  }

  if (globalVpVer !== "" && localVpVer !== "" && localVpVer !== globalVpVer) {
    return { upgraded: true, oldVer: localVpVer, newVer: globalVpVer };
  }
  return { upgraded: false, oldVer: "", newVer: "" };
}

async function commitChangesIfDirty(input: {
  readonly ctx: CommandContext;
  readonly tx: BranchTransactionController;
  readonly stepLabel: string;
  readonly title: string;
  readonly bodyLines: readonly string[];
  readonly includeBody: boolean;
  readonly actionTag: string;
  readonly createdCommits: string[];
}): Promise<void> {
  const statusRes = await input.ctx.runner.exec("git", ["status", "--porcelain"], {
    cwd: input.ctx.cwd,
  });
  if (statusRes.stdout.trim() === "") {
    return;
  }

  const commitMsg = input.includeBody
    ? `${input.title}\n\nUpgrade details:\n${input.bodyLines.join("\n")}`
    : input.title;

  input.tx.setStep(input.stepLabel);
  const addRes = await input.ctx.runner.exec("git", ["add", "-A"], { cwd: input.ctx.cwd });
  if (addRes.exitCode !== 0) {
    throw new ExecutionError(`git add (${input.actionTag}) failed`, addRes.exitCode);
  }
  const commitRes = await input.ctx.runner.exec("git", ["commit", "-q", "-m", commitMsg], {
    cwd: input.ctx.cwd,
  });
  if (commitRes.exitCode !== 0) {
    throw new ExecutionError(`git commit (${input.actionTag}) failed`, commitRes.exitCode);
  }
  input.createdCommits.push(input.title);
}

/**
 * Checks and updates Node.js package dependencies and GitHub Actions exact versions
 * inside a transactional Git branch with automated verification and rollback.
 */
export const upCommand = defineCommand({
  name: "up",
  summary:
    "Check and update Node.js package dependencies and GitHub Actions exact versions with clean spinner feedback",
  usage: "up [options]",
  examples: ["up", "up --dry-run"],
  flags: {},
  positionals: { min: 0, max: 0, label: "" },
  supportsDryRun: true,
  async run({ ctx }) {
    const effectiveCtx = await withWindowsMachinePath(ctx);
    await assertRequiredCommands(effectiveCtx, ["git", "vp", "vpr", "vpx", "yq"]);

    const initialPkg = await readPackageJsonManifest(effectiveCtx.fs, effectiveCtx.cwd);
    if (initialPkg === null) {
      effectiveCtx.stderr("Error: File package.json does not exist\n");
      return 1;
    }

    const branchRes = await effectiveCtx.runner.exec("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
      cwd: effectiveCtx.cwd,
    });
    const currentBranch = branchRes.stdout.trim();
    if (branchRes.exitCode !== 0 || currentBranch !== "main") {
      effectiveCtx.stderr(`Error: Current branch is not 'main' (${currentBranch})\n`);
      return 1;
    }

    const dirtyRes = await effectiveCtx.runner.exec("git", ["status", "--porcelain"], {
      cwd: effectiveCtx.cwd,
    });
    if (dirtyRes.stdout.trim() !== "") {
      effectiveCtx.stderr(
        "Error: Working directory is not clean. Please commit or stash your changes first.\n",
      );
      return 1;
    }

    const upstreamRes = await effectiveCtx.runner.exec(
      "git",
      ["rev-parse", "--abbrev-ref", "@{u}"],
      { cwd: effectiveCtx.cwd },
    );
    const hasUpstream = upstreamRes.exitCode === 0;
    if (hasUpstream && !effectiveCtx.dryRun) {
      const fetchRes = await effectiveCtx.runner.exec(
        "git",
        ["fetch", "--tags", "--force", "--quiet"],
        { cwd: effectiveCtx.cwd },
      );
      if (fetchRes.exitCode !== 0) {
        effectiveCtx.stderr("Error: Failed to fetch remote tags.\n");
        return 1;
      }
      const pullRes = await effectiveCtx.runner.exec("git", ["pull", "--ff-only", "--quiet"], {
        cwd: effectiveCtx.cwd,
      });
      if (pullRes.exitCode !== 0) {
        effectiveCtx.stderr(
          "Error: Cannot fast-forward with remote. Please sync your branch first.\n",
        );
        return 1;
      }
    }

    const deps = initialPkg.dependencies ?? {};
    const devDeps = initialPkg.devDependencies ?? {};
    const peerDeps = initialPkg.peerDependencies ?? {};
    const optDeps = initialPkg.optionalDependencies ?? {};
    const isVitePlus = deps["vite-plus"] !== undefined || devDeps["vite-plus"] !== undefined;

    const vpUpgrade = await resolveVitePlusUpgrade(effectiveCtx, deps, devDeps);
    const ncuMap = await detectNcuUpdates(effectiveCtx);
    const ncuEntries = Object.entries(ncuMap);

    let hasLockfileDrift = false;
    if (await isFile(path.join(effectiveCtx.cwd, "pnpm-lock.yaml"), effectiveCtx.fs)) {
      const driftRes = await effectiveCtx.runner.exec(
        "vp",
        ["install", "--frozen-lockfile", "--lockfile-only", "--silent"],
        { cwd: effectiveCtx.cwd, env: { VP_LOG: "error" } },
      );
      hasLockfileDrift = driftRes.exitCode !== 0;
    }

    const hasDepUpdates = vpUpgrade.upgraded || ncuEntries.length > 0 || hasLockfileDrift;

    const isGitHubActionsRepo = await isDirectory(
      path.join(effectiveCtx.cwd, "actions"),
      effectiveCtx.fs,
    );
    const ciFiles = isGitHubActionsRepo
      ? []
      : await findGitHubActionFiles(effectiveCtx, effectiveCtx.cwd);

    const latestByMajorByRepo = new Map<string, ReadonlyMap<number, GitHubActionVersion>>();
    let ciUpdates: ReturnType<typeof getGitHubActionUpdates> = [];
    const ciDisplayEntries: CiDisplayEntry[] = [];
    const seenCiKeys = new Set<string>();

    if (ciFiles.length > 0) {
      const ciRefs = await getGitHubActionReferences(effectiveCtx, ciFiles, effectiveCtx.cwd);
      if (ciRefs.length > 0) {
        const repoSlugs = ciRefs.map((item) => item.repoSlug);
        const repoResults = await resolveGitHubActionLatestVersions(effectiveCtx, repoSlugs);
        const uniqueSortedSlugs = [...new Set(repoSlugs)].toSorted((a, b) => a.localeCompare(b));

        for (const slug of uniqueSortedSlugs) {
          const res = repoResults.get(slug);
          if (res === undefined) {
            continue;
          }
          if (!res.success) {
            effectiveCtx.stderr(`Warning: Failed to query tags for ${slug}: ${res.error}\n`);
          } else if (res.latestByMajor.size > 0) {
            latestByMajorByRepo.set(slug, res.latestByMajor);
          }
        }

        ciUpdates = getGitHubActionUpdates(ciRefs, latestByMajorByRepo);
        for (const item of ciUpdates) {
          const key = `${item.actionTarget}|${item.oldRef}|${item.newRef}`;
          if (!seenCiKeys.has(key)) {
            seenCiKeys.add(key);
            ciDisplayEntries.push({
              target: item.actionTarget,
              oldRef: item.oldRef,
              newRef: item.newRef,
            });
          }
        }
      }
    }

    const hasCiUpdates = ciUpdates.length > 0;
    if (!hasDepUpdates && !hasCiUpdates) {
      return 0;
    }

    let depCount = 0;
    const depCommitBodyLines: string[] = [];
    let singlePkgSummary = "";
    let hasVitePlusInTargets = false;

    for (const [pkgName, newVer] of ncuEntries) {
      const oldVer =
        deps[pkgName] ?? devDeps[pkgName] ?? peerDeps[pkgName] ?? optDeps[pkgName] ?? "?";
      if (pkgName === "vite-plus") {
        hasVitePlusInTargets = true;
      }
      effectiveCtx.stdout(`  ${pkgName}  ${oldVer}  ->  ${newVer}\n`);
      depCommitBodyLines.push(`- ${pkgName}: ${oldVer} -> ${newVer}`);
      singlePkgSummary = `${pkgName} ${oldVer} -> ${newVer}`;
      depCount += 1;
    }

    if (vpUpgrade.upgraded && !hasVitePlusInTargets) {
      effectiveCtx.stdout(`  vite-plus  ${vpUpgrade.oldVer}  ->  ${vpUpgrade.newVer}\n`);
      depCommitBodyLines.push(`- vite-plus: ${vpUpgrade.oldVer} -> ${vpUpgrade.newVer}`);
      singlePkgSummary = `vite-plus ${vpUpgrade.oldVer} -> ${vpUpgrade.newVer}`;
      depCount += 1;
    }

    let ciCount = 0;
    const ciCommitBodyLines: string[] = [];
    let singleCiSummary = "";

    for (const entry of ciDisplayEntries) {
      effectiveCtx.stdout(`  ${entry.target}  ${entry.oldRef}  ->  ${entry.newRef}\n`);
      ciCommitBodyLines.push(`- ${entry.target}: ${entry.oldRef} -> ${entry.newRef}`);
      singleCiSummary = `${entry.target} ${entry.oldRef} -> ${entry.newRef}`;
      ciCount += 1;
    }

    if (effectiveCtx.dryRun) {
      effectiveCtx.stdout(
        `[dry-run] Would run transactional upgrade on branch chore/deps-upgrade-... (deps=${String(hasDepUpdates)}, ci=${String(hasCiUpdates)})\n`,
      );
      return 0;
    }

    const epochSeconds = Math.floor(effectiveCtx.now().getTime() / 1000);
    const tempBranch = `chore/deps-upgrade-${epochSeconds.toString()}`;
    const createdCommits: string[] = [];

    try {
      await runBranchTransaction(
        effectiveCtx,
        {
          tempBranch,
          baseBranch: "main",
          cwd: effectiveCtx.cwd,
          onSignalCleanup: effectiveCtx.onSignalCleanup,
          onRollback: async () => {
            const restoredBackup = await restoreNodeModulesBackup(
              effectiveCtx.fs,
              effectiveCtx.cwd,
            );
            if (!restoredBackup && hasDepUpdates) {
              await effectiveCtx.runner.exec("vp", ["install", "--frozen-lockfile", "--silent"], {
                cwd: effectiveCtx.cwd,
                env: { VP_LOG: "error" },
              });
            }
          },
        },
        async (tx) => {
          try {
            if (hasDepUpdates) {
              if (isVitePlus) {
                if (vpUpgrade.upgraded || ncuEntries.length > 0) {
                  await runSpinnerStep(
                    effectiveCtx,
                    tx,
                    "vp migrate --no-interactive",
                    "Aligning Vite+ toolchain (vp migrate)",
                    "vp",
                    ["migrate", "--no-interactive"],
                  );

                  tx.setStep("Restore GitHub Actions workflows");
                  await restoreGitHubWorkflow(effectiveCtx, {
                    includeActionsDir: isGitHubActionsRepo,
                    cwd: effectiveCtx.cwd,
                  });

                  if (ncuEntries.length > 0) {
                    await runSpinnerStep(
                      effectiveCtx,
                      tx,
                      "vpx npm-check-updates",
                      "Updating packages (NCU)",
                      "vpx",
                      ["-s", "npm-check-updates@latest", "-u", "-t", "minor"],
                    );
                  }

                  await runSpinnerStep(
                    effectiveCtx,
                    tx,
                    "vp pm pkg fix",
                    "Normalizing manifest (vp pm pkg fix)",
                    "vp",
                    ["pm", "pkg", "fix"],
                  );
                }

                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  "vp install",
                  "Syncing dependencies (vp install)",
                  "vp",
                  ["install"],
                );

                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  "vp install (frozen verification)",
                  "Verifying frozen lockfile",
                  "vp",
                  ["install", "--frozen-lockfile"],
                );
              } else {
                if (ncuEntries.length > 0) {
                  await runSpinnerStep(
                    effectiveCtx,
                    tx,
                    "vpx npm-check-updates",
                    "Updating packages (NCU)",
                    "vpx",
                    ["-s", "npm-check-updates@latest", "-u", "-t", "minor"],
                  );

                  await runSpinnerStep(
                    effectiveCtx,
                    tx,
                    "vp pm pkg fix",
                    "Normalizing manifest (vp pm pkg fix)",
                    "vp",
                    ["pm", "pkg", "fix"],
                  );
                }

                await backupNodeModules(effectiveCtx.fs, effectiveCtx.cwd);
                await effectiveCtx.fs
                  .rm(path.join(effectiveCtx.cwd, "package-lock.json"), { force: true })
                  .catch(() => {});

                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  "vp install (lockfile update)",
                  "Writing lockfile",
                  "vp",
                  ["install", "--lockfile-only", "--ignore-scripts"],
                );

                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  "vp install",
                  "Syncing dependencies (vp install)",
                  "vp",
                  ["install", "--frozen-lockfile"],
                );

                await removeNodeModulesBackup(effectiveCtx.fs, effectiveCtx.cwd);
              }

              const reloadedPkg = await readPackageJsonManifest(effectiveCtx.fs, effectiveCtx.cwd);
              const reloadedDeps = reloadedPkg?.dependencies ?? {};
              const reloadedDevDeps = reloadedPkg?.devDependencies ?? {};
              const scriptsMap = reloadedPkg?.scripts ?? {};

              await runSpinnerStep(
                effectiveCtx,
                tx,
                "vp fmt",
                "Formatting code & configs (vp fmt)",
                "vp",
                ["fmt"],
              );

              if (hasCiUpdates || isGitHubActionsRepo) {
                tx.setStep("Restore GitHub Actions workflows before deps commit");
                await restoreGitHubWorkflow(effectiveCtx, {
                  includeActionsDir: isGitHubActionsRepo,
                  cwd: effectiveCtx.cwd,
                });
              }

              await runSpinnerStep(
                effectiveCtx,
                tx,
                "vp check",
                "Checking quality & lint (vp check)",
                "vp",
                ["check", "--quiet", "--no-error-on-unmatched-pattern"],
              );

              if (scriptsMap["lint:tailwind"] !== undefined) {
                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  "vpr lint:tailwind (lint)",
                  "Verifying additional lint rules",
                  "vpr",
                  ["lint:tailwind"],
                );
              }

              if (!hasCiUpdates) {
                const ciLintScript = ["agent:lint:ci", "lint:ci"].find(
                  (candidate) => scriptsMap[candidate] !== undefined,
                );
                if (ciLintScript !== undefined) {
                  await runSpinnerStep(
                    effectiveCtx,
                    tx,
                    `vpr ${ciLintScript} (lint)`,
                    "Verifying CI workflow rules",
                    "vpr",
                    [ciLintScript],
                  );
                }
              }

              const typecheckScript = ["agent:typecheck", "typecheck"].find(
                (candidate) => scriptsMap[candidate] !== undefined,
              );
              if (typecheckScript !== undefined) {
                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  `vpr ${typecheckScript} (typecheck)`,
                  "Verifying types",
                  "vpr",
                  [typecheckScript],
                );
              } else if (
                reloadedDeps["typescript"] !== undefined ||
                reloadedDevDeps["typescript"] !== undefined
              ) {
                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  "vpx tsc --noEmit",
                  "Verifying types",
                  "vpx",
                  ["tsc", "--noEmit"],
                );
              }

              const deadcodeScript = ["check:deadcode", "knip"].find(
                (candidate) => scriptsMap[candidate] !== undefined,
              );
              if (deadcodeScript !== undefined) {
                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  `vpr ${deadcodeScript} (deadcode)`,
                  "Verifying dead code",
                  "vpr",
                  [deadcodeScript],
                );
              }

              if (reloadedPkg !== null) {
                const pwStep = await resolvePlaywrightSyncStep(
                  reloadedPkg,
                  effectiveCtx.cwd,
                  effectiveCtx.fs,
                );
                if (pwStep !== null) {
                  await runSpinnerStep(
                    effectiveCtx,
                    tx,
                    pwStep.stepLabel,
                    "Syncing Playwright browsers",
                    pwStep.exe,
                    pwStep.args,
                    { PLAYWRIGHT_SKIP_BROWSER_GC: "1" },
                  );
                }
              }

              const verifySteps = resolveProjectVerifySteps(scriptsMap);
              await runSequentially(verifySteps, async (step) => {
                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  step.stepLabel,
                  step.message,
                  step.exe,
                  step.args,
                );
              });

              const depCommitTitle =
                depCount === 0
                  ? "chore: sync lockfile"
                  : depCount === 1
                    ? `chore(deps): update dependency ${singlePkgSummary}`
                    : `chore(deps): update dependencies (${depCount.toString()} packages)`;
              await commitChangesIfDirty({
                ctx: effectiveCtx,
                tx,
                stepLabel: "git commit (deps)",
                title: depCommitTitle,
                bodyLines: depCommitBodyLines,
                includeBody: depCount > 1,
                actionTag: "deps",
                createdCommits,
              });
            }

            if (hasCiUpdates) {
              const workflowFiles = ciFiles.filter((filePath) => WORKFLOW_FILE_RE.test(filePath));
              if (
                workflowFiles.length > 0 &&
                !(await effectiveCtx.runner.commandExists("actionlint"))
              ) {
                tx.setStep("actionlint pre-check");
                throw new ExecutionError("actionlint is not installed", 1);
              }

              tx.setStep("Update GitHub Actions versions");
              const freshCiRefs = await getGitHubActionReferences(
                effectiveCtx,
                ciFiles,
                effectiveCtx.cwd,
              );
              const updatesToApply = getGitHubActionUpdates(freshCiRefs, latestByMajorByRepo);
              const changedCiFiles = await updateGitHubActionFiles(
                effectiveCtx,
                updatesToApply,
                effectiveCtx.cwd,
              );

              if (changedCiFiles.length > 0) {
                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  "vp fmt (CI)",
                  "Formatting GitHub Actions files (vp fmt)",
                  "vp",
                  ["fmt", "--no-error-on-unmatched-pattern", ...changedCiFiles],
                );
              }

              if (workflowFiles.length > 0) {
                await runSpinnerStep(
                  effectiveCtx,
                  tx,
                  "actionlint",
                  "Verifying GitHub Actions workflows (actionlint)",
                  "actionlint",
                  [],
                );
              }

              const ciCommitTitle =
                ciCount === 1
                  ? `chore(ci): update action ${singleCiSummary}`
                  : `chore(ci): update GitHub Actions (${ciCount.toString()} actions)`;
              await commitChangesIfDirty({
                ctx: effectiveCtx,
                tx,
                stepLabel: "git commit (ci)",
                title: ciCommitTitle,
                bodyLines: ciCommitBodyLines,
                includeBody: ciCount !== 1,
                actionTag: "ci",
                createdCommits,
              });
            }
          } catch (err) {
            if (!(err instanceof SpinnerStepError)) {
              effectiveCtx.stderr(`Error: ${formatErrorMessage(err)}\n`);
            }
            throw new RollbackHandledError();
          }
        },
      );
    } catch (err) {
      if (err instanceof RollbackHandledError) {
        return 1;
      }
      throw err;
    }

    if (createdCommits.length > 0) {
      if (hasUpstream) {
        await withSpinner(effectiveCtx, "Pushing to remote", async () => {
          const pushRes = await effectiveCtx.runner.exec("git", ["push", "-q", "origin", "main"], {
            cwd: effectiveCtx.cwd,
          });
          if (pushRes.exitCode !== 0) {
            throw new ExecutionError("git push failed", pushRes.exitCode);
          }
        });
        for (const title of createdCommits) {
          effectiveCtx.stdout(`Pushed: ${title}\n`);
        }
      } else {
        for (const title of createdCommits) {
          effectiveCtx.stdout(`Committed and merged: ${title}\n`);
        }
      }
    }

    return 0;
  },
});
