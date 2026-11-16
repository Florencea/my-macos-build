import path from "node:path";

import { z } from "zod";

import { defineCommand } from "../lib/cli-framework.ts";
import {
  ExecutionError,
  UsageError,
  formatErrorMessage,
  formatNativeErrorDetail,
  parseEnvWithSchema,
  type CommandContext,
} from "../lib/context.ts";
import { pathExists } from "../lib/fs-utils.ts";
import { mapWithConcurrency } from "../lib/process.ts";

const ClallEnvSchema = z.object({
  GITHUB_TOKEN: z.string().optional(),
  GH_TOKEN: z.string().optional(),
});

const GitHubRepoItemSchema = z.object({
  name: z.string().optional(),
  ssh_url: z.string().optional(),
});

const GitHubResponseArraySchema = z.array(z.unknown());

const CLONE_CONCURRENCY_LIMIT = 6;
const CLONE_MAX_ATTEMPTS = 2;
const CLONE_RETRY_DELAY_MS = 500;
const GITHUB_PER_PAGE = 100;

export interface GitHubRepoEntry {
  readonly name: string;
  readonly sshUrl: string;
}

type CloneOutcome =
  | { readonly status: "skipped"; readonly name: string }
  | { readonly status: "cloned"; readonly name: string }
  | { readonly status: "failed"; readonly name: string; readonly detail: string };

/**
 * Resolves the GitHub access token with CLI positional > `GITHUB_TOKEN` > `GH_TOKEN` precedence
 * and rejects unresolved 1Password (`op://`) references.
 */
export function resolveGitHubToken(
  positionalToken: string | undefined,
  env: Readonly<Record<string, string | undefined>>,
): string {
  const parsedEnv = parseEnvWithSchema(env, ClallEnvSchema);
  const posCandidate = positionalToken?.trim() ?? "";
  const ghTokenCandidate = parsedEnv.GITHUB_TOKEN?.trim() ?? "";
  const ghCliTokenCandidate = parsedEnv.GH_TOKEN?.trim() ?? "";

  const token =
    posCandidate !== ""
      ? posCandidate
      : ghTokenCandidate !== ""
        ? ghTokenCandidate
        : ghCliTokenCandidate;

  if (token === "") {
    throw new UsageError(
      "Error: Missing GitHub access token. Pass [GITHUB_ACCESS_TOKEN] or set GITHUB_TOKEN / GH_TOKEN.",
      true,
    );
  }

  if (token.toLowerCase().startsWith("op://")) {
    throw new UsageError(
      "Error: Unresolved 1Password secret reference in token; run via 'op run'",
      false,
    );
  }

  return token;
}

/**
 * Extracts validated `{ name, sshUrl }` entries from a GitHub `/user/repos` JSON payload,
 * filtering out entries without a non-empty `ssh_url`.
 */
export function parseGitHubRepoList(rawResponse: unknown): readonly GitHubRepoEntry[] {
  if (rawResponse === null || rawResponse === undefined) {
    return [];
  }

  const rawItems: readonly unknown[] = Array.isArray(rawResponse) ? rawResponse : [rawResponse];
  const entries: GitHubRepoEntry[] = [];

  for (const item of rawItems) {
    const parsed = GitHubRepoItemSchema.safeParse(item);
    if (!parsed.success) {
      continue;
    }
    const sshUrl = parsed.data.ssh_url?.trim() ?? "";
    if (sshUrl === "") {
      continue;
    }
    const rawName = parsed.data.name?.trim() ?? "";
    const derivedName =
      rawName !== "" ? rawName : path.posix.basename(sshUrl, ".git") || path.posix.basename(sshUrl);
    if (derivedName === "") {
      continue;
    }
    entries.push({ name: derivedName, sshUrl });
  }

  return entries;
}

