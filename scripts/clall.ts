type GitHubAPISchema = GitHubRepoSchema[];

interface GitHubRepoSchema {
  id: number;
  node_id: string;
  name: string;
  full_name: string;
  license: null | GitHubLicenseSchema;
  organization?: null | GitHubUserSchema;
  forks: number;
  permissions?: {
    admin: boolean;
    pull: boolean;
    triage?: boolean;
    push: boolean;
    maintain?: boolean;
  };
  owner: GitHubUserSchema;
  private: boolean;
  html_url: string;
  description: string | null;
  fork: boolean;
  url: string;
  archive_url: string;
  assignees_url: string;
  blobs_url: string;
  branches_url: string;
  collaborators_url: string;
  comments_url: string;
  commits_url: string;
  compare_url: string;
  contents_url: string;
  contributors_url: string;
  deployments_url: string;
  downloads_url: string;
  events_url: string;
  forks_url: string;
  git_commits_url: string;
  git_refs_url: string;
  git_tags_url: string;
  git_url: string;
  issue_comment_url: string;
  issue_events_url: string;
  issues_url: string;
  keys_url: string;
  labels_url: string;
  languages_url: string;
  merges_url: string;
  milestones_url: string;
  notifications_url: string;
  pulls_url: string;
  releases_url: string;
  ssh_url: string;
  stargazers_url: string;
  statuses_url: string;
  subscribers_url: string;
  subscription_url: string;
  tags_url: string;
  teams_url: string;
  trees_url: string;
  clone_url: string;
  mirror_url: string | null;
  hooks_url: string;
  svn_url: string;
  homepage: string | null;
  language: string | null;
  forks_count: number;
  stargazers_count: number;
  watchers_count: number;
  size: number;
  default_branch: string;
  open_issues_count: number;
  is_template?: boolean;
  topics?: string[];
  has_issues: boolean;
  has_projects: boolean;
  has_wiki: boolean;
  has_pages: boolean;
  has_downloads: boolean;
  has_discussions?: boolean;
  archived: boolean;
  disabled: boolean;
  visibility?: string;
  pushed_at: string | null;
  created_at: string | null;
  updated_at: string | null;
  allow_rebase_merge?: boolean;
  template_repository?: {
    id?: number;
    node_id?: string;
    name?: string;
    full_name?: string;
    owner?: {
      login?: string;
      id?: number;
      node_id?: string;
      avatar_url?: string;
      gravatar_id?: string;
      url?: string;
      html_url?: string;
      followers_url?: string;
      following_url?: string;
      gists_url?: string;
      starred_url?: string;
      subscriptions_url?: string;
      organizations_url?: string;
      repos_url?: string;
      events_url?: string;
      received_events_url?: string;
      type?: string;
      site_admin?: boolean;
    };
    private?: boolean;
    html_url?: string;
    description?: string;
    fork?: boolean;
    url?: string;
    archive_url?: string;
    assignees_url?: string;
    blobs_url?: string;
    branches_url?: string;
    collaborators_url?: string;
    comments_url?: string;
    commits_url?: string;
    compare_url?: string;
    contents_url?: string;
    contributors_url?: string;
    deployments_url?: string;
    downloads_url?: string;
    events_url?: string;
    forks_url?: string;
    git_commits_url?: string;
    git_refs_url?: string;
    git_tags_url?: string;
    git_url?: string;
    issue_comment_url?: string;
    issue_events_url?: string;
    issues_url?: string;
    keys_url?: string;
    labels_url?: string;
    languages_url?: string;
    merges_url?: string;
    milestones_url?: string;
    notifications_url?: string;
    pulls_url?: string;
    releases_url?: string;
    ssh_url?: string;
    stargazers_url?: string;
    statuses_url?: string;
    subscribers_url?: string;
    subscription_url?: string;
    tags_url?: string;
    teams_url?: string;
    trees_url?: string;
    clone_url?: string;
    mirror_url?: string;
    hooks_url?: string;
    svn_url?: string;
    homepage?: string;
    language?: string;
    forks_count?: number;
    stargazers_count?: number;
    watchers_count?: number;
    size?: number;
    default_branch?: string;
    open_issues_count?: number;
    is_template?: boolean;
    topics?: string[];
    has_issues?: boolean;
    has_projects?: boolean;
    has_wiki?: boolean;
    has_pages?: boolean;
    has_downloads?: boolean;
    archived?: boolean;
    disabled?: boolean;
    visibility?: string;
    pushed_at?: string;
    created_at?: string;
    updated_at?: string;
    permissions?: {
      admin?: boolean;
      maintain?: boolean;
      push?: boolean;
      triage?: boolean;
      pull?: boolean;
    };
    allow_rebase_merge?: boolean;
    temp_clone_token?: string;
    allow_squash_merge?: boolean;
    allow_auto_merge?: boolean;
    delete_branch_on_merge?: boolean;
    allow_update_branch?: boolean;
    use_squash_pr_title_as_default?: boolean;
    squash_merge_commit_title?: "PR_TITLE" | "COMMIT_OR_PR_TITLE";
    squash_merge_commit_message?: "PR_BODY" | "COMMIT_MESSAGES" | "BLANK";
    merge_commit_title?: "PR_TITLE" | "MERGE_MESSAGE";
    merge_commit_message?: "PR_BODY" | "PR_TITLE" | "BLANK";
    allow_merge_commit?: boolean;
    subscribers_count?: number;
    network_count?: number;
  } | null;
  temp_clone_token?: string;
  allow_squash_merge?: boolean;
  allow_auto_merge?: boolean;
  delete_branch_on_merge?: boolean;
  allow_update_branch?: boolean;
  use_squash_pr_title_as_default?: boolean;
  squash_merge_commit_title?: "PR_TITLE" | "COMMIT_OR_PR_TITLE";
  squash_merge_commit_message?: "PR_BODY" | "COMMIT_MESSAGES" | "BLANK";
  merge_commit_title?: "PR_TITLE" | "MERGE_MESSAGE";
  merge_commit_message?: "PR_BODY" | "PR_TITLE" | "BLANK";
  allow_merge_commit?: boolean;
  allow_forking?: boolean;
  web_commit_signoff_required?: boolean;
  subscribers_count?: number;
  network_count?: number;
  open_issues: number;
  watchers: number;
  master_branch?: string;
  starred_at?: string;
  anonymous_access_enabled?: boolean;
}

