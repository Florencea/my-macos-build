import { z } from "zod";
import { defineCommand } from "../lib/cli-framework.ts";

const EmptyOptionsSchema = z.object({});

export const mmbCommand = defineCommand({
  name: "mmb",
  summary: "Open current build workspace in Visual Studio Code",
  usage: "mmb",
  flags: {},
  optionsSchema: EmptyOptionsSchema,
  positionals: { min: 0, max: 0, label: "" },
  requiredCommands: ["code"],
  async run({ ctx }) {
    return await ctx.runner.spawnInteractive("code", [ctx.repoRoot]);
  },
});
