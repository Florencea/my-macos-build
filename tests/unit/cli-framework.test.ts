import process from "node:process";
import { describe, expect, it } from "vite-plus/test";
import { z } from "zod";
import {
  defineCommand,
  handleCliError,
  parseValidatedInt,
} from "../../cli/src/lib/cli-framework.ts";
import {
  MissingDependencyError,
  UsageError,
  formatByteSize,
  formatNativeErrorDetail,
  parseEnvWithSchema,
} from "../../cli/src/lib/context.ts";
import { createNodeCommandRunner } from "../../cli/src/lib/process.ts";
import { withSpinner } from "../../cli/src/lib/spinner.ts";
import { createTestContext } from "./test-helpers.ts";

describe("cli-framework and core utilities", () => {
  it("formats byte sizes consistently", () => {
    expect(formatByteSize(1024)).toBe("1K");
    expect(formatByteSize(1572864)).toBe("1.5M");
    expect(formatByteSize(2147483648)).toBe("2.0G");
  });

  it("formats native error details and falls back to exit code", () => {
    expect(
      formatNativeErrorDetail(
        ["fatal: remote error: ", "", "  Repository is disabled.", null],
        128,
      ),
    ).toBe("fatal: remote error: | Repository is disabled.");
    expect(formatNativeErrorDetail(["", "   "], 128)).toBe("exit code 128");
  });

  it("validates integer options with range bounds", () => {
    expect(parseValidatedInt("50", "--quality", 0, 100)).toBe(50);
    expect(() => parseValidatedInt("abc", "--quality", 0, 100)).toThrow(UsageError);
    expect(() => parseValidatedInt("101", "--quality", 0, 100)).toThrow(UsageError);
  });

  it("validates environment variables through parseEnvWithSchema", () => {
    const EnvSchema = z.object({
      YT_DLP_BROWSER: z.string().trim().min(1).default("chrome"),
    });
    expect(parseEnvWithSchema({}, EnvSchema).YT_DLP_BROWSER).toBe("chrome");
    expect(parseEnvWithSchema({ YT_DLP_BROWSER: " firefox " }, EnvSchema).YT_DLP_BROWSER).toBe(
      "firefox",
    );
    expect(() => parseEnvWithSchema({ YT_DLP_BROWSER: "   " }, EnvSchema)).toThrow(UsageError);
  });

  it("checks command availability via real node runner", async () => {
    const runner = createNodeCommandRunner();
    await expect(runner.commandExists("vpx")).resolves.toBe(true);
    await expect(runner.commandExists("nonexistent-cmd-xyz-999")).resolves.toBe(false);
  });

  it("handles --help, --dry-run, unknown options, and positional bounds", async () => {
    const sample = defineCommand({
      name: "demo",
      summary: "Demo command",
      usage: "demo [options] <target>",
      flags: {
        verbose: { type: "boolean", short: "v", description: "Verbose output" },
      },
      optionsSchema: z.object({ verbose: z.boolean().optional() }),
      positionals: { min: 1, max: 1, label: "target" },
      supportsDryRun: true,
      async run({ options, positionals, ctx }) {
        ctx.stdout(
          `target=${positionals[0] ?? ""},dry=${String(ctx.dryRun)},v=${String(Boolean(options.verbose))}`,
        );
        return 0;
      },
    });

    const helpRun = createTestContext();
    await expect(sample.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("demo: Demo command");
    expect(helpRun.getStdout()).toContain("--dry-run");

    const okRun = createTestContext();
    await expect(sample.execute(["--dry-run", "-v", "src"], okRun.ctx)).resolves.toBe(0);
    expect(okRun.getStdout()).toBe("target=src,dry=true,v=true");

    const badFlagRun = createTestContext();
    await expect(sample.execute(["--unknown-flag-test"], badFlagRun.ctx)).rejects.toThrow(
      UsageError,
    );

    const missingPosRun = createTestContext();
    await expect(sample.execute([], missingPosRun.ctx)).rejects.toThrow(UsageError);

    const extraPosRun = createTestContext();
    await expect(sample.execute(["one", "two"], extraPosRun.ctx)).rejects.toThrow(UsageError);
  });

  it("fails with MissingDependencyError when required command is unavailable", async () => {
    const cmd = defineCommand({
      name: "needs-tool",
      summary: "Needs tool",
      usage: "needs-tool",
      flags: {},
      optionsSchema: z.object({}),
      requiredCommands: ["missing-tool"],
      async run() {
        return 0;
      },
    });

    const { ctx } = createTestContext({
      runner: {
        commandExists: async () => false,
      },
    });

    await expect(cmd.execute([], ctx)).rejects.toThrow(MissingDependencyError);
  });

  it("formats errors cleanly through handleCliError", () => {
    let errText = "";
    const code = handleCliError(
      new UsageError("Error: Unknown option --bad", true),
      "demo: help\n",
      (t) => {
        errText += t;
      },
    );
    expect(code).toBe(2);
    expect(errText).toContain("Unknown option --bad");
    expect(errText).toContain("demo: help");
  });

  it("restores TTY cursor in withSpinner even when task fails", async () => {
    let stderrText = "";
    let registeredCleanup: (() => void) | undefined;

    await expect(
      withSpinner(
        {
          isTty: true,
          stderr: (t) => {
            stderrText += t;
          },
          onSignalCleanup: (handler) => {
            registeredCleanup = handler;
            return () => {
              registeredCleanup = undefined;
            };
          },
        },
        "Working",
        async () => {
          throw new Error("boom");
        },
      ),
    ).rejects.toThrow("boom");

    expect(stderrText).toContain("\x1b[?25l");
    expect(stderrText).toContain("\x1b[?25h");
    expect(registeredCleanup).toBeUndefined();
  });

  it("executes and pipes real child processes via node runner", async () => {
    const runner = createNodeCommandRunner();
    const piped = await runner.pipe(
      { command: process.execPath, args: ["-e", "process.stdout.write('hello world')"] },
      {
        command: process.execPath,
        args: [
          "-e",
          "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>process.stdout.write(d.toUpperCase()))",
        ],
      },
    );
    expect(piped.leftExitCode).toBe(0);
    expect(piped.rightExitCode).toBe(0);
    expect(piped.stdout).toBe("HELLO WORLD");
  });
});
