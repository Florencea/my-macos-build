import { readdir, unlink } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Single line logger
 * @param content content to print
 * @param withNewline print `\n` at content end, default: `true`
 */
const logger = async (content: string[], withNewline: boolean = true) => {
  await Bun.write(
    Bun.stdout,
    `${content.join("\n").trimEnd()}${withNewline ? "\n" : ""}`,
  );
};

/**
 * Check if file exist
 * @param path File path
 * @returns if file exist
 */
const isFileExist = async (path: string) => Bun.file(path).exists();

/**
 * Copy file from source to destination
 * @param {string} source source path
 * @param {string} destination destination path
 */
const copyFile = async (source: string, destination: string) => {
  if (await isFileExist(source)) {
    await Bun.write(destination, Bun.file(source));
  }
};

/**
 * Remove File
 * @param path file to remove
 */
const removeFile = async (path: string) => {
  if (await isFileExist(path)) {
    await unlink(path);
  }
};

/**
 * Find file in directory
 * @param dir Target directory
 * @param patternStart pattern for target file start
 * @param patternEnd pattern for target file end
 * @returns file path or `null`
 */
const findFileInDir = async (
  dir: string,
  patternStart: string,
  patternEnd: string,
) => {
  const file = (await readdir(dir, { withFileTypes: true }))
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
const addBackup = (cwd: string, file: string) =>
  Bun.spawnSync({
    cwd,
    cmd: ["git", "add", file],
  });

/**
 * Make a git commit
 * @param cwd current working directory
 * @param fileName file name for commit message
 */
const commitBackup = (cwd: string, fileName: string) =>
  Bun.spawnSync({
    cwd,
    cmd: ["git", "commit", "-qm", `feat: update ${fileName} by ubk`],
  });

/**
 * Make a git push
 * @param cwd file directory
 */
const pushBackup = async (cwd: string) =>
  Bun.spawnSync({
    cwd,
    cmd: ["git", "push", "-q"],
  });

/**
 * Backup file in user's download directory
 * @param patternStart pattern for target file start
 * @param patternEnd pattern for target file end
 * @param backupDir Backup directory
 * @param backupFileName file name in backup directory
 */
const backup = async (
  patternStart: string,
  patternEnd: string,
  backupDir: string,
  backupFileName: string,
) => {
  const targetDir = join(homedir(), "Downloads");
  const targetFilePath = await findFileInDir(
    targetDir,
    patternStart,
    patternEnd,
  );
  if (targetFilePath) {
    await logger([
      `Backup Configuration: ${targetFilePath}`,
      `     --> ${backupFileName}`,
    ]);
    const backupFilePath = join(backupDir, backupFileName);
    await copyFile(targetFilePath, backupFilePath);
    await removeFile(targetFilePath);
    addBackup(backupDir, backupFileName);
    commitBackup(backupDir, backupFileName);
    pushBackup(backupDir);
  }
};

/**
 * main funcion
 */
const main = async () => {
  const backupDir = Bun.argv[2];
  await backup("my-ublock-backup", ".txt", backupDir, "ubo-config.txt");
  await backup("tampermonkey-backup-", ".zip", backupDir, "userscript.zip");
  await backup("tongwentang-", "json", backupDir, "tongwentang.json");
};

main();