interface GitHubLicenseSchema {
  key: string;
  name: string;
  url: string | null;
  spdx_id: string | null;
  node_id: string;
  html_url?: string;
}

interface GitHubUserSchema {
  name?: string | null;
  email?: string | null;
  login: string;
  id: number;
  node_id: string;
  avatar_url: string;
  gravatar_id: string | null;
  url: string;
  html_url: string;
  followers_url: string;
  following_url: string;
  gists_url: string;
  starred_url: string;
  subscriptions_url: string;
  organizations_url: string;
  repos_url: string;
  events_url: string;
  received_events_url: string;
  type: string;
  site_admin: boolean;
  starred_at?: string;
}

let GLOBAL_FINISHED_COUNT = 0;
let GLOBAL_ALL_COUNT = 0;

/**
 * Logger
 * @param {string} c contnt
 * @param {boolean} n with newline, default: `false`
 */
const logger = async (c: string, n: boolean = false) => {
  await Bun.write(Bun.stdout, `${c}${n ? "\n" : ""}`);
};

/**
 * Get Repository url list
 * @param {string} t GitHub Access Token
 *
 * GitHub docs here: https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#list-repositories-for-the-authenticated-user
 */
const getReopList = async (t: string) => {
  const res = await fetch(
    "https://api.github.com/user/repos?type=owner&per_page=100",
    {
      method: "GET",
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${t}`,
        "X-GitHub-Api-Version": "2022-11-28",
      },
    },
  );
  const d = await res.json<GitHubAPISchema>();
  GLOBAL_ALL_COUNT = d.length;
  return d.map((r) => r.ssh_url);
};

/**
 * Clone Repositories
 * @param {string[]} rr Repository list
 */
const cloneRepos = async (rr: string[]) => {
  await logger(`remote: ${GLOBAL_ALL_COUNT} repositories to clone...`, true);
  await Promise.all(
    rr.map(async (r) => {
      const d = r.split("/").pop()?.replaceAll(".git", "");
      const p = Bun.spawn({
        cmd: ["git", "clone", "-q", r],
        stdout: "pipe",
        stderr: "pipe",
        onExit: async (pp, exitCode) => {
          if (exitCode === 0) {
            GLOBAL_FINISHED_COUNT += 1;
            await logger(
              `complete: \x1b[1m${d}\x1b[0m (${GLOBAL_FINISHED_COUNT}/${GLOBAL_ALL_COUNT})`,
              true,
            );
          } else {
            const e = await new Response(
              pp.stderr as ReadableStream<Uint8Array>,
            ).text();
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
