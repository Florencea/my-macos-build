import { readdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Check if file or directory exist
 * @param {string} p File/Dir path
 * @returns {Promise<boolean>} if file or directory exist
 */
const isInodeExist = async (p) => {
  const file = Bun.file(p);
  return file.size > 0;
};

/**
 * Logger
 * @param {string} c contnt
 * @param {boolean} n with newline, default: `false`
 */
const logger = async (c, n = false) => {
  await Bun.write(Bun.stdout, `${c}${n ? "\n" : ""}`);
};

/**
 * Sync git projects
 * @param {string} c codespace path
 */
const syncGitProjects = async (c) => {
  (await readdir(c, { withFileTypes: true }))
    .filter((f) => f.isDirectory())
    .map((f) => f.name)
    .map(async (d) => {
      const cwd = join(c, d);
      const g = join(cwd, ".git");
      if (await isInodeExist(g)) {
        const p = await Bun.spawn({
          cwd,
          cmd: ["git", "pull", "--all"],
          stdout: "pipe",
          stderr: "pipe",
        });
        const o = await new Response(p.stdout).text();
        const e = await new Response(p.stderr).text();
        if (o) {
          await logger(`Syncing \x1b[1m${d}\x1b[0m ${o}`);
        }
        if (e) {
          await logger(`Syncing \x1b[1m${d}\x1b[0m \n${e}`);
        }
      }
    });
};

/**
 * brew upgrade
 */
const brewUpgrade = () =>
  Bun.spawnSync({
    cwd: homedir(),
    cmd: ["brew", "upgrade"],
    stdout: "inherit",
    stderr: "inherit",
  });

/**
 * main function
 */
const main = async () => {
  brewUpgrade();
  await syncGitProjects(Bun.argv[2]);
};

main();
