import { readdir, unlink } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Logger
 * @param {string[]} c contnt
 * @param {boolean} n with newline, default: `true`
 */
const logger = async (c: string[], n: boolean = true) => {
  await Bun.write(Bun.stdout, `${c.join("\n").trimEnd()}${n ? "\n" : ""}`);
};

/**
 * Check if file exist
 * @param {string} p File path
 * @returns {Promise<boolean>} if file exist
 */
const isFileExist = async (p: string): Promise<boolean> => {
  const file = Bun.file(p);
  const e = await file.exists();
  return e;
};

/**
 * Copy file
 * @param {string} s source path
 * @param {string} d destination path
 */
const copyFile = async (s: string, d: string) => {
  if (await isFileExist(s)) {
    await Bun.write(d, Bun.file(s));
  }
};

/**
 * Remove File
 * @param {string} f file to remove
 */
const removeFile = async (f: string) => {
  if (await isFileExist(f)) {
    await unlink(f);
  }
};

/**
 * Find file in directory
 * @param {string} td Target directory
 * @param {string} ps pattern for target file start
 * @param {string} pe pattern for target file end
 * @returns {Promise<string?>} file path or `null`
 */
const findFileInDir = async (
  td: string,
  ps: string,
  pe: string,
): Promise<string | null> => {
  const f = (await readdir(td, { withFileTypes: true }))
    .filter(
      (f) => !f.isDirectory() && f.name.startsWith(ps) && f.name.endsWith(pe),
    )
    .map((f) => f.name)?.[0];
  if (f) {
    return join(td, f);
  } else {
    return null;
  }
};

/**
 * Add files to git
 * @param {string} d file directory
 * @param {string} f file
 */
const addBackup = (d: string, f: string) =>
  Bun.spawnSync({
    cwd: d,
    cmd: ["git", "add", f],
  });

/**
 * Make a git commit
 * @param {string} d file directory
 * @param {string} f file name
 */
const commitBackup = (d: string, f: string) =>
  Bun.spawnSync({
    cwd: d,
    cmd: ["git", "commit", "-qm", `feat: update ${f} by ubk`],
  });

/**
 * Make a git push
 * @param {string} d file directory
 */
const pushBackup = async (d: string) =>
  Bun.spawnSync({
    cwd: d,
    cmd: ["git", "push", "-q"],
  });

/**
 * Backup file in user's download directory
 * @param {string} ps pattern for target file start
 * @param {string} pe pattern for target file end
 * @param {string} d Backup directory
 * @param {string} f file name in backup
 */
const backup = async (ps: string, pe: string, d: string, f: string) => {
  const td = join(homedir(), "Downloads");
  const ff = await findFileInDir(td, ps, pe);
  if (ff) {
    await logger([`Backup Configuration: ${ff}`, `     --> ${f}`]);
    const dd = join(d, f);
    await copyFile(ff, dd);
    await removeFile(ff);
    addBackup(d, f);
    commitBackup(d, f);
    pushBackup(d);
  }
};

/**
 * main funcion
 */
const main = async () => {
  const d = Bun.argv[2];
  await backup("my-ublock-backup", ".txt", d, "ubo-config.txt");
  await backup("tampermonkey-backup-", ".zip", d, "userscript.zip");
  await backup("tongwentang-", "json", d, "tongwentang.json");
};

main();
