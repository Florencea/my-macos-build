let GLOBAL_FINISHED_COUNT = 0;
let GLOBAL_ALL_COUNT = 0;

/**
 * Logger
 * @param {string} c contnt
 * @param {boolean} n with newline, default: `false`
 */
const logger = async (c, n = false) => {
  await Bun.write(Bun.stdout, `${c}${n ? "\n" : ""}`);
};

/**
 * Get Repository url list
 * @param {string} t GitHub Access Token
 *
 * GitHub docs here: https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#list-repositories-for-the-authenticated-user
 */
const getReopList = async (t) => {
  const res = await fetch(
    new Request({
      method: "GET",
      url: "https://api.github.com/user/repos",
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${t}`,
        "X-GitHub-Api-Version": "2022-11-28",
      },
      searchParams: new URLSearchParams([
        ["type", "owner"],
        ["per_page", "100"],
      ]),
    }),
  );
  const d = await res.json();
  GLOBAL_ALL_COUNT = d.length;
  return d.map((r) => r.ssh_url);
};

/**
 * Clone Repositories
 * @param {string[]} rr Repository list
 */
const cloneRepos = async (rr) => {
  await logger(`remote: ${GLOBAL_ALL_COUNT} repositories to clone...`, true);
  await Promise.all(
    rr.map(async (r) => {
      const d = r.split("/").pop().replaceAll(".git", "");
      const p = await Bun.spawn({
        cmd: ["git", "clone", "-q", r],
        stdout: "pipe",
        stderr: "pipe",
        onExit: async (pp, exitCode, signalCode, error) => {
          if (exitCode === 0) {
            GLOBAL_FINISHED_COUNT += 1;
            await logger(
              `complete: \x1b[1m${d}\x1b[0m (${GLOBAL_FINISHED_COUNT}/${GLOBAL_ALL_COUNT})`,
              true,
            );
          } else {
            const e = await new Response(pp.stderr).text();
            await logger(e);
          }
        },
      });
      await p.exited;
    }),
  );
};

/**
 * main function
 */
const main = async () => {
  const rr = await getReopList(Bun.argv[2]);
  await cloneRepos(rr);
};

main();
