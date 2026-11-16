import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vite-plus/test";
import { uaCommand } from "../../cli/src/commands/ua.ts";
import { MissingDependencyError, UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

describe("ua command", () => {
  it("prints help and rejects unknown options or positional arguments", async () => {
    const helpRun = createTestContext();
    await expect(uaCommand.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("ua:");
    expect(helpRun.getStdout()).toContain("--skip-brew");
    expect(helpRun.getStdout()).toContain("--skip-winget");
    expect(helpRun.getStdout()).toContain("--skip-vite");
    expect(helpRun.getStdout()).toContain("--skip-git");

    await expect(uaCommand.execute(["--unknown"], helpRun.ctx)).rejects.toThrow(UsageError);
    await expect(uaCommand.execute(["extra"], helpRun.ctx)).rejects.toThrow(UsageError);
  });

  it("supports --dry-run across OS packages, Vite+ toolchain, and workspace git repos", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-ua-dry-"));
    try {
      const repoRoot = path.join(tempDir, "my-machine-build");
      await fs.mkdir(path.join(repoRoot, ".git"), { recursive: true });

      const darwinDry = createTestContext({
        platform: "darwin",
        repoRoot,
        runner: { commandExists: async () => true },
      });
      await expect(uaCommand.execute(["--dry-run"], darwinDry.ctx)).resolves.toBe(0);
      expect(darwinDry.getStdout()).toContain("[dry-run] brew upgrade && brew cleanup");
      expect(darwinDry.getStdout()).toContain("[dry-run] vp upgrade");
      expect(darwinDry.getStdout()).toContain("[dry-run] git pull --all across 1 repository(s)");

      const winDry = createTestContext({
        platform: "win32",
        repoRoot,
        env: { PATH: "C:\\Tools" },
        runner: { commandExists: async () => true },
      });
      await expect(uaCommand.execute(["--dry-run"], winDry.ctx)).resolves.toBe(0);
      expect(winDry.getStdout()).toContain("[dry-run] winget upgrade --all");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("fails on missing brew on darwin unless --skip-brew is passed, and runs Vite+ upgrade cleanup", async () => {
    const missingBrew = createTestContext({
      platform: "darwin",
      runner: { commandExists: async (cmd) => cmd !== "brew" },
    });
    await expect(uaCommand.execute([], missingBrew.ctx)).rejects.toThrow(MissingDependencyError);

    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-ua-vite-"));
    try {
      const legacyNodeDir = path.join(tempDir, ".local", "opt", "node-v22");
      await fs.mkdir(legacyNodeDir, { recursive: true });
      const vpHome = path.join(tempDir, ".local", "share", "vite-plus");
      await fs.mkdir(path.join(vpHome, "current", "node_modules", "vite-plus"), {
        recursive: true,
      });
      await fs.mkdir(path.join(vpHome, "bin"), { recursive: true });
      await fs.writeFile(
        path.join(vpHome, "current", "node_modules", "vite-plus", "package.json"),
        '{"name":"vite-plus","dependencies":{"oxfmt":"1.2.3"}}',
      );
      await fs.writeFile(path.join(vpHome, "bin", "oxfmt"), "");

      let nodeChecks = 0;
      const execCalls: string[] = [];
      const { ctx, getStdout } = createTestContext({
        platform: "darwin",
        env: { HOME: tempDir, VP_HOME: vpHome },
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            execCalls.push(`${cmd} ${args.join(" ")}`);
            if (cmd === "vp" && args[0] === "node" && args[1] === "-v") {
              nodeChecks += 1;
              return {
                exitCode: 0,
                stdout: nodeChecks === 1 ? "v26.12.0\n" : "v26.13.1\n",
                stderr: "",
              };
            }
            if (cmd === "vp" && args[0] === "env" && args[1] === "list-remote") {
              return {
                exitCode: 0,
                stdout: JSON.stringify({
                  package_managers: {
                    pnpm: [{ version: "12.21.0", latest: true, installed: false }],
                  },
                }),
                stderr: "",
              };
            }
            if (cmd === "vp" && args[0] === "--version") {
              return { exitCode: 0, stdout: "vp v1.6.0\n", stderr: "" };
            }
            if (cmd.endsWith("oxfmt") && args[0] === "--version") {
              return { exitCode: 0, stdout: "oxfmt 1.2.3\n", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(uaCommand.execute(["--skip-brew", "--skip-git"], ctx)).resolves.toBe(0);
      expect(getStdout()).toContain("node: v26.13.1");
      expect(getStdout()).toContain("pnpm: v12.21.0");
      expect(execCalls).toContain("vp env clean");
      await expect(fs.stat(legacyNodeDir)).rejects.toThrow(/ENOENT/);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("pulls git repositories in bounded parallel and reports outdated pnpm lockfile hints", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-ua-git-"));
    try {
      const okRepo = path.join(tempDir, "a-ok");
      const updatedRepo = path.join(tempDir, "b-updated");
      const failedRepo = path.join(tempDir, "c-broken");

      await Promise.all(
        [okRepo, updatedRepo, failedRepo].map((dir) =>
          fs.mkdir(path.join(dir, ".git"), { recursive: true }),
        ),
      );
      await fs.writeFile(path.join(updatedRepo, "package.json"), "{}");
      await fs.writeFile(path.join(updatedRepo, "pnpm-lock.yaml"), "");

      const { ctx, getStdout, getStderr } = createTestContext({
        repoRoot: okRepo,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            if (cmd === "git" && args.includes("pull")) {
              if (args[1] === updatedRepo) {
                return { exitCode: 0, stdout: "Fast-forward\n", stderr: "" };
              }
              if (args[1] === failedRepo) {
                return { exitCode: 1, stdout: "", stderr: "fatal: could not read from remote" };
              }
              return { exitCode: 0, stdout: "Already up to date.\n", stderr: "" };
            }
            if (cmd === "vp" && args[1] === updatedRepo && args.includes("install")) {
              return {
                exitCode: 1,
                stdout: "",
                stderr: "ERR_PNPM_OUTDATED_LOCKFILE: Cannot install with frozen-lockfile",
              };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      const code = await uaCommand.execute(["--skip-brew", "--skip-vite"], ctx);
      expect(code).toBe(1);
      expect(getStdout()).toContain("Sync b-updated updated");
      expect(getStderr()).toContain("Sync c-broken failed: fatal: could not read from remote");
      expect(getStderr()).toContain("Sync b-updated dependencies failed:");
      expect(getStderr()).toContain("Hint: Run 'up' in b-updated or 'upnpmv'");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
