import { spawn, spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { argv, stdout } from "node:process";

/**
 * Sync git projects
 * @param {string} codeSpacePath codespace path
 */
const syncGitProjects = (codeSpacePath) => {
  readdirSync(codeSpacePath, { withFileTypes: true })
    .filter((inode) => inode.isDirectory())
    .map((dir) => dir.name)
    .map((projectDir) => {
      const cwd = join(codeSpacePath, projectDir);
      const gitDir = join(cwd, ".git");
      if (existsSync(gitDir)) {
        const p = spawn("git", ["pull", "--all"], {
          cwd,
        });
        p.stdout.on("data", (data) => {
          stdout.write(`Syncing \x1b[1m${projectDir}\x1b[0m ${data}`);
        });
        p.stderr.on("data", (data) => {
          stdout.write(`Syncing \x1b[1m${projectDir}\x1b[0m \n${data}`);
        });
      }
    });
};

/**
 * brew upgrade
 */
const brewUpgrade = () => {
  spawnSync("brew", ["upgrade"], { cwd: homedir(), stdio: "inherit" });
};

/**
 * main function
 */
const main = () => {
  brewUpgrade();
  syncGitProjects(argv[2]);
};

main();
