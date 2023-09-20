import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, readdirSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { argv } from "node:process";

/**
 * Multi line logger
 * @param {string[]} contents contents to print
 */
const print = (contents) => {
  console.info(contents.join("\n").trimEnd());
};

/**
 * Copy file from source to destination
 * @param {string} source source path
 * @param {string} destination destination path
 */
const copyFile = (source, destination) => {
  if (existsSync(source)) {
    copyFileSync(source, destination);
  }
};

/**
 * Remove File
 * @param {string} path file to remove
 */
const removeFile = (path) => {
  if (existsSync(path)) {
    unlinkSync(path);
  }
};

/**
 * Find file in directory
 * @param {string} dir Target directory
 * @param {string} patternStart pattern for target file start
 * @param {string} patternEnd pattern for target file end
 * @returns file path or `null`
 */
const findFileInDir = (dir, patternStart, patternEnd) => {
  const file = readdirSync(dir, { withFileTypes: true })
    .filter(
      (inode) =>
        !inode.isDirectory() &&
        inode.name.startsWith(patternStart) &&
        inode.name.endsWith(patternEnd),
    )
    .map((inode) => inode.name)?.[0];
  if (file) {
    return join(dir, file);
  } else {
    return null;
  }
};

/**
 * Add file to git
 * @param {string} cwd current working directory
 * @param {string} file file
 */
const addBackup = (cwd, file) => {
  spawnSync("git", ["add", file], { cwd });
};

/**
 * Make a git commit
 * @param {string} cwd current working directory
 * @param {string} fileName file name for commit message
 */
const commitBackup = (cwd, fileName) => {
  spawnSync("git", ["commit", "-qm", `feat: update ${fileName} by ubk`], {
    cwd,
  });
};

/**
 * Make a git push
 * @param {string} cwd file directory
 */
const pushBackup = (cwd) => {
  spawnSync("git", ["push", "-q"], { cwd });
};

/**
 * Backup file in user's download directory
 * @param {string} patternStart pattern for target file start
 * @param {string} patternEnd pattern for target file end
 * @param {string} backupDir Backup directory
 * @param {string} backupFileName file name in backup directory
 */
const backup = (patternStart, patternEnd, backupDir, backupFileName) => {
  const targetDir = join(homedir(), "Downloads");
  const targetFilePath = findFileInDir(targetDir, patternStart, patternEnd);
  if (targetFilePath) {
    print([
      `Backup Configuration: ${targetFilePath}`,
      `     --> ${backupFileName}`,
    ]);
    const backupFilePath = join(backupDir, backupFileName);
    copyFile(targetFilePath, backupFilePath);
    removeFile(targetFilePath);
    addBackup(backupDir, backupFileName);
    commitBackup(backupDir, backupFileName);
    pushBackup(backupDir);
  }
};

/**
 * main funcion
 */
const main = () => {
  const backupDir = argv[2];
  backup("my-ublock-backup", ".txt", backupDir, "ubo-config.txt");
  backup("tampermonkey-backup-", ".zip", backupDir, "userscript.zip");
  backup("tongwentang-", "json", backupDir, "tongwentang.json");
};

main();