async function fetchAllOwnedRepos(
  ctx: CommandContext,
  token: string,
): Promise<readonly GitHubRepoEntry[]> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    Authorization: `Bearer ${token}`,
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "viteplus-clall",
  };

  const collected: GitHubRepoEntry[] = [];

  const fetchPage = async (page: number): Promise<void> => {
    const uri = `https://api.github.com/user/repos?type=owner&per_page=${GITHUB_PER_PAGE.toString()}&page=${page.toString()}`;
    const signal =
      ctx.signal !== undefined
        ? AbortSignal.any([ctx.signal, AbortSignal.timeout(20_000)])
        : AbortSignal.timeout(20_000);
    const response = await ctx.fetch(uri, { method: "GET", headers, signal });
    if (!response.ok) {
      throw new ExecutionError(
        `Error: Failed to fetch repositories from GitHub API (HTTP ${response.status.toString()})`,
        1,
      );
    }

    const rawJson: unknown = await response.json();
    const arrayValidation = GitHubResponseArraySchema.safeParse(rawJson);
    if (!arrayValidation.success) {
      throw new ExecutionError(
        "Error: Unexpected non-array response from GitHub API /user/repos",
        1,
      );
    }

    const pageItems = arrayValidation.data;
    if (pageItems.length === 0) {
      return;
    }

    collected.push(...parseGitHubRepoList(pageItems));
    if (pageItems.length < GITHUB_PER_PAGE) {
      return;
    }
    await fetchPage(page + 1);
  };

  try {
    await fetchPage(1);
  } catch (err) {
    if (err instanceof ExecutionError) {
      throw err;
    }
    const msg = formatErrorMessage(err);
    throw new ExecutionError(`Error: Failed to fetch repositories from GitHub API: ${msg}`, 1);
  }

  return collected;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function cloneSingleRepo(
  ctx: CommandContext,
  repo: GitHubRepoEntry,
  retryDelayMs: number,
): Promise<CloneOutcome> {
  const destPath = path.join(ctx.cwd, repo.name);
  if (await pathExists(destPath, ctx.fs)) {
    return { status: "skipped", name: repo.name };
  }

  const attemptClone = async (attempt: number): Promise<CloneOutcome> => {
    const cloneRes = await ctx.runner.exec("git", ["clone", "--quiet", repo.sshUrl, destPath], {
      env: { GIT_TERMINAL_PROMPT: "0" },
      signal: ctx.signal,
    });

    if (cloneRes.exitCode === 0) {
      return { status: "cloned", name: repo.name };
    }

    await ctx.fs.rm(destPath, { recursive: true, force: true }).catch(() => {});

    if (attempt < CLONE_MAX_ATTEMPTS) {
      await sleep(retryDelayMs);
      return await attemptClone(attempt + 1);
    }

    const detail = formatNativeErrorDetail([cloneRes.stderr, cloneRes.stdout], cloneRes.exitCode);
    return { status: "failed", name: repo.name, detail };
  };

  return await attemptClone(1);
}

/**
 * Clones all GitHub repositories owned by the authenticated user in bounded parallel batches.
 */
export const clallCommand = defineCommand({
  name: "clall",
  summary: "Clone all GitHub Repositories for the authenticated user",
  usage: "clall [options] [GITHUB_ACCESS_TOKEN]",
  examples: ["clall ghp_000000000000000000000000000000000000", "GITHUB_TOKEN=... clall"],
  flags: {},
  positionals: { min: 0, max: 1, label: "GITHUB_ACCESS_TOKEN" },
  requiredCommands: ["git"],
  supportsDryRun: true,
  async run({ positionals, ctx }) {
    const token = resolveGitHubToken(positionals[0], ctx.env);
    const repos = await fetchAllOwnedRepos(ctx, token);

    const total = repos.length;
    if (total === 0) {
      ctx.stdout("No repositories found.\n");
      return 0;
    }

    if (ctx.dryRun) {
      const checks = await Promise.all(
        repos.map(async (repo) => ({
          repo,
          exists: await pathExists(path.join(ctx.cwd, repo.name), ctx.fs),
        })),
      );
      for (const { repo, exists } of checks) {
        const destPath = path.join(ctx.cwd, repo.name);
        if (exists) {
          ctx.stdout(`[dry-run] Skip ${repo.name} (already exists)\n`);
        } else {
          ctx.stdout(`[dry-run] git clone --quiet ${repo.sshUrl} ${destPath}\n`);
        }
      }
      return 0;
    }

    const outcomes = await mapWithConcurrency(
      repos,
      CLONE_CONCURRENCY_LIMIT,
      async (repo) => await cloneSingleRepo(ctx, repo, CLONE_RETRY_DELAY_MS),
    );
    let done = 0;
    let failedCount = 0;

    for (const outcome of outcomes) {
      if (outcome.status === "skipped") {
        done += 1;
        ctx.stdout(
          `Skip [${done.toString()}/${total.toString()}] ${outcome.name} (already exists)\n`,
        );
      } else if (outcome.status === "cloned") {
        done += 1;
        ctx.stdout(`Clone [${done.toString()}/${total.toString()}] ${outcome.name} ok\n`);
      } else {
        failedCount += 1;
        ctx.stderr(`Clone ${outcome.name} failed: ${outcome.detail}\n`);
      }
    }

    return failedCount > 0 ? 1 : 0;
  },
});
