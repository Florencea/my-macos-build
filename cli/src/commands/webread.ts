import path from "node:path";
import { z } from "zod";
import { defineCommand, parseValidatedInt } from "../lib/cli-framework.ts";
import { ExecutionError, UsageError, type CommandContext } from "../lib/context.ts";
import { parseWebContent } from "../lib/webread-parser.ts";

const DEFAULT_MAX_CHARS = 64_000;
const JINA_TIMEOUT_MS = 15_000;
const FETCH_TIMEOUT_MS = 20_000;
const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
const ACCEPT_HEADER =
  "text/markdown, text/plain;q=0.95, text/html;q=0.9, application/xhtml+xml;q=0.8, application/json;q=0.7";

const WebreadOptionsSchema = z.object({
  llms: z.boolean().default(false),
  selector: z.string().optional(),
  raw: z.boolean().default(false),
  output: z.string().optional(),
  jina: z.boolean().default(false),
  external: z.boolean().default(false),
  "no-enclosure": z.boolean().default(false),
  "max-chars": z.string().optional(),
});

const TargetUrlSchema = z.url({ protocol: /^https?$/ });

interface FetchedPayload {
  readonly body: string;
  readonly contentType: string;
  readonly effectiveUrl: string;
}

/**
 * Rewrites GitHub blob URLs to raw.githubusercontent.com for direct source reading.
 */
