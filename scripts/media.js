import { unlink } from "node:fs/promises";
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
 * mkgif
 * @param {number} fps FPS for gif
 * @param {number} w width for gif
 */
const mkgif = async (fps, w) => {
  const u = [
    "Usage: mkgif [input_file] [from(hh:mm:ss or sec)] [during(sec)]",
    "       mkgif 'input.mp4' 01:02:08 11.0",
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
    await logger([o]);
  }
};

/**
 * main function
 */
const main = async () => {
  switch (Bun.argv[2]) {
    case "mkgif":
      await mkgif(12, 480);
      break;
    case "mkgifv":
      await mkgif(24, 480);
      break;
    case "rec":
      await logger(["under developing..."]);
      break;
    case "rea":
      await logger(["under developing..."]);
      break;
    case "re4":
      await logger(["under developing..."]);
      break;
    default:
      await logger(["Unknown commands"]);
      break;
  }
};

main();
