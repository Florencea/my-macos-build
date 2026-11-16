import type { CommandContext } from "./context.ts";

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"] as const;
const FRAME_INTERVAL_MS = 80;

export async function withSpinner<T>(
  ctx: Pick<CommandContext, "isTty" | "stderr" | "onSignalCleanup">,
  message: string,
  task: () => Promise<T>,
): Promise<T> {
  if (!ctx.isTty) {
    ctx.stderr(`  ${message}...\n`);
    return await task();
  }

  let frameIdx = 0;
  let restored = false;

  const restoreCursor = (): void => {
    if (restored) {
      return;
    }
    restored = true;
    ctx.stderr("\r\x1b[K\x1b[?25h");
  };

  const unregisterSignal = ctx.onSignalCleanup(restoreCursor);

  ctx.stderr(`\x1b[?25l\r  ${SPINNER_FRAMES[0]} ${message}...`);
  const timer = setInterval(() => {
    frameIdx = (frameIdx + 1) % SPINNER_FRAMES.length;
    const frame = SPINNER_FRAMES[frameIdx] ?? SPINNER_FRAMES[0];
    ctx.stderr(`\r  ${frame} ${message}...`);
  }, FRAME_INTERVAL_MS);

  try {
    return await task();
  } finally {
    clearInterval(timer);
    unregisterSignal();
    restoreCursor();
  }
}
