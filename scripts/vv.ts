import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, statSync, unlinkSync } from "node:fs";
import { join, parse } from "node:path";
import { argv, exit } from "node:process";

/**
 * Check if args exist (not `null`, `undefined`, `""`)
 * @param args args
 * @returns if every args exist
 */
const isExistArgs = (args: string[]) => args.every(Boolean);

/**
 * Check if args match length
 * @param args args
 * @param len Length of current args
 * @returns if args match length
 */
const isLenMatchArgs = (args: string[], len: number) => args.length === len;

/**
 * Check if file exist
 * @param path File path
 * @returns if file exist
 */
const isFileExist = (path: string) => existsSync(path);

/**
 * Check if file exist, if not, exit current process
 * @param path File path
 */
const checkFileExistOrAbort = (path: string) => {
  if (!isFileExist(path)) {
    print([`File: ${path} do not exist.`]);
    exit(0);
  }
};

/**
 * Check if file video codec is HEVC
 * @param path File path
 * @returns if file video codec is HEVC
 */
const checkFileCodecIsHevc = (path: string) => {
  const { status, stdout } = spawnSync("ffprobe", [
    "-v",
    "error",
    "-select_streams",
    "v:0",
    "-show_entries",
    "stream=codec_name",
    "-of",
    "default=noprint_wrappers=1:nokey=1",
    path,
  ]);
  if (status === 0) {
    return stdout.toString().trim().toLowerCase() === "hevc";
  } else {
    return false;
  }
};

/**
 * Replace file extenstion
 * @param path File path
 * @param ext File ext to replace, ex: `mp4`
 * @returns replaced file path
 * @example
 * ```ts
 * const newPath = replaceFileExt("/User/Downloads/1.mkv", "mp4")
 * // "/User/Downloads/1.mp4"
 * const newPath = replaceFileExt("/User/Downloads/1", "mp4")
 * // "/User/Downloads/1.mp4"
 * const newPath = replaceFileExt("/User/Downloads/1/", "mp4")
 * // "/User/Downloads/1.mp4"
 * ```
 */
const replaceFileExt = (path: string, ext: string) => {
  const parsedPath = parse(path);
  return join(parsedPath.dir, `${parsedPath.name}.${ext}`);
};

/**
 * Multi line logger
 * @param contents contents to print
 */
const print = (contents: string[]) => {
  console.info(contents.join("\n").trimEnd());
};

/**
 * Get args from argv
 * @param len Length of args
 * @param usage Cmd usage shows when args length does not match or any empty arg exist
 * @returns args
 * ```ts
 * // $ vv mkgif a b c
 * const args = getArgs(3, ["..."]);
 * // [a, b, c]
 *
 * // $ vv mkgif a b c
 * const args = getArgs(2, ["..."]);
 * // print ["..."] and exit current process
 * ```
 */
const getArgs = (len: number, usage: string[]) => {
  const args = argv.slice(3);
  if (isLenMatchArgs(args, len) && isExistArgs(args)) {
    return args;
  } else {
    print(usage);
    exit(0);
  }
};

/**
 * Get current date string for unique file name
 * @returns Date string without comma and whitespace. Ex: `20230918011637`
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
 * Get human readable file size Ex: `1.5 GB`, `2.1 MB`, `322 KB`
 * @param path file path
 * @returns Readable file size string (return `""` if file not exist)
 */
const getFileSize = (path: string) => {
  if (isFileExist(path)) {
    /**
     * file size in bytes
     */
    const { size } = statSync(path);
    const ONE_GB = 1000 * 1000 * 1000;
    const ONE_MB = 1000 * 1000;
    const ONE_KB = 1000;
    if (size > ONE_GB) {
      return `${(size / ONE_GB).toFixed(1)} GB`;
    } else if (size > ONE_MB) {
      return `${(size / ONE_MB).toFixed(1)} MB`;
    } else {
      return `${(size / ONE_KB).toFixed(0)} KB`;
    }
  } else {
    return "";
  }
};

