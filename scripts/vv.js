import { unlink } from "node:fs/promises";
import { join } from "node:path";
import { exit } from "node:process";

/**
 * Check if args exist
 * @param {string[]} aa args
 * @returns {boolean} if every args exist
 */
const isExistArgs = (aa) => aa.every(Boolean);

/**
 * Check if args match length
 * @param {string[]} aa args
 * @param {number} n Length of current args
 * @returns {boolean} if args match length
 */
const isLenMatchArgs = (aa, n) => aa.length === n;

/**
 * Check if file exist
 * @param {string} p File path
 * @returns {Promise<boolean>} if file exist
 */
const isFileExist = async (p) => {
  const file = Bun.file(p);
  const e = await file.exists();
  return e;
};

/**
 * Check if file exist, or end process
 * @param {string} p File path
 */
const checkFileExist = async (p) => {
  const e = await isFileExist(p);
  if (!e) {
    await logger([`File: ${p} do not exist.`]);
    exit(0);
  }
};

/**
 * Logger
 * @param {string[]} c contnt
 * @param {boolean} n with newline, default: `true`
 */
const logger = async (c, n = true) => {
  await Bun.write(Bun.stdout, `${c.join("\n").trimEnd()}${n ? "\n" : ""}`);
};

/**
 * Get args from Bun.argv
 * @param {number} n Number of args
 * @param {string[]} u Cmd usage when error
 * @returns {Promise<string[]>} args
 */
const getArgs = async (n, u) => {
  const aa = Bun.argv.slice(3);
  if (isLenMatchArgs(aa, n) && isExistArgs(aa)) {
    return aa;
  } else {
    await logger(u);
    exit(0);
  }
};

/**
 * Get current date string for file name
 * @returns {string} Date string without comma and whitespace
 */
const getDateStrForFile = () =>
  new Intl.DateTimeFormat("lt-LT", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  })
    .format(new Date())
    .replace(/\D/g, "");

/**
 * Get file size
 * @param {string} f file
 * @returns {Promise<string>} file size
 */
const getFileSize = async (f) => {
  if (await isFileExist(f)) {
    const s = Bun.file(f).size;
    const ONE_KB = 1000;
    const ONE_MB = 1000 * 1000;
    if (s > ONE_MB) {
      return `${(s / ONE_MB).toFixed(1)} MB`;
    } else {
      return `${(s / ONE_KB).toFixed(0)} KB`;
    }
  }
};

/**
 * Copy file
 * @param {string} s source path
 * @param {string} d destination path
 */
const copyFile = async (s, d) => {
  if (await isFileExist(s)) {
    await Bun.write(d, Bun.file(s));
  }
};

/**
 * Remove Files
 * @param {string[]} df files to remove
 */
const removeFiles = (df) =>
  Promise.all(
    df.map(async (f) => {
      if (await isFileExist(f)) {
        await unlink(f);
      }
    }),
  );

/**
 * ffmpeg factory function
 * @param {string[]} args ffmpeg args
 * @param {string[]} df files to remove if failed
 * @returns {Promise<boolean>} if success
 */
const ffmpeg = async (args, df) => {
  const p = Bun.spawnSync({
    cmd: ["ffmpeg", "-hide_banner", "-loglevel", "error", ...args],
  });
  if (p.success) {
    return true;
  } else {
    await removeFiles(df);
    await logger([p.stderr]);
    return false;
  }
};

/**
 * MP4-Encoder: encode mkv (hevc) to mp4
 * @param {string} cmd current cmd (for usage string)
 */
const mp4Encoder = async (cmd) => {
  const u = [
    "encode mkv (hevc) to mp4",
    `Usage: ${cmd} [input.mkv]`,
    `       ${cmd} \'input.mkv\'`,
  ];
  const [i] = await getArgs(1, u);
  await checkFileExist(i);
  const o = i.replaceAll(".mkv", ".mp4");
  const success = await ffmpeg(
    ["-i", i, "-c:v", "copy", "-c:a", "copy", "-tag:v", "hvc1", o],
    [o],
  );
  if (success) {
    await removeFiles([i]);
  }
};

/**
 * ASS-Combiner: combile `.cht.ass` to mkv
 * @param {string} cmd current cmd (for usage string)
 */
const assCombiner = async (cmd) => {
  const u = [
    "combile .cht.ass to mkv",
    `Usage: ${cmd} [input_dir]`,
    `       ${cmd} \'input\'`,
  ];
  const [od] = await getArgs(1, u);
  const d = od.replaceAll("/", "");
  const iv = join(d, `${d}.mkv`);
  const ia = join(d, `${d}.cht.ass`);
  await checkFileExist(iv);
  await checkFileExist(ia);
  const o = join(d, `temp_${d}.mkv`);
  const success = await ffmpeg(
    [
      "-i",
      iv,
      "-i",
      ia,
      "-c:v",
      "copy",
      "-c:a",
      "copy",
      "-c:s",
      "copy",
      "-map",
      "0:0",
      "-map",
      "0:1",
      "-map",
      "1:0",
      "-disposition:s:0",
      "default",
      o,
    ],
    [o],
  );
  if (success) {
    await copyFile(o, iv);
    await removeFiles([o]);
  }
};

/**
 * Re-Encoder: re-encode a mp4
 * @param {string} cmd current cmd (for usage string)
 */
const reEncoder = async (cmd) => {
  const u = [
    "re-encode a mp4",
    `Usage: ${cmd} [input_file]`,
    `       ${cmd} 'input.mp4'`,
  ];
  const [i] = await getArgs(1, u);
  await checkFileExist(i);
  const o = `temp_${i}`;
  const success = await ffmpeg(
    ["-i", i, "-vcodec", "copy", "-acodec", "copy", o],
    [o],
  );
  if (success) {
    await copyFile(o, i);
    await removeFiles([o]);
  }
};

/**
 * Gif Maker
 * @param {string} cmd current cmd (for usage string)
 * @param {number} fps FPS for gif
 * @param {number} w width for gif
 */
const gifMaker = async (cmd, fps, w) => {
  const u = [
    "Gif Maker",
    `Usage: ${cmd} [input_file] [from(hh:mm:ss or sec)] [during(sec)]`,
    `       ${cmd} 'input.mp4' 01:02:08 11.0`,
  ];
  const [i, ss, t] = await getArgs(3, u);
  await checkFileExist(i);
  const o = `${getDateStrForFile()}_fps${fps}.gif`;
  const success = await ffmpeg(
    [
      "-ss",
      ss,
      "-t",
      t,
      "-i",
      i,
      "-filter_complex",
      `[0:v] fps=${fps},scale=w=${w}:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1`,
      o,
    ],
    [o],
  );
  if (success) {
    await logger([`${o} ${await getFileSize(o)}`]);
  }
};

/**
 * main function
 */
const main = async () => {
  const cmd = Bun.argv[2];
  switch (cmd) {
    case "mkgif":
      await gifMaker(cmd, 12, 480);
      break;
    case "mkgifv":
      await gifMaker(cmd, 24, 480);
      break;
    case "rec":
      await reEncoder(cmd);
      break;
    case "rea":
      await assCombiner(cmd);
      break;
    case "re4":
      await mp4Encoder(cmd);
      break;
    default:
      await logger([
        "vv available commands:",
        "mkgif:  Gif Maker (12fps)",
        "mkgifv: Gif Maker (24fps)",
        "rec:    Re-Encoder: re-encode a mp4",
        "rea:    ASS-Combiner: combile .cht.ass to mkv",
        "re4:    MP4-Encoder: encode mkv (hevc) to mp4",
      ]);
      break;
  }
};

main();