import { readdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Check if file or directory exist
 * @param path File/Dir path
 * @returns if file or directory exist
 */
const isInodeExist = async (path: string) => {
  const file = Bun.file(path);
  return file.size > 0;
};

/**
 * Single line logger
 * @param content content to print
 * @param withNewline print `\n` at content end, default: `false`
 */
const logger = async (content: string, withNewline: boolean = false) => {
  await Bun.write(Bun.stdout, `${content}${withNewline ? "\n" : ""}`);
};

/**
 * Sync git projects
 * @param codeSpacePath codespace path
 */
const syncGitProjects = async (codeSpacePath: string) => {
  (await readdir(codeSpacePath, { withFileTypes: true }))
    .filter((inode) => inode.isDirectory())
    .map((dir) => dir.name)
    .map(async (projectDir) => {
      const cwd = join(codeSpacePath, projectDir);
      const gitDir = join(cwd, ".git");
      if (await isInodeExist(gitDir)) {
        const p = Bun.spawn({
          cwd,
          cmd: ["git", "pull", "--all"],
          stdout: "pipe",
          stderr: "pipe",
        });
        const stdoutText = await new Response(p.stdout).text();
        const stderrText = await new Response(p.stderr).text();
        if (stdoutText) {
          await logger(`Syncing \x1b[1m${projectDir}\x1b[0m ${stdoutText}`);
        }
        if (stderrText) {
          await logger(`Syncing \x1b[1m${projectDir}\x1b[0m \n${stderrText}`);
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
