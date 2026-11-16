import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vite-plus/test";
import { runShellVerification } from "../verify-shell.ts";

describe("verify-shell", () => {
  it("passes on valid shell files and detects syntax errors", async () => {
    const tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-verify-shell-"));
    try {
      await fs.mkdir(path.join(tempRoot, "scripts"), { recursive: true });
      await fs.mkdir(path.join(tempRoot, "configs", "zsh", "completions"), { recursive: true });
      await fs.mkdir(path.join(tempRoot, "configs", "bash"), { recursive: true });
      await fs.mkdir(path.join(tempRoot, "configs", "git", "hooks"), { recursive: true });
      await fs.mkdir(path.join(tempRoot, "cli", "bin"), { recursive: true });

      await fs.writeFile(
        path.join(tempRoot, "scripts", "install.sh"),
        "#!/bin/zsh\necho ok\n",
        "utf8",
      );
      await fs.writeFile(path.join(tempRoot, "configs", "zsh", "zshenv"), "export FOO=1\n", "utf8");
      await fs.writeFile(
        path.join(tempRoot, "configs", "zsh", "zprofile"),
        "export BAR=2\n",
        "utf8",
      );
      await fs.writeFile(path.join(tempRoot, "configs", "zsh", "zshrc"), "setopt promptsubst\n");
      await fs.writeFile(
        path.join(tempRoot, "configs", "bash", "bash_profile"),
        "echo bash_profile\n",
      );
      await fs.writeFile(path.join(tempRoot, "configs", "bash", "bashrc"), "echo bashrc\n");
      await fs.writeFile(
        path.join(tempRoot, "configs", "git", "hooks", "pre-commit.sh"),
        "#!/usr/bin/env bash\nexit 0\n",
      );

      const okRes = await runShellVerification(tempRoot, false);
      expect(okRes.totalFiles).toBe(7);
      expect(okRes.failures).toEqual([]);

      await fs.writeFile(
        path.join(tempRoot, "configs", "bash", "bashrc"),
        "if [ true ]; then\necho broken\n",
      );
      const badRes = await runShellVerification(tempRoot, false);
      expect(badRes.failures.length).toBeGreaterThan(0);
    } finally {
      await fs.rm(tempRoot, { recursive: true, force: true });
    }
  });
});
