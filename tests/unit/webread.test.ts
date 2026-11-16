import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { describe, expect, it } from "vite-plus/test";

import {
  normalizeTargetUrl,
  resolveGitHubRawUrl,
  webreadCommand,
} from "../../cli/src/commands/webread.ts";
import { ExecutionError, UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

function extractFetchUrl(input: RequestInfo | URL): string {
  if (typeof input === "string") {
    return input;
  }
  return input instanceof URL ? input.href : input.url;
}

describe("webread command", () => {
  it("prints help on --help and rejects non-integer --max-chars", async () => {
    const helpRun = createTestContext();
    await expect(webreadCommand.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("webread:");
    expect(helpRun.getStdout()).toContain("--llms");

    const badMaxRun = createTestContext();
    await expect(
      webreadCommand.execute(["--max-chars", "abc", "https://example.com"], badMaxRun.ctx),
    ).rejects.toThrow(/Invalid integer for --max-chars/);

    const zeroMaxRun = createTestContext();
    await expect(
      webreadCommand.execute(["--max-chars", "0", "https://example.com"], zeroMaxRun.ctx),
    ).rejects.toThrow(UsageError);
  });

  it("normalizes bare hostnames and rejects invalid URLs", () => {
    expect(normalizeTargetUrl("example.com/docs")).toBe("https://example.com/docs");
    expect(normalizeTargetUrl("http://example.com")).toBe("http://example.com");
    expect(() => normalizeTargetUrl("not a valid url")).toThrow(UsageError);
  });

  it("rewrites GitHub blob URLs unless --raw is enabled", () => {
    expect(
      resolveGitHubRawUrl("https://github.com/org/repo/blob/main/README.md?plain=1#top", false),
    ).toBe("https://raw.githubusercontent.com/org/repo/main/README.md");
    expect(resolveGitHubRawUrl("https://github.com/org/repo/blob/main/README.md", true)).toBeNull();
    expect(resolveGitHubRawUrl("https://example.com/docs", false)).toBeNull();
  });

  it("probes /llms-full.txt and /llms.txt in --llms mode with local fallback", async () => {
    const requestedUrls: string[] = [];
    const { ctx, getStdout } = createTestContext({
      fetch: async (input) => {
        const url = extractFetchUrl(input);
        requestedUrls.push(url);
        if (url === "https://docs.example.com/llms-full.txt") {
          return new Response("", { status: 404 });
        }
        if (url === "https://docs.example.com/llms.txt") {
          return new Response("# Docs Index\n\n- Guide\n", {
            status: 200,
            headers: { "content-type": "text/plain; charset=utf-8" },
          });
        }
        return new Response("unexpected", { status: 500 });
      },
    });

    const code = await webreadCommand.execute(
      ["--llms", "--no-enclosure", "https://docs.example.com/guide"],
      ctx,
    );
    expect(code).toBe(0);
    expect(requestedUrls).toEqual([
      "https://docs.example.com/llms-full.txt",
      "https://docs.example.com/llms.txt",
    ]);
    expect(getStdout()).toBe("# Docs Index\n\n- Guide\n\n");

    const fallbackUrls: string[] = [];
    const fallbackRun = createTestContext({
      fetch: async (input) => {
        const url = extractFetchUrl(input);
        fallbackUrls.push(url);
        if (url.endsWith("/llms-full.txt") || url.endsWith("/llms.txt")) {
          return new Response("Not found", { status: 404 });
        }
        return new Response("<html><body><main><h1>Local Fallback</h1></main></body></html>", {
          status: 200,
          headers: { "content-type": "text/html" },
        });
      },
    });

    await expect(
      webreadCommand.execute(
        ["--llms", "--no-enclosure", "https://example.com/page"],
        fallbackRun.ctx,
      ),
    ).resolves.toBe(0);
    expect(fallbackUrls).toEqual([
      "https://example.com/llms-full.txt",
      "https://example.com/llms.txt",
      "https://example.com/page",
    ]);
    expect(fallbackRun.getStderr()).toContain("Neither /llms-full.txt nor /llms.txt found");
    expect(fallbackRun.getStdout()).toContain("Local Fallback");
  });

  it("supports --jina/--external with fallback and GitHub blob rewrite", async () => {
    const jinaRun = createTestContext({
      fetch: async (input) => {
        const url = extractFetchUrl(input);
        if (url.startsWith("https://r.jina.ai/")) {
          return new Response("# Jina Extracted", {
            status: 200,
            headers: { "content-type": "text/markdown" },
          });
        }
        return new Response("unused", { status: 500 });
      },
    });
    await expect(
      webreadCommand.execute(["--jina", "--no-enclosure", "https://spa.example.com"], jinaRun.ctx),
    ).resolves.toBe(0);
    expect(jinaRun.getStderr()).toContain("Using external Jina Reader service");
    expect(jinaRun.getStdout()).toContain("# Jina Extracted");

    const githubUrls: string[] = [];
    const ghRun = createTestContext({
      fetch: async (input) => {
        const url = extractFetchUrl(input);
        githubUrls.push(url);
        return new Response("# Repo Readme\n", {
          status: 200,
          headers: { "content-type": "text/plain" },
        });
      },
    });
    await expect(
      webreadCommand.execute(
        ["--no-enclosure", "https://github.com/acme/demo/blob/main/README.md"],
        ghRun.ctx,
      ),
    ).resolves.toBe(0);
    expect(githubUrls).toEqual(["https://raw.githubusercontent.com/acme/demo/main/README.md"]);
    expect(ghRun.getStdout()).toContain("# Repo Readme");
  });

  it("extracts selectors, preserves raw HTML, and writes to -o/--output", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-webread-test-"));
    try {
      const { ctx, getStdout } = createTestContext({
        cwd: tempDir,
        platform: "darwin",
        fetch: async () =>
          new Response(
            "<html><body><nav>Menu</nav><article class='doc'><h2>Spec</h2><p>Body</p></article></body></html>",
            {
              status: 200,
              headers: { "content-type": "text/html" },
            },
          ),
      });

      const outFile = path.join("nested", "out.md");
      const code = await webreadCommand.execute(
        ["-s", "article.doc", "--no-enclosure", "-o", outFile, "https://example.com"],
        ctx,
      );
      expect(code).toBe(0);
      expect(getStdout()).toContain(`Content saved to ${outFile}`);
      const saved = await fs.readFile(path.join(tempDir, outFile), "utf8");
      expect(saved).toBe("## Spec\n\nBody\n");

      const winOutFile = path.join("nested", "win-out.md");
      const winRun = createTestContext({
        cwd: tempDir,
        platform: "win32",
        fetch: async () =>
          new Response("# Win\r\n\r\nLine\r\n", {
            status: 200,
            headers: { "content-type": "text/plain" },
          }),
      });
      await expect(
        webreadCommand.execute(
          ["--no-enclosure", "-o", winOutFile, "https://example.com/a.txt"],
          winRun.ctx,
        ),
      ).resolves.toBe(0);
      const winSaved = await fs.readFile(path.join(tempDir, winOutFile), "utf8");
      expect(winSaved).toBe("# Win\n\nLine\n");
      expect(winSaved.includes("\r\n")).toBe(false);

      const rawRun = createTestContext({
        fetch: async () =>
          new Response("<p>raw</p>", { status: 200, headers: { "content-type": "text/html" } }),
      });
      await expect(
        webreadCommand.execute(["--raw", "--no-enclosure", "https://example.com"], rawRun.ctx),
      ).resolves.toBe(0);
      expect(rawRun.getStdout()).toBe("<p>raw</p>\n");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("throws ExecutionError when fetch fails", async () => {
    const { ctx } = createTestContext({
      fetch: async () => new Response("Server error", { status: 502 }),
    });
    await expect(webreadCommand.execute(["https://example.com"], ctx)).rejects.toThrow(
      ExecutionError,
    );
  });
});
