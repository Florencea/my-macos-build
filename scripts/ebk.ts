import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, readdirSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { argv } from "node:process";

/**
 * Multi line logger
 * @param contents contents to print
 */
const print = (contents: string[]) => {
  console.info(contents.join("\n").trimEnd());
};

/**
 * Copy file from source to destination
 * @param {string} source source path
 * @param {string} destination destination path
 */
const copyFile = (source: string, destination: string) => {
  if (existsSync(source)) {
    copyFileSync(source, destination);
  }
};

/**
 * Remove File
 * @param path file to remove
 */
const removeFile = (path: string) => {
  if (existsSync(path)) {
    unlinkSync(path);
  }
};

/**
 * Find file in directory
 * @param dir Target directory
 * @param patternStart pattern for target file start
 * @param patternEnd pattern for target file end
 * @returns file path or `null`
 */
const findFileInDir = (
  dir: string,
  patternStart: string,
  patternEnd: string,
) => {
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
 * @param cwd current working directory
 * @param file file
 */
const addBackup = (cwd: string, file: string) => {
  spawnSync("git", ["add", file], { cwd });
};

/**
 * Make a git commit
 * @param cwd current working directory
 * @param fileName file name for commit message
 */
const commitBackup = (cwd: string, fileName: string) => {
  spawnSync("git", ["commit", "-qm", `feat: update ${fileName} by ubk`], {
    cwd,
  });
};

/**
 * Make a git push
 * @param cwd file directory
 */
const pushBackup = (cwd: string) => {
  spawnSync("git", ["push", "-q"], { cwd });
};

/**
 * Backup file in user's download directory
 * @param patternStart pattern for target file start
 * @param patternEnd pattern for target file end
 * @param backupDir Backup directory
 * @param backupFileName file name in backup directory
 */
const backup = (
  patternStart: string,
  patternEnd: string,
  backupDir: string,
  backupFileName: string,
) => {
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