/**
 * Copy file from source to destination
 * @param source source path
 * @param destination destination path
 */
const copyFileIfExist = (source: string, destination: string) => {
  if (isFileExist(source)) {
    copyFileSync(source, destination);
  }
};

/**
 * Remove multi files
 * @param paths files to remove
 */
const removeFiles = (paths: string[]) => {
  paths.map((path) => {
    if (isFileExist(path)) {
      unlinkSync(path);
    }
  });
};

/**
 * ffmpeg factory function
 * @param args ffmpeg args
 * @param filesToClear files to remove if failed
 * @returns if the operation success
 */
const ffmpeg = (args: string[], filesToClear: string[] = []) => {
  const { status, stderr } = spawnSync("ffmpeg", [
    "-hide_banner",
    "-loglevel",
    "error",
    ...args,
  ]);
  if (status === 0) {
    return true;
  } else {
    removeFiles(filesToClear);
    print([stderr.toString()]);
    return false;
  }
};

/**
 * yt-dlp factory function
 * @param args yt-dlp args
 * @param filesToClear files to remove if failed
 * @returns if the operation success
 */
const ytdlp = (args: string[], filesToClear: string[] = []) => {
  const { status, stderr } = spawnSync("yt-dlp", args);
  if (status === 0) {
    return true;
  } else {
    removeFiles(filesToClear);
    print([stderr.toString()]);
    return false;
  }
};

/**
 * MP4-Packager: change video container to mp4
 * @param cmd current cmd (for print usage string)
 */
const mp4Packager = (cmd: string) => {
  const usage = [
    "change video container to mp4",
    `Usage: ${cmd} [input.mkv]`,
    `       ${cmd} \'input.mkv\'`,
  ];
  const [inputFilePath] = getArgs(1, usage);
  checkFileExistOrAbort(inputFilePath);
  const outputFilePath = replaceFileExt(inputFilePath, "mp4");
  const success = ffmpeg(
    [
      "-i",
      inputFilePath,
      "-c:v",
      "copy",
      "-c:a",
      "copy",
      ...(checkFileCodecIsHevc(inputFilePath) ? ["-tag:v", "hvc1"] : []),
      outputFilePath,
    ],
    [outputFilePath],
  );
  if (success) {
    removeFiles([inputFilePath]);
  }
};

/**
 * ASS-Combiner: combile `.cht.ass` to mkv
 * @param cmd current cmd (for usage string)
 */
const assCombiner = (cmd: string) => {
  const usage = [
    "combile .cht.ass to mkv",
    `Usage: ${cmd} [input_dir]`,
    `       ${cmd} \'input\'`,
  ];
  const [targetDir] = getArgs(1, usage);
  const inputVideo = join(targetDir, replaceFileExt(targetDir, "mkv"));
  const inputAss = join(targetDir, replaceFileExt(targetDir, "cht.ass"));
  checkFileExistOrAbort(inputVideo);
  checkFileExistOrAbort(inputAss);
  const outputFile = join(targetDir, replaceFileExt(targetDir, "temp.mkv"));
  const success = ffmpeg(
    [
      "-i",
      inputVideo,
      "-i",
      inputAss,
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
      outputFile,
    ],
    [outputFile],
  );
  if (success) {
    copyFileIfExist(outputFile, inputVideo);
    removeFiles([outputFile]);
  }
};

/**
 * Re-Encoder: re-encode a mp4
 * @param cmd current cmd (for usage string)
 */
const reEncoder = (cmd: string) => {
  const usage = [
    "re-encode a mp4",
    `Usage: ${cmd} [input_file]`,
    `       ${cmd} 'input.mp4'`,
  ];
  const [inputFile] = getArgs(1, usage);
  checkFileExistOrAbort(inputFile);
  const outputFile = replaceFileExt(inputFile, "temp.mp4");
  const success = ffmpeg(
    ["-i", inputFile, "-vcodec", "copy", "-acodec", "copy", outputFile],
    [outputFile],
  );
  if (success) {
    copyFileIfExist(outputFile, inputFile);
    removeFiles([outputFile]);
  }
};

