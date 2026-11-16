import { describe, expect, it } from "vite-plus/test";
import { mmbCommand } from "../../cli/src/commands/mmb.ts";
import { MissingDependencyError, UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

describe("mmb command", () => {
  it("opens repoRoot in Visual Studio Code", async () => {
    const calls: { command: string; args: readonly string[] }[] = [];
    const { ctx } = createTestContext({
      repoRoot: "/tmp/example-repo",
      runner: {
        commandExists: async (name) => name === "code",
        spawnInteractive: async (command, args) => {
          calls.push({ command, args });
          return 0;
        },
      },
    });

    const code = await mmbCommand.execute([], ctx);
    expect(code).toBe(0);
    expect(calls).toEqual([{ command: "code", args: ["/tmp/example-repo"] }]);
  });

  it("prints help on --help", async () => {
    const { ctx, getStdout } = createTestContext();
    const code = await mmbCommand.execute(["--help"], ctx);
    expect(code).toBe(0);
    expect(getStdout()).toContain("mmb: Open current build workspace in Visual Studio Code");
  });

  it("rejects unexpected positional arguments and missing code binary", async () => {
    const { ctx } = createTestContext({
      runner: {
        commandExists: async () => false,
      },
    });
    await expect(mmbCommand.execute(["extra"], ctx)).rejects.toThrow(UsageError);
    await expect(mmbCommand.execute([], ctx)).rejects.toThrow(MissingDependencyError);
  });
});
