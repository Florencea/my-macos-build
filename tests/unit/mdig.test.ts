import { describe, expect, it } from "vite-plus/test";
import { MDIG_DNS_SERVERS, mdigCommand } from "../../cli/src/commands/mdig.ts";
import { UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

describe("mdig command", () => {
  it("prints help on --help and validates required positional domain", async () => {
    const helpRun = createTestContext();
    await expect(mdigCommand.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("mdig:");

    const missingRun = createTestContext();
    await expect(mdigCommand.execute([], missingRun.ctx)).rejects.toThrow(UsageError);

    const badOptRun = createTestContext();
    await expect(mdigCommand.execute(["--unknown-flag-test"], badOptRun.ctx)).rejects.toThrow(
      UsageError,
    );

    const badDomainRun = createTestContext();
    await expect(mdigCommand.execute(["bad domain"], badDomainRun.ctx)).rejects.toThrow(UsageError);
  });

  it("queries all 5 DNS servers in parallel for A and AAAA and groups matching answers", async () => {
    const queries: Array<{ domain: string; recordType: "A" | "AAAA"; serverIp?: string }> = [];
    let tick = 0;

    const { ctx, getStdout } = createTestContext({
      now: () => {
        tick += 5;
        return new Date(1_700_000_000_000 + tick);
      },
      dns: {
        async resolve(input) {
          queries.push({
            domain: input.domain,
            recordType: input.recordType,
            serverIp: input.serverIp,
          });
          if (input.recordType === "A") {
            if (input.serverIp === "168.95.1.1") {
              return ["2.2.2.2", "1.1.1.1"];
            }
            return ["93.184.215.14"];
          }
          if (input.serverIp === "8.8.8.8" || input.serverIp === "2001:4860:4860::8888") {
            const timeoutErr = Object.assign(new Error("queryAaaa ETIMEOUT"), { code: "ETIMEOUT" });
            throw timeoutErr;
          }
          if (input.serverIp === undefined) {
            const noDataErr = Object.assign(new Error("queryAaaa ENODATA"), { code: "ENODATA" });
            throw noDataErr;
          }
          return ["2606:2800:220:1:248:1893:25c8:1946"];
        },
      },
    });

    const code = await mdigCommand.execute(["example.com"], ctx);
    expect(code).toBe(0);
    expect(queries).toHaveLength(MDIG_DNS_SERVERS.length * 2);

    const output = getStdout();
    expect(output).toContain("── A Records ──");
    expect(output).toContain("93.184.215.14");
    expect(output).toContain("  - Google (8.8.8.8) [");
    expect(output).toContain("  - Cloudflare (1.1.1.1) [");
    expect(output).toContain("  - Hinet (168.95.192.1) [");
    expect(output).toContain("  - System [");
    expect(output).toContain("1.1.1.1\n2.2.2.2\n  - Hinet (168.95.1.1)");

    expect(output).toContain("── AAAA Records ──");
    expect(output).toContain("[AAAA timeout]\n  - Google (2001:4860:4860::8888)\n");
    expect(output).toContain("2606:2800:220:1:248:1893:25c8:1946");
    expect(output).toContain("[no AAAA record]\n  - System [");
  });
});
