import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vite-plus/test";
import { ExecutionError } from "../../cli/src/lib/context.ts";
import {
  compareGitHubActionVersion,
  findGitHubActionFiles,
  getGitHubActionReferences,
  getGitHubActionUpdates,
  parseGitHubActionVersion,
  resolveGitHubActionLatestVersions,
  restoreGitHubWorkflow,
  updateGitHubActionFiles,
  type GitHubActionReference,
  type GitHubActionVersion,
} from "../../cli/src/lib/github-actions.ts";
import { createTestContext } from "./test-helpers.ts";

describe("github-actions utilities", () => {
  it("parses valid action version refs and rejects bare integers or SHAs", () => {
    const v4 = parseGitHubActionVersion("v4");
    const v42 = parseGitHubActionVersion("v4.2");
    const v421 = parseGitHubActionVersion("v4.2.1");
    const noPrefixMinor = parseGitHubActionVersion("4.2");

    expect(v4).toEqual({ raw: "v4", major: 4, minor: 0, patch: 0, precision: 1 });
    expect(v42).toEqual({ raw: "v4.2", major: 4, minor: 2, patch: 0, precision: 2 });
    expect(v421).toEqual({ raw: "v4.2.1", major: 4, minor: 2, patch: 1, precision: 3 });
    expect(noPrefixMinor).toEqual({ raw: "4.2", major: 4, minor: 2, patch: 0, precision: 2 });

    expect(parseGitHubActionVersion("4")).toBeNull();
    expect(parseGitHubActionVersion("a81bbbf8298c0fa03ea29cdc473d45769f953675")).toBeNull();
    expect(parseGitHubActionVersion("main")).toBeNull();
  });

  it("compares action versions across major, minor, patch, and precision", () => {
    const v4 = parseGitHubActionVersion("v4");
    const v42 = parseGitHubActionVersion("v4.2");
    const v421 = parseGitHubActionVersion("v4.2.1");
    const v5 = parseGitHubActionVersion("v5");

    expect(v4).not.toBeNull();
    expect(v42).not.toBeNull();
    expect(v421).not.toBeNull();
    expect(v5).not.toBeNull();

    if (v4 === null || v42 === null || v421 === null || v5 === null) {
      throw new Error("Unexpected null version");
    }

    expect(compareGitHubActionVersion(v421, v42)).toBe(1);
    expect(compareGitHubActionVersion(v4, v42)).toBe(-1);
    expect(compareGitHubActionVersion(v42, v42)).toBe(0);
    expect(compareGitHubActionVersion(v5, v421)).toBe(1);
  });

  it("computes same-major updates and ignores cross-major tags", () => {
    const v4 = parseGitHubActionVersion("v4");
    const v421 = parseGitHubActionVersion("v4.2.1");
    const v500 = parseGitHubActionVersion("v5.0.0");
    if (v4 === null || v421 === null || v500 === null) {
      throw new Error("Unexpected null version");
    }

    const refs: readonly GitHubActionReference[] = [
      {
        filePath: ".github/workflows/ci.yml",
        line: 12,
        oldUses: "actions/checkout@v4",
        repoSlug: "actions/checkout",
        actionTarget: "actions/checkout",
        currentRef: "v4",
        currentVersion: v4,
      },
    ];

    const latestByRepo = new Map<string, ReadonlyMap<number, GitHubActionVersion>>([
      [
        "actions/checkout",
        new Map<number, GitHubActionVersion>([
          [4, v421],
          [5, v500],
        ]),
      ],
    ]);

    const updates = getGitHubActionUpdates(refs, latestByRepo);
    expect(updates).toEqual([
      {
        filePath: ".github/workflows/ci.yml",
        line: 12,
        oldUses: "actions/checkout@v4",
        newUses: "actions/checkout@v4.2.1",
        repoSlug: "actions/checkout",
        actionTarget: "actions/checkout",
        oldRef: "v4",
        newRef: "v4.2.1",
      },
    ]);
  });

  it("updates targeted lines preserving CRLF and inline comments, and throws on out-of-range lines", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-gha-update-"));
    try {
      const wfPath = path.join(tempDir, "ci.yml");
      const initialContent =
        "jobs:\r\n  test:\r\n    steps:\r\n      - uses: actions/checkout@v4 # keep comment\r\n";
      await fs.writeFile(wfPath, initialContent, "utf8");

      const { ctx } = createTestContext({ cwd: tempDir });
      const changed = await updateGitHubActionFiles(
        ctx,
        [
          {
            filePath: wfPath,
            line: 4,
            oldUses: "actions/checkout@v4",
            newUses: "actions/checkout@v4.2.1",
            repoSlug: "actions/checkout",
            actionTarget: "actions/checkout",
            oldRef: "v4",
            newRef: "v4.2.1",
          },
        ],
        tempDir,
      );

      expect(changed).toEqual([wfPath]);
      const updatedText = await fs.readFile(wfPath, "utf8");
      expect(updatedText).toBe(
        "jobs:\r\n  test:\r\n    steps:\r\n      - uses: actions/checkout@v4.2.1 # keep comment\r\n",
      );

      await expect(
        updateGitHubActionFiles(
          ctx,
          [
            {
              filePath: wfPath,
              line: 99,
              oldUses: "actions/checkout@v4.2.1",
              newUses: "actions/checkout@v4.3.0",
              repoSlug: "actions/checkout",
              actionTarget: "actions/checkout",
              oldRef: "v4.2.1",
              newRef: "v4.3.0",
            },
          ],
          tempDir,
        ),
      ).rejects.toThrow(ExecutionError);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("discovers workflow and composite action files under .github", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-gha-find-"));
    try {
      await fs.mkdir(path.join(tempDir, ".github", "workflows"), { recursive: true });
      await fs.mkdir(path.join(tempDir, ".github", "actions", "setup"), { recursive: true });
      await fs.writeFile(path.join(tempDir, ".github", "workflows", "ci.yml"), "");
      await fs.writeFile(path.join(tempDir, ".github", "actions", "setup", "action.yaml"), "");
      await fs.writeFile(path.join(tempDir, ".github", "dependabot.yml"), "");

      const { ctx } = createTestContext({ cwd: tempDir });
      const files = await findGitHubActionFiles(ctx, tempDir);
      expect(files).toEqual([".github/actions/setup/action.yaml", ".github/workflows/ci.yml"]);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("parses yq references and resolves latest tags per major via git ls-remote", async () => {
    const { ctx } = createTestContext({
      cwd: "/repo",
      runner: {
        exec: async (cmd, args) => {
          if (cmd === "yq") {
            return {
              exitCode: 0,
              stdout: JSON.stringify([
                { uses: "actions/checkout@v4", line: 10 },
                { uses: "github/codeql-action/init@v3.1.0", line: 15 },
                { uses: "./local-action", line: 18 },
                { uses: "docker://alpine:latest", line: 20 },
                { uses: "actions/setup-node@a81bbbf8298c0fa03ea29cdc473d45769f953675", line: 22 },
              ]),
              stderr: "",
            };
          }
          if (cmd === "git" && args.includes("ls-remote")) {
            const url = args[args.length - 1] ?? "";
            if (url.includes("actions/checkout")) {
              return {
                exitCode: 0,
                stdout: "sha1\trefs/tags/v4\nsha2\trefs/tags/v4.2.2\nsha3\trefs/tags/v5.0.0\n",
                stderr: "",
              };
            }
            return { exitCode: 128, stdout: "", stderr: "fatal: repository not found" };
          }
          return { exitCode: 0, stdout: "", stderr: "" };
        },
      },
    });

    const refs = await getGitHubActionReferences(ctx, [".github/workflows/ci.yml"], "/repo");
    expect(refs).toHaveLength(2);
    expect(refs[0]?.repoSlug).toBe("actions/checkout");
    expect(refs[1]?.actionTarget).toBe("github/codeql-action/init");
    expect(refs[1]?.repoSlug).toBe("github/codeql-action");

    const resolved = await resolveGitHubActionLatestVersions(
      ctx,
      refs.map((r) => r.repoSlug),
    );
    const checkoutRes = resolved.get("actions/checkout");
    expect(checkoutRes?.success).toBe(true);
    expect(checkoutRes?.latestByMajor.get(4)?.raw).toBe("v4.2.2");
    expect(checkoutRes?.latestByMajor.get(5)?.raw).toBe("v5.0.0");

    const codeqlRes = resolved.get("github/codeql-action");
    expect(codeqlRes?.success).toBe(false);
    expect(codeqlRes?.error).toContain("repository not found");
  });

  it("restores modified workflow files via git checkout", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-gha-restore-"));
    try {
      await fs.mkdir(path.join(tempDir, ".github"), { recursive: true });
      await fs.mkdir(path.join(tempDir, "actions"), { recursive: true });
      const gitCalls: Array<readonly string[]> = [];

      const { ctx } = createTestContext({
        cwd: tempDir,
        runner: {
          exec: async (_cmd, args) => {
            gitCalls.push(args);
            if (args.includes("diff")) {
              return {
                exitCode: 0,
                stdout: ".github/workflows/ci.yml\nactions/deploy/action.yml\n.github/README.md\n",
                stderr: "",
              };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await restoreGitHubWorkflow(ctx, { includeActionsDir: true, cwd: tempDir });
      const checkoutCall = gitCalls.find((args) => args[0] === "checkout");
      expect(checkoutCall).toEqual([
        "checkout",
        "-q",
        "--",
        ".github/workflows/ci.yml",
        "actions/deploy/action.yml",
      ]);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
