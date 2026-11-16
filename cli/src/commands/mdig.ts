import { z } from "zod";

import { defineCommand } from "../lib/cli-framework.ts";
import { UsageError, type CommandContext } from "../lib/context.ts";

const DomainSchema = z
  .string()
  .trim()
  .min(1, "Domain cannot be empty")
  .refine((value) => !/\s/.test(value), "Domain cannot contain whitespace");

const DNS_QUERY_TIMEOUT_MS = 2000;

const TIMEOUT_ERROR_CODES = new Set([
  "ETIMEOUT",
  "ECANCELLED",
  "ECONNREFUSED",
  "ENETUNREACH",
  "EHOSTUNREACH",
]);

interface DnsServerSpec {
  readonly index: number;
  readonly name: string;
  readonly ipv4: string;
  readonly ipv6: string;
}

export const MDIG_DNS_SERVERS: readonly DnsServerSpec[] = [
  { index: 0, name: "Google", ipv4: "8.8.8.8", ipv6: "2001:4860:4860::8888" },
  { index: 1, name: "Cloudflare", ipv4: "1.1.1.1", ipv6: "2606:4700:4700::1111" },
  { index: 2, name: "Hinet", ipv4: "168.95.192.1", ipv6: "2001:b000:168::1" },
  { index: 3, name: "Hinet", ipv4: "168.95.1.1", ipv6: "2001:b000:168::2" },
  { index: 4, name: "System", ipv4: "", ipv6: "" },
] as const;

interface DnsQueryResult {
  readonly index: number;
  readonly name: string;
  readonly recordType: "A" | "AAAA";
  readonly serverIp: string;
  readonly key: string;
  readonly timeMs: string;
}

const NodeDnsErrorSchema = z.object({
  code: z.string().optional(),
  message: z.string().optional(),
});

function isTimeoutDnsError(err: unknown): boolean {
  const parsed = NodeDnsErrorSchema.safeParse(err);
  if (parsed.success) {
    if (parsed.data.code !== undefined && TIMEOUT_ERROR_CODES.has(parsed.data.code)) {
      return true;
    }
    if (parsed.data.message !== undefined && /timeout|timed out/i.test(parsed.data.message)) {
      return true;
    }
  }
  return false;
}

async function querySingleServer(
  ctx: CommandContext,
  domain: string,
  server: DnsServerSpec,
  recordType: "A" | "AAAA",
): Promise<DnsQueryResult> {
  const serverIp = recordType === "A" ? server.ipv4 : server.ipv6;
  const startMs = ctx.now().getTime();

  try {
    const ips = await ctx.dns.resolve({
      domain,
      recordType,
      serverIp: serverIp !== "" ? serverIp : undefined,
      timeoutMs: DNS_QUERY_TIMEOUT_MS,
    });
    const elapsedMs = Math.max(0, Math.round(ctx.now().getTime() - startMs)).toString();
    const sorted = [...ips].filter((ip) => ip.trim() !== "").toSorted();
    const key = sorted.length === 0 ? `[no ${recordType} record]` : sorted.join(",");
    return {
      index: server.index,
      name: server.name,
      recordType,
      serverIp,
      key,
      timeMs: elapsedMs,
    };
  } catch (err) {
    const elapsedMs = Math.max(0, Math.round(ctx.now().getTime() - startMs)).toString();
    if (isTimeoutDnsError(err)) {
      return {
        index: server.index,
        name: server.name,
        recordType,
        serverIp,
        key: `[${recordType} timeout]`,
        timeMs: "",
      };
    }
    return {
      index: server.index,
      name: server.name,
      recordType,
      serverIp,
      key: `[no ${recordType} record]`,
      timeMs: elapsedMs,
    };
  }
}

function formatDnsSection(title: string, items: readonly DnsQueryResult[]): string {
  const lines: string[] = [`── ${title} ──`];
  const order: string[] = [];
  const groups = new Map<string, DnsQueryResult[]>();

  const sortedItems = [...items].toSorted((a, b) => a.index - b.index);
  for (const item of sortedItems) {
    const existing = groups.get(item.key);
    if (existing !== undefined) {
      existing.push(item);
    } else {
      order.push(item.key);
      groups.set(item.key, [item]);
    }
  }

  for (const key of order) {
    if (key.startsWith("[")) {
      lines.push(key);
    } else {
      for (const ip of key.split(",")) {
        lines.push(ip);
      }
    }

    const entries = groups.get(key) ?? [];
    for (const entry of entries) {
      const desc = entry.serverIp !== "" ? `${entry.name} (${entry.serverIp})` : entry.name;
      if (entry.timeMs !== "") {
        lines.push(`  - ${desc} [${entry.timeMs} ms]`);
      } else {
        lines.push(`  - ${desc}`);
      }
    }
    lines.push("");
  }

  return lines.join("\n");
}

/**
 * Multi-dig: Check A and AAAA records across multiple DNS resolvers in parallel.
 */
export const mdigCommand = defineCommand({
  name: "mdig",
  summary: "Multi-dig: Check DNS records on different DNS servers at once",
  usage: "mdig <domain>",
  examples: ["mdig 'is1-ssl.mzstatic.com'"],
  flags: {},
  positionals: { min: 1, max: 1, label: "domain" },
  async run({ positionals, ctx }) {
    const parsedDomain = DomainSchema.safeParse(positionals[0] ?? "");
    if (!parsedDomain.success) {
      const detail = parsedDomain.error.issues[0]?.message ?? "Invalid domain";
      throw new UsageError(`Error: ${detail}`, true);
    }
    const domain = parsedDomain.data;

    const tasks: Promise<DnsQueryResult>[] = [];
    for (const server of MDIG_DNS_SERVERS) {
      tasks.push(querySingleServer(ctx, domain, server, "A"));
      tasks.push(querySingleServer(ctx, domain, server, "AAAA"));
    }

    const results = await Promise.all(tasks);
    const aResults = results.filter((r) => r.recordType === "A");
    const aaaaResults = results.filter((r) => r.recordType === "AAAA");

    ctx.stdout(`${formatDnsSection("A Records", aResults)}\n`);
    ctx.stdout(`${formatDnsSection("AAAA Records", aaaaResults)}\n`);
    return 0;
  },
});
