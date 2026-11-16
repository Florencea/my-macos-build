import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vite-plus/test";
import { unodevCommand } from "../../cli/src/commands/unodev.ts";
import { MissingDependencyError, UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

describe("unodev command", () => {
  it("prints help and rejects unknown flags, positional args, and missing dependencies", async () => {
    const helpRun = createTestContext();
    await expect(unodevCommand.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("unodev:");
    expect(helpRun.getStdout()).toContain("--dry-run");

    await expect(unodevCommand.execute(["--unknown"], helpRun.ctx)).rejects.toThrow(UsageError);
    await expect(unodevCommand.execute(["extra"], helpRun.ctx)).rejects.toThrow(UsageError);

    const missingRun = createTestContext({
      runner: {
        commandExists: async (name) => name !== "vp",
      },
    });
    await expect(unodevCommand.execute([], missingRun.ctx)).rejects.toThrow(MissingDependencyError);
  });

  it("supports --dry-run without modifying package.json or committing", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-unodev-dry-"));
    try {
      const repoRoot = path.join(tempDir, "my-machine-build");
      const appDir = path.join(tempDir, "app-a");
      await fs.mkdir(path.join(repoRoot, ".git"), { recursive: true });
      await fs.mkdir(path.join(appDir, ".git"), { recursive: true });
      await fs.writeFile(path.join(repoRoot, "package.json"), "{}");
      await fs.writeFile(path.join(appDir, "package.json"), "{}");

      const execCalls: string[] = [];
      const { ctx, getStdout } = createTestContext({
        repoRoot,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            execCalls.push(`${cmd} ${args.join(" ")}`);
            if (cmd === "vp" && args[0] === "node") {
              return { exitCode: 0, stdout: "v26.13.1\n", stderr: "" };
            }
            if (cmd === "vp" && args.includes("get")) {
              return {
                exitCode: 0,
                stdout: args[1] === repoRoot ? '"26.13.1"\n' : '"26.12.0"\n',
                stderr: "",
              };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(unodevCommand.execute(["--dry-run"], ctx)).resolves.toBe(0);
      expect(getStdout()).toContain("engines.node my-machine-build: 26.13.1 ok");
      expect(getStdout()).toContain("[dry-run] engines.node app-a: 26.12.0 -> 26.13.1");
      expect(execCalls.some((c) => c.includes("pm pkg set") || c.includes("commit"))).toBe(false);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("updates, formats, commits, and pushes projects while rolling back on format failure or dirty tree", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-unodev-exec-"));
    try {
      const repoRoot = path.join(tempDir, "repo-ok");
      const dirtyRepo = path.join(tempDir, "repo-dirty");
      const badFmtRepo = path.join(tempDir, "repo-badfmt");

      await Promise.all(
        [repoRoot, dirtyRepo, badFmtRepo].map(async (dir) => {
          await fs.mkdir(path.join(dir, ".git"), { recursive: true });
          await fs.writeFile(path.join(dir, "package.json"), '{"name":"test"}\n');
        }),
      );

      const calls: string[] = [];
      const { ctx, getStdout, getStderr } = createTestContext({
        repoRoot,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            calls.push(`${cmd} ${args.join(" ")}`);
            if (cmd === "vp" && args[0] === "node") {
              return { exitCode: 1, stdout: "", stderr: "" };
            }
            if (cmd === "node" && args[0] === "-v") {
              return { exitCode: 0, stdout: "v26.13.1\n", stderr: "" };
            }
            if (cmd === "vp" && args.includes("get")) {
              return { exitCode: 0, stdout: '"26.11.0"\n', stderr: "" };
            }
            if (cmd === "git" && args.includes("--porcelain")) {
              if (args[1] === dirtyRepo) {
                return { exitCode: 0, stdout: " M package.json\n", stderr: "" };
              }
              return { exitCode: 0, stdout: "", stderr: "" };
            }
            if (cmd === "vp" && args.includes("fmt")) {
              if (args[1] === badFmtRepo) {
                return { exitCode: 1, stdout: "", stderr: "oxfmt error" };
              }
              return { exitCode: 0, stdout: "", stderr: "" };
            }
            if (cmd === "git" && args.includes("--short")) {
              return { exitCode: 0, stdout: "M  package.json\n", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      const code = await unodevCommand.execute([], ctx);
      expect(code).toBe(1);
      expect(getStdout()).toContain("engines.node repo-ok: 26.11.0 -> 26.13.1 ok");
      expect(getStderr()).toContain("repo-dirty: working tree has uncommitted changes");
      expect(getStderr()).toContain("repo-badfmt: failed to format package.json (oxfmt error)");
      expect(calls.some((c) => c.includes(`-C ${badFmtRepo} checkout -q -- package.json`))).toBe(
        true,
      );
      expect(calls.some((c) => c.includes(`-C ${repoRoot} push -q`))).toBe(true);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
