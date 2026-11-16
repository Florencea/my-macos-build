import fs from "node:fs/promises";
import type { CommandContext } from "./context.ts";

/**
 * Checks whether `filePath` exists and is a regular file.
 */
export async function isFile(
  filePath: string,
  fsPort: CommandContext["fs"] = fs,
): Promise<boolean> {
  try {
    const stats = await fsPort.stat(filePath);
    return stats.isFile();
  } catch {
    return false;
  }
}

/**
 * Checks whether `dirPath` exists and is a directory.
 */
export async function isDirectory(
  dirPath: string,
  fsPort: CommandContext["fs"] = fs,
): Promise<boolean> {
  try {
    const stats = await fsPort.stat(dirPath);
    return stats.isDirectory();
  } catch {
    return false;
  }
}

/**
 * Checks whether `targetPath` exists on disk.
 */
export async function pathExists(
  targetPath: string,
  fsPort: CommandContext["fs"] = fs,
): Promise<boolean> {
  try {
    await fsPort.stat(targetPath);
    return true;
  } catch {
    return false;
  }
}
