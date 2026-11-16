import { defineCommand } from "../lib/cli-framework.ts";

export const mmbCommand = defineCommand({
  name: "mmb",
  summary: "Open current build workspace in Visual Studio Code",
  usage: "mmb",
  flags: {},
  positionals: { min: 0, max: 0, label: "" },
  requiredCommands: ["code"],
  async run({ ctx }) {
    return await ctx.runner.spawnInteractive("code", [ctx.repoRoot]);
  },
});