export function resolveGitHubRawUrl(uriText: string, raw: boolean): string | null {
  if (raw) {
    return null;
  }
  const match = uriText.match(
    /^https?:\/\/github\.com\/([^/]+)\/([^/]+)\/blob\/([^?#]+)(?:\?.*)?(?:#.*)?$/,
  );
  if (match === null) {
    return null;
  }
  const owner = match[1];
  const repo = match[2];
  const branchAndPath = match[3];
  if (owner === undefined || repo === undefined || branchAndPath === undefined) {
    return null;
  }
  return `https://raw.githubusercontent.com/${owner}/${repo}/${branchAndPath}`;
}

/**
 * Normalizes and validates an input URL string, defaulting bare hosts to HTTPS.
 */
export function normalizeTargetUrl(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  const withScheme = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  const validated = TargetUrlSchema.safeParse(withScheme);
  if (!validated.success) {
    throw new UsageError(`Error: Invalid URI '${withScheme}'`, false);
  }
  return validated.data;
}

async function fetchTextPayload(
  ctx: CommandContext,
  url: string,
  headers: Readonly<Record<string, string>>,
  timeoutMs: number,
): Promise<FetchedPayload | null> {
  try {
    const timeoutSignal = AbortSignal.timeout(timeoutMs);
    const signal =
      ctx.signal !== undefined ? AbortSignal.any([ctx.signal, timeoutSignal]) : timeoutSignal;
    const response = await ctx.fetch(url, {
      headers,
      redirect: "follow",
      signal,
    });
    if (!response.ok) {
      return null;
    }
    const body = await response.text();
    if (body === "") {
      return null;
    }
    const contentType = response.headers.get("content-type") ?? "";
    const effectiveUrl = response.url !== "" ? response.url : url;
    return { body, contentType, effectiveUrl };
  } catch {
    return null;
  }
}

async function fetchWebreadContent(input: {
  readonly ctx: CommandContext;
  readonly targetUrl: string;
  readonly llms: boolean;
  readonly useJina: boolean;
  readonly raw: boolean;
  readonly selector: string | undefined;
  readonly maxChars: number;
  readonly untrustedEnclosure: boolean;
}): Promise<string> {
  const { ctx, targetUrl, llms, useJina, raw, selector, maxChars, untrustedEnclosure } = input;

  const parsePayload = async (
    payload: FetchedPayload,
    fallbackUrl: string,
    fallbackContentType?: string,
  ): Promise<string> => {
    const sourceUrl = payload.effectiveUrl !== "" ? payload.effectiveUrl : fallbackUrl;
    const contentType =
      payload.contentType !== "" ? payload.contentType : (fallbackContentType ?? "");
    return await parseWebContent(payload.body, {
      url: sourceUrl,
      selector,
      contentType: contentType !== "" ? contentType : undefined,
      raw,
      maxLength: maxChars,
      untrustedEnclosure,
    });
  };

  if (llms) {
    const origin = new URL(targetUrl).origin;
    const fullUrl = `${origin}/llms-full.txt`;
    const fullPayload = await fetchTextPayload(
      ctx,
      fullUrl,
      { "User-Agent": USER_AGENT },
      FETCH_TIMEOUT_MS,
    );
    if (fullPayload !== null) {
      return await parsePayload(fullPayload, fullUrl);
    }

    const indexUrl = `${origin}/llms.txt`;
    const indexPayload = await fetchTextPayload(
      ctx,
      indexUrl,
      { "User-Agent": USER_AGENT },
      FETCH_TIMEOUT_MS,
    );
    if (indexPayload !== null) {
      return await parsePayload(indexPayload, indexUrl);
    }

    ctx.stderr(
      `Notice: Neither /llms-full.txt nor /llms.txt found on ${origin}, falling back to local reader...\n`,
    );
  }

  if (useJina) {
    ctx.stderr("Notice: Using external Jina Reader service (r.jina.ai)...\n");
    const jinaUrl = `https://r.jina.ai/${targetUrl}`;
    const payload = await fetchTextPayload(ctx, jinaUrl, { "X-No-Cache": "true" }, JINA_TIMEOUT_MS);
    if (payload !== null && !/Request failed with status code/i.test(payload.body)) {
      const jinaContentType = payload.contentType !== "" ? payload.contentType : "text/markdown";
      return await parseWebContent(payload.body, {
        url: targetUrl,
        selector,
        contentType: jinaContentType,
        raw,
        maxLength: maxChars,
        untrustedEnclosure,
      });
    }
    ctx.stderr("Notice: External Jina Reader unavailable, falling back to local reader...\n");
  }

  const githubRawUrl = resolveGitHubRawUrl(targetUrl, raw);
  if (githubRawUrl !== null) {
    const rawPayload = await fetchTextPayload(
      ctx,
      githubRawUrl,
      { "User-Agent": USER_AGENT },
      FETCH_TIMEOUT_MS,
    );
    if (rawPayload !== null) {
      return await parsePayload(rawPayload, githubRawUrl, "text/plain");
    }
  }

  const fetchedPayload = await fetchTextPayload(
    ctx,
    targetUrl,
    {
      "User-Agent": USER_AGENT,
      Accept: ACCEPT_HEADER,
    },
    FETCH_TIMEOUT_MS,
  );
  if (fetchedPayload === null) {
    throw new ExecutionError(`Error: Failed to fetch content from ${targetUrl}`, 1);
  }

  return await parsePayload(fetchedPayload, targetUrl);
}

/**
 * Clean, token-efficient, local-first webpage and documentation reader.
 */
export const webreadCommand = defineCommand({
  name: "webread",
  summary: "Clean, token-efficient, secure webpage and documentation reader",
  usage: "webread [options] <url>",
  examples: [
    "webread --llms https://viteplus.dev",
    "webread https://react.dev/learn/you-might-not-need-an-effect",
    "webread -s 'article' https://oxc.rs",
    "webread --raw https://example.com -o page.html",
  ],
  flags: {
    llms: {
      type: "boolean",
      short: "l",
      description: "Probe /llms-full.txt or /llms.txt from domain",
    },
    selector: {
      type: "string",
      short: "s",
      valueName: "sel",
      description: "Extract CSS selector, tag, #id, or .class",
    },
    raw: {
      type: "boolean",
      short: "r",
      description: "Fetch raw content without Markdown conversion",
    },
    output: {
      type: "string",
      short: "o",
      valueName: "file",
      description: "Save output directly to a file",
    },
    jina: {
      type: "boolean",
      description: "Use Jina Reader (r.jina.ai) fallback (opt-in)",
    },
    external: {
      type: "boolean",
      description: "Alias for --jina",
    },
    "no-enclosure": {
      type: "boolean",
      description: "Omit <UNTRUSTED_EXTERNAL_WEB_CONTENT> barrier",
    },
    "max-chars": {
      type: "string",
      valueName: "n",
      description: "Max characters before truncation (default: 64000)",
    },
  },
  optionsSchema: WebreadOptionsSchema,
  positionals: { min: 1, max: 1, label: "url" },
  async run({ options, positionals, ctx }) {
    const rawMaxChars = options["max-chars"];
    const maxChars =
      rawMaxChars !== undefined
        ? parseValidatedInt(rawMaxChars, "--max-chars", 1)
        : DEFAULT_MAX_CHARS;

    const targetUrl = normalizeTargetUrl(positionals[0] ?? "");
    const useJina = options.jina || options.external;

    const result = await fetchWebreadContent({
      ctx,
      targetUrl,
      llms: options.llms,
      useJina,
      raw: options.raw,
      selector: options.selector,
      maxChars,
      untrustedEnclosure: !options["no-enclosure"],
    });

    if (result === "") {
      return 1;
    }

    const outputPath = options.output;
    if (outputPath !== undefined && outputPath.trim() !== "") {
      const absOut = path.resolve(ctx.cwd, outputPath);
      await ctx.fs.mkdir(path.dirname(absOut), { recursive: true });
      const normalized = `${result.replace(/\r\n/g, "\n").replace(/\n+$/g, "")}\n`;
      await ctx.fs.writeFile(absOut, normalized, "utf8");
      ctx.stdout(`Content saved to ${outputPath}\n`);
      return 0;
    }

    ctx.stdout(`${result}\n`);
    return 0;
  },
});
