import path from "node:path";
import { z } from "zod";
import { ExecutionError, formatNativeErrorDetail, type CommandContext } from "./context.ts";
import { isDirectory } from "./fs-utils.ts";
import { mapWithConcurrency } from "./process.ts";

const GITHUB_WORKFLOW_OR_ACTION_RE = /^\.github\/(workflows\/[^/]+\.ya?ml|(.+\/)?action\.ya?ml)$/i;
const VERSION_REF_RE = /^(v)?(\d+)(?:\.(\d+)(?:\.(\d+))?)?$/;
const USES_TARGET_RE = /^([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)(?:\/([^@]+))?@(.+)$/;
const TAG_LINE_RE = /\trefs\/tags\/([^\s]+)$/;
const YQ_USES_QUERY =
  '[(.jobs[]?.uses, .jobs[]?.steps[]?.uses, .runs?.steps[]?.uses) | select(. != null and tag == "!!str") | {"uses": ., "line": line}]';
const TAG_QUERY_CONCURRENCY = 6;

const YqUsesItemSchema = z.object({
  uses: z.string(),
  line: z.number().int().positive(),
});
const YqUsesArraySchema = z.array(YqUsesItemSchema);

export interface GitHubActionVersion {
  readonly raw: string;
  readonly major: number;
  readonly minor: number;
  readonly patch: number;
  readonly precision: 1 | 2 | 3;
}

export interface GitHubActionReference {
  readonly filePath: string;
  readonly line: number;
  readonly oldUses: string;
  readonly repoSlug: string;
  readonly actionTarget: string;
  readonly currentRef: string;
  readonly currentVersion: GitHubActionVersion;
}

export interface RepoActionVersionResult {
  readonly repoSlug: string;
  readonly success: boolean;
  readonly latestByMajor: ReadonlyMap<number, GitHubActionVersion>;
  readonly error: string;
}

export interface GitHubActionUpdate {
  readonly filePath: string;
  readonly line: number;
  readonly oldUses: string;
  readonly newUses: string;
  readonly repoSlug: string;
  readonly actionTarget: string;
  readonly oldRef: string;
  readonly newRef: string;
}

function escapeRegExp(literal: string): string {
  return literal.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Restores `.github` workflow/action files (and optionally `actions/`) modified by `vp migrate` or `vp fmt`.
 */
export async function restoreGitHubWorkflow(
  ctx: CommandContext,
  options?: { readonly includeActionsDir?: boolean; readonly cwd?: string },
): Promise<void> {
  const workDir = options?.cwd ?? ctx.cwd;
  const includeActionsDir = options?.includeActionsDir ?? false;

  const pathsToInspect: string[] = [];
  if (await isDirectory(path.join(workDir, ".github"), ctx.fs)) {
    pathsToInspect.push(".github");
  }
  if (includeActionsDir && (await isDirectory(path.join(workDir, "actions"), ctx.fs))) {
    pathsToInspect.push("actions");
  }
  if (pathsToInspect.length === 0) {
    return;
  }

  const diffRes = await ctx.runner.exec(
    "git",
    ["-c", "core.quotePath=false", "diff", "--relative", "--name-only", "--", ...pathsToInspect],
    { cwd: workDir },
  );
  if (diffRes.exitCode !== 0) {
    throw new ExecutionError(
      "Failed to inspect GitHub Actions workflow changes after vp migrate",
      diffRes.exitCode,
    );
  }

  const changedWorkflowFiles = diffRes.stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(
      (line) =>
        line !== "" &&
        (GITHUB_WORKFLOW_OR_ACTION_RE.test(line) ||
          (includeActionsDir && /^actions\//i.test(line))),
    );

  if (changedWorkflowFiles.length === 0) {
    return;
  }

  const checkoutRes = await ctx.runner.exec(
    "git",
    ["checkout", "-q", "--", ...changedWorkflowFiles],
    { cwd: workDir },
  );
  if (checkoutRes.exitCode !== 0) {
    throw new ExecutionError(
      "Failed to restore GitHub Actions workflow files after vp migrate",
      checkoutRes.exitCode,
    );
  }
}

/**
 * Recursively locates `.github/workflows/*.yml` and `.github/**\/action.yml` files relative to `projectDir`.
 */
export async function findGitHubActionFiles(
  ctx: Pick<CommandContext, "fs" | "cwd">,
  projectDir = ctx.cwd,
): Promise<readonly string[]> {
  const githubDir = path.join(projectDir, ".github");
  if (!(await isDirectory(githubDir, ctx.fs))) {
    return [];
  }

  const collected: string[] = [];
  const walk = async (dirPath: string): Promise<void> => {
    const entries = await ctx.fs.readdir(dirPath, { withFileTypes: true });
    const subdirs: string[] = [];
    for (const entry of entries) {
      const fullPath = path.join(dirPath, entry.name);
      if (entry.isDirectory()) {
        subdirs.push(fullPath);
      } else if (entry.isFile() && /\.ya?ml$/i.test(entry.name)) {
        const relPath = path.relative(projectDir, fullPath).replace(/\\/g, "/");
        if (GITHUB_WORKFLOW_OR_ACTION_RE.test(relPath)) {
          collected.push(relPath);
        }
      }
    }
    await Promise.all(subdirs.map((sub) => walk(sub)));
  };

  await walk(githubDir);
  return collected.toSorted((a, b) => a.localeCompare(b));
}

/**
 * Parses a GitHub Action tag ref (`v4`, `v4.2`, `v4.2.1`, or `4.2`) while rejecting SHAs and bare integers.
 */
export function parseGitHubActionVersion(ref: string): GitHubActionVersion | null {
  const match = ref.match(VERSION_REF_RE);
  if (match === null) {
    return null;
  }

  const hasVPrefix = match[1] !== undefined && match[1] !== "";
  const minorText = match[3];
  const patchText = match[4];
  const hasMinor = minorText !== undefined;
  const hasPatch = patchText !== undefined;

  if (!hasVPrefix && !hasMinor) {
    return null;
  }

  const majorText = match[2];
  if (majorText === undefined) {
    return null;
  }

  const precision: 1 | 2 | 3 = hasPatch ? 3 : hasMinor ? 2 : 1;
  return {
    raw: ref,
    major: Number.parseInt(majorText, 10),
    minor: hasMinor ? Number.parseInt(minorText, 10) : 0,
    patch: hasPatch ? Number.parseInt(patchText, 10) : 0,
    precision,
  };
}

/**
 * Compares two parsed GitHub Action versions across major, minor, patch, and precision.
 */
export function compareGitHubActionVersion(
  left: GitHubActionVersion,
  right: GitHubActionVersion,
): -1 | 0 | 1 {
  const fields: readonly (keyof Omit<GitHubActionVersion, "raw">)[] = [
    "major",
    "minor",
    "patch",
    "precision",
  ];
  for (const field of fields) {
    if (left[field] !== right[field]) {
      return left[field] > right[field] ? 1 : -1;
    }
  }
  return 0;
}

/**
 * Extracts versioned `uses:` references from workflow/action YAML files via `yq` with Zod validation.
 */
export async function getGitHubActionReferences(
  ctx: Pick<CommandContext, "runner" | "cwd">,
  filePaths: readonly string[],
  projectDir = ctx.cwd,
): Promise<readonly GitHubActionReference[]> {
  const perFileRefs = await Promise.all(
    filePaths.map(async (relPath): Promise<readonly GitHubActionReference[]> => {
      const absPath = path.resolve(projectDir, relPath);
      const yqRes = await ctx.runner.exec("yq", ["-o=json", YQ_USES_QUERY, absPath], {
        cwd: projectDir,
      });
      if (yqRes.exitCode !== 0) {
        const detail = formatNativeErrorDetail([yqRes.stderr, yqRes.stdout], yqRes.exitCode);
        throw new ExecutionError(
          `Failed to parse YAML file '${relPath}': ${detail}`,
          yqRes.exitCode,
        );
      }

      const trimmed = yqRes.stdout.trim();
      if (trimmed === "" || trimmed === "[]") {
        return [];
      }

      let parsedJson: unknown;
      try {
        parsedJson = JSON.parse(trimmed);
      } catch {
        throw new ExecutionError(`Failed to parse JSON from yq output for '${relPath}'`, 1);
      }

      const validated = YqUsesArraySchema.safeParse(parsedJson);
      if (!validated.success) {
        throw new ExecutionError(`Unexpected yq output structure for '${relPath}'`, 1);
      }

      const fileRefs: GitHubActionReference[] = [];
      for (const item of validated.data) {
        const usesValue = item.uses;
        if (
          usesValue === "" ||
          usesValue.startsWith(".") ||
          usesValue.startsWith("docker://") ||
          !usesValue.includes("@")
        ) {
          continue;
        }

        const match = usesValue.match(USES_TARGET_RE);
        if (match === null) {
          continue;
        }
        const repoSlug = match[1];
        const subpath = match[2] ?? "";
        const currentRef = match[3];
        if (repoSlug === undefined || currentRef === undefined) {
          continue;
        }

        const currentVersion = parseGitHubActionVersion(currentRef);
        if (currentVersion === null) {
          continue;
        }

        const actionTarget = subpath !== "" ? `${repoSlug}/${subpath}` : repoSlug;
        fileRefs.push({
          filePath: relPath,
          line: item.line,
          oldUses: usesValue,
          repoSlug,
          actionTarget,
          currentRef,
          currentVersion,
        });
      }
      return fileRefs;
    }),
  );

  return perFileRefs.flat();
}

/**
 * Resolves the latest tag per major version for each unique GitHub Action repository in parallel.
 */
export async function resolveGitHubActionLatestVersions(
  ctx: Pick<CommandContext, "runner">,
  repoSlugs: readonly string[],
): Promise<ReadonlyMap<string, RepoActionVersionResult>> {
  const uniqueRepos = [...new Set(repoSlugs)].toSorted((a, b) => a.localeCompare(b));
  const resultMap = new Map<string, RepoActionVersionResult>();
  if (uniqueRepos.length === 0) {
    return resultMap;
  }

  const queried = await mapWithConcurrency(uniqueRepos, TAG_QUERY_CONCURRENCY, async (slug) => {
    const lsRes = await ctx.runner.exec(
      "git",
      [
        "-c",
        "credential.interactive=never",
        "ls-remote",
        "--tags",
        "--refs",
        `https://github.com/${slug}.git`,
      ],
      { env: { GIT_TERMINAL_PROMPT: "0" } },
    );

    if (lsRes.exitCode !== 0) {
      const firstLine =
        lsRes.stderr
          .split(/\r?\n/)
          .concat(lsRes.stdout.split(/\r?\n/))
          .map((line) => line.trim())
          .find((line) => line !== "") ?? `exit code ${lsRes.exitCode.toString()}`;
      return {
        repoSlug: slug,
        success: false,
        latestByMajor: new Map<number, GitHubActionVersion>(),
        error: firstLine,
      };
    }

    const latestByMajor = new Map<number, GitHubActionVersion>();
    for (const line of lsRes.stdout.split(/\r?\n/)) {
      const tagMatch = line.match(TAG_LINE_RE);
      const tagName = tagMatch?.[1];
      if (tagName === undefined) {
        continue;
      }
      const parsed = parseGitHubActionVersion(tagName);
      if (parsed === null) {
        continue;
      }
      const existing = latestByMajor.get(parsed.major);
      if (existing === undefined || compareGitHubActionVersion(parsed, existing) > 0) {
        latestByMajor.set(parsed.major, parsed);
      }
    }

    return {
      repoSlug: slug,
      success: true,
      latestByMajor,
      error: "",
    };
  });

  for (const entry of queried) {
    resultMap.set(entry.repoSlug, entry);
  }
  return resultMap;
}

/**
 * Computes candidate same-major version upgrades for parsed GitHub Action references.
 */
export function getGitHubActionUpdates(
  references: readonly GitHubActionReference[],
  latestByMajorByRepo: ReadonlyMap<string, ReadonlyMap<number, GitHubActionVersion>>,
): readonly GitHubActionUpdate[] {
  const updates: GitHubActionUpdate[] = [];

  for (const refItem of references) {
    const majorMap = latestByMajorByRepo.get(refItem.repoSlug);
    if (majorMap === undefined) {
      continue;
    }

    const latestVersion = majorMap.get(refItem.currentVersion.major);
    if (latestVersion === undefined) {
      continue;
    }

    const cmp = compareGitHubActionVersion(latestVersion, refItem.currentVersion);
    if (cmp > 0 || (cmp === 0 && refItem.currentRef !== latestVersion.raw)) {
      updates.push({
        filePath: refItem.filePath,
        line: refItem.line,
        oldUses: refItem.oldUses,
        newUses: `${refItem.actionTarget}@${latestVersion.raw}`,
        repoSlug: refItem.repoSlug,
        actionTarget: refItem.actionTarget,
        oldRef: refItem.currentRef,
        newRef: latestVersion.raw,
      });
    }
  }

  return updates;
}

/**
 * Applies targeted `uses:` updates in-place while preserving EOLs, formatting, and trailing comments.
 */
export async function updateGitHubActionFiles(
  ctx: Pick<CommandContext, "fs" | "cwd" | "dryRun">,
  updates: readonly GitHubActionUpdate[],
  projectDir = ctx.cwd,
): Promise<readonly string[]> {
  if (updates.length === 0) {
    return [];
  }

  const grouped = new Map<string, GitHubActionUpdate[]>();
  for (const item of updates) {
    const existing = grouped.get(item.filePath);
    if (existing !== undefined) {
      existing.push(item);
    } else {
      grouped.set(item.filePath, [item]);
    }
  }

  const results = await Promise.all(
    [...grouped.entries()].map(async ([relPath, fileUpdates]): Promise<string | undefined> => {
      const absPath = path.resolve(projectDir, relPath);
      const raw = await ctx.fs.readFile(absPath, "utf8");
      const eol = raw.includes("\r\n") ? "\r\n" : "\n";
      const lines = raw.split(/\r?\n/);
      let fileModified = false;

      for (const item of fileUpdates) {
        const lineIndex = item.line - 1;
        const lineText = lines[lineIndex];
        if (lineIndex < 0 || lineIndex >= lines.length || lineText === undefined) {
          throw new ExecutionError(
            `Line index ${item.line.toString()} out of range for '${relPath}'`,
            1,
          );
        }

        const escapedOld = escapeRegExp(item.oldUses);
        const usesPattern = new RegExp(
          `(?<=uses\\s*:\\s*['"]?)${escapedOld}(?=['"]?(?:\\s+#.*|\\s*$))`,
        );
        const fallbackPattern = new RegExp(
          `(?<=^\\s*['"]?)${escapedOld}(?=['"]?(?:\\s+#.*|\\s*$))`,
        );

        if (usesPattern.test(lineText)) {
          lines[lineIndex] = lineText.replace(usesPattern, () => item.newUses);
          fileModified = true;
        } else if (fallbackPattern.test(lineText)) {
          lines[lineIndex] = lineText.replace(fallbackPattern, () => item.newUses);
          fileModified = true;
        } else {
          throw new ExecutionError(
            `Failed to locate uses target '${item.oldUses}' at ${relPath}:${item.line.toString()}`,
            1,
          );
        }
      }

      if (fileModified && !ctx.dryRun) {
        await ctx.fs.writeFile(absPath, lines.join(eol), "utf8");
        return relPath;
      }
      return undefined;
    }),
  );

  return results.filter((entry): entry is string => entry !== undefined);
}
