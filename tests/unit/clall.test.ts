import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vite-plus/test";
import {
  clallCommand,
  parseGitHubRepoList,
  resolveGitHubToken,
} from "../../cli/src/commands/clall.ts";
import { ExecutionError, UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

describe("clall command", () => {
  it("prints help and rejects unknown flags or extra positional arguments", async () => {
    const helpRun = createTestContext();
    await expect(clallCommand.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("clall:");

    await expect(clallCommand.execute(["--unknown-flag"], helpRun.ctx)).rejects.toThrow(UsageError);
    await expect(clallCommand.execute(["tok1", "extra"], helpRun.ctx)).rejects.toThrow(UsageError);
  });

  it("enforces token precedence and rejects missing tokens or unresolved op:// references", () => {
    expect(resolveGitHubToken(" pos_tok ", { GITHUB_TOKEN: "gh_tok", GH_TOKEN: "cli_tok" })).toBe(
      "pos_tok",
    );
    expect(resolveGitHubToken(undefined, { GITHUB_TOKEN: " gh_tok ", GH_TOKEN: "cli_tok" })).toBe(
      "gh_tok",
    );
    expect(resolveGitHubToken(undefined, { GH_TOKEN: " cli_tok " })).toBe("cli_tok");

    expect(() => resolveGitHubToken(undefined, {})).toThrow(UsageError);
    expect(() => resolveGitHubToken("op://Personal/GitHub/token", {})).toThrow(
      /1Password secret reference/,
    );
    expect(() => resolveGitHubToken(undefined, { GITHUB_TOKEN: "OP://Vault/Item/token" })).toThrow(
      /1Password secret reference/,
    );
  });

  it("parses GitHub repo lists across empty, null, single, and missing ssh_url payloads", () => {
    expect(parseGitHubRepoList([])).toEqual([]);
    expect(parseGitHubRepoList(null)).toEqual([]);
    expect(parseGitHubRepoList(undefined)).toEqual([]);

    expect(parseGitHubRepoList([{ name: "alpha", ssh_url: "git@github.com:u/alpha.git" }])).toEqual(
      [{ name: "alpha", sshUrl: "git@github.com:u/alpha.git" }],
    );

    expect(parseGitHubRepoList({ name: "single", ssh_url: "git@github.com:u/single.git" })).toEqual(
      [{ name: "single", sshUrl: "git@github.com:u/single.git" }],
    );

    expect(
      parseGitHubRepoList([
        { name: "alpha", ssh_url: "git@github.com:u/alpha.git" },
        { name: "no-ssh" },
        { name: "blank-ssh", ssh_url: "   " },
        { ssh_url: "git@github.com:u/beta.git" },
      ]),
    ).toEqual([
      { name: "alpha", sshUrl: "git@github.com:u/alpha.git" },
      { name: "beta", sshUrl: "git@github.com:u/beta.git" },
    ]);
  });

  it("paginates GitHub /user/repos and handles empty results and HTTP failures", async () => {
    const requestedUrls: string[] = [];
    const pageOne = Array.from({ length: 100 }, (_, idx) => ({
      name: `repo-${idx.toString()}`,
      ssh_url: `git@github.com:u/repo-${idx.toString()}.git`,
    }));

    const dryPagedRun = createTestContext({
      cwd: "/workspace",
      fetch: async (input) => {
        const url =
          typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
        requestedUrls.push(url);
        const parsedUrl = new URL(url);
        if (parsedUrl.searchParams.get("page") === "1") {
          return new Response(JSON.stringify(pageOne), { status: 200 });
        }
        return new Response(
          JSON.stringify([{ name: "repo-100", ssh_url: "git@github.com:u/repo-100.git" }]),
          { status: 200 },
        );
      },
    });

    await expect(clallCommand.execute(["--dry-run", "tok_test"], dryPagedRun.ctx)).resolves.toBe(0);
    expect(requestedUrls).toHaveLength(2);
    expect(requestedUrls[0]).toContain("page=1");
    expect(requestedUrls[1]).toContain("page=2");
    expect(dryPagedRun.getStdout()).toContain("repo-100");

    const emptyRun = createTestContext({
      fetch: async () => new Response("[]", { status: 200 }),
    });
    await expect(clallCommand.execute(["tok_test"], emptyRun.ctx)).resolves.toBe(0);
    expect(emptyRun.getStdout()).toBe("No repositories found.\n");

    const httpErrRun = createTestContext({
      fetch: async () => new Response("Unauthorized", { status: 401 }),
    });
    await expect(clallCommand.execute(["tok_test"], httpErrRun.ctx)).rejects.toThrow(
      ExecutionError,
    );
  });

  it("clones in bounded parallel batches, skips existing dirs, retries once, and reports git errors", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-clall-clone-"));
    try {
      await fs.mkdir(path.join(tempDir, "existing-repo"));

      const repos = [
        { name: "existing-repo", ssh_url: "git@github.com:u/existing-repo.git" },
        ...Array.from({ length: 8 }, (_, idx) => ({
          name: `repo-${idx.toString()}`,
          ssh_url: `git@github.com:u/repo-${idx.toString()}.git`,
        })),
        { name: "flaky-repo", ssh_url: "git@github.com:u/flaky-repo.git" },
        { name: "broken-repo", ssh_url: "git@github.com:u/broken-repo.git" },
      ];

      let activeClones = 0;
      let maxConcurrentClones = 0;
      const attemptCount = new Map<string, number>();

      const { ctx, getStdout, getStderr } = createTestContext({
        cwd: tempDir,
        fetch: async () => new Response(JSON.stringify(repos), { status: 200 }),
        runner: {
          commandExists: async () => true,
          exec: async (_command, args, options) => {
            expect(options?.env?.["GIT_TERMINAL_PROMPT"]).toBe("0");
            const destPath = args[args.length - 1] ?? "";
            const repoName = path.basename(destPath);
            const currentAttempts = (attemptCount.get(repoName) ?? 0) + 1;
            attemptCount.set(repoName, currentAttempts);

            activeClones += 1;
            maxConcurrentClones = Math.max(maxConcurrentClones, activeClones);
            await new Promise((resolve) => {
              setTimeout(resolve, 15);
            });
            activeClones -= 1;

            if (repoName === "flaky-repo" && currentAttempts === 1) {
              await fs.mkdir(destPath, { recursive: true });
              return { exitCode: 128, stdout: "", stderr: "transient reset" };
            }
            if (repoName === "broken-repo") {
              return {
                exitCode: 128,
                stdout: "",
                stderr: "fatal: remote error:\nRepository is disabled.",
              };
            }
            await fs.mkdir(destPath, { recursive: true });
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      const code = await clallCommand.execute(["tok_123"], ctx);
      expect(code).toBe(1);
      expect(maxConcurrentClones).toBeLessThanOrEqual(6);
      expect(attemptCount.get("flaky-repo")).toBe(2);
      expect(attemptCount.get("broken-repo")).toBe(2);
      expect(attemptCount.has("existing-repo")).toBe(false);

      const out = getStdout();
      expect(out).toContain("Skip [1/11] existing-repo (already exists)");
      expect(out).toContain("Clone [10/11] flaky-repo ok");
      expect(getStderr()).toContain("Clone broken-repo failed: fatal: remote error:");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