/**
 * Gif Maker
 * @param cmd current cmd (for usage string)
 * @param fps FPS for gif
 * @param width width for gif
 */
const gifMaker = (cmd: string, fps: number, width: number) => {
  const usage = [
    "Gif Maker",
    `Usage: ${cmd} [input_file] [from(hh:mm:ss or sec)] [during(sec)]`,
    `       ${cmd} 'input.mp4' 01:02:08 11.0`,
  ];
  const [inputFile, start, duration] = getArgs(3, usage);
  checkFileExistOrAbort(inputFile);
  const outputFile = `${getDateStrForFile()}_fps${fps}.gif`;
  const success = ffmpeg(
    [
      "-ss",
      start,
      "-t",
      duration,
      "-i",
      inputFile,
      "-filter_complex",
      `[0:v] fps=${fps},scale=w=${width}:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1`,
      outputFile,
    ],
    [outputFile],
  );
  if (success) {
    print([`${outputFile} ${getFileSize(outputFile)}`]);
  }
};

/**
 * YouTube Gif Maker
 * @param cmd current cmd (for usage string)
 * @param fps FPS for gif
 * @param width width for gif
 */
const ytGifMaker = (cmd: string, fps: number, width: number) => {
  const usage = [
    "YouTube Gif Maker",
    `Usage: ${cmd} [video_link] [from(hh:mm:ss or sec)] [during(sec)]`,
    `       ${cmd} 'https://www.youtube.com/watch?v=JoSY6AWKqHs' 00:01:59 2`,
  ];
  const [url, start, duration] = getArgs(3, usage);
  const tempFile = `ytgif_${getDateStrForFile()}.mp4`;
  const successDownload = ytdlp(
    [
      url,
      "-f",
      "mp4",
      "--downloader",
      "ffmpeg",
      "--downloader-args",
      `ffmpeg_i:-ss ${start} -t ${duration}`,
      "-o",
      tempFile,
    ],
    [tempFile],
  );
  if (successDownload) {
    const outputFile = `${getDateStrForFile()}_fps${fps}.gif`;
    const success = ffmpeg(
      [
        "-ss",
        "0",
        "-t",
        duration,
        "-i",
        tempFile,
        "-filter_complex",
        `[0:v] fps=${fps},scale=w=${width}:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1`,
        outputFile,
      ],
      [outputFile],
    );
    if (success) {
      removeFiles([tempFile]);
      print([`${outputFile} ${getFileSize(outputFile)}`]);
    }
  }
};

/**
 * main function
 */
const main = () => {
  const cmd = argv[2];
  switch (cmd) {
    case "ytgif":
      ytGifMaker(cmd, 12, 480);
      break;
    case "ytgifv":
      ytGifMaker(cmd, 24, 480);
      break;
    case "mkgif":
      gifMaker(cmd, 12, 480);
      break;
    case "mkgifv":
      gifMaker(cmd, 24, 480);
      break;
    case "rec":
      reEncoder(cmd);
      break;
    case "rea":
      assCombiner(cmd);
      break;
    case "re4":
      mp4Packager(cmd);
      break;
    default:
      print([
        "vv available commands:",
        "ytgif:  YouTube Gif Maker (12fps)",
        "ytgifv: YouTube Gif Maker (24fps)",
        "mkgif:  Gif Maker (12fps)",
        "mkgifv: Gif Maker (24fps)",
        "rec:    Re-Encoder: re-encode a mp4",
        "rea:    ASS-Combiner: combile .cht.ass to mkv",
        "re4:    MP4-Packager: change video container to mp4",
      ]);
      break;
  }
};

main();
