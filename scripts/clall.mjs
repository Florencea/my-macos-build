import { spawn } from "node:child_process";
import { argv, stdout } from "node:process";

/**
 * @typedef {{ id: number; node_id: string; name: string; full_name: string; license: null | GitHubLicenseSchema; organization?: null | GitHubUserSchema; forks: number; permissions?: {   admin: boolean;   pull: boolean;   triage?: boolean;   push: boolean;   maintain?: boolean; }; owner: GitHubUserSchema; private: boolean; html_url: string; description: string | null; fork: boolean; url: string; archive_url: string; assignees_url: string; blobs_url: string; branches_url: string; collaborators_url: string; comments_url: string; commits_url: string; compare_url: string; contents_url: string; contributors_url: string; deployments_url: string; downloads_url: string; events_url: string; forks_url: string; git_commits_url: string; git_refs_url: string; git_tags_url: string; git_url: string; issue_comment_url: string; issue_events_url: string; issues_url: string; keys_url: string; labels_url: string; languages_url: string; merges_url: string; milestones_url: string; notifications_url: string; pulls_url: string; releases_url: string; ssh_url: string; stargazers_url: string; statuses_url: string; subscribers_url: string; subscription_url: string; tags_url: string; teams_url: string; trees_url: string; clone_url: string; mirror_url: string | null; hooks_url: string; svn_url: string; homepage: string | null; language: string | null; forks_count: number; stargazers_count: number; watchers_count: number; size: number; default_branch: string; open_issues_count: number; is_template?: boolean; topics?: string[]; has_issues: boolean; has_projects: boolean; has_wiki: boolean; has_pages: boolean; has_downloads: boolean; has_discussions?: boolean; archived: boolean; disabled: boolean; visibility?: string; pushed_at: string | null; created_at: string | null; updated_at: string | null; allow_rebase_merge?: boolean; template_repository?: {   id?: number;   node_id?: string;   name?: string;   full_name?: string;   owner?: {     login?: string;     id?: number;     node_id?: string;     avatar_url?: string;     gravatar_id?: string;     url?: string;     html_url?: string;     followers_url?: string;     following_url?: string;     gists_url?: string;     starred_url?: string;     subscriptions_url?: string;     organizations_url?: string;     repos_url?: string;     events_url?: string;     received_events_url?: string;     type?: string;     site_admin?: boolean;   };   private?: boolean;   html_url?: string;   description?: string;   fork?: boolean;   url?: string;   archive_url?: string;   assignees_url?: string;   blobs_url?: string;   branches_url?: string;   collaborators_url?: string;   comments_url?: string;   commits_url?: string;   compare_url?: string;   contents_url?: string;   contributors_url?: string;   deployments_url?: string;   downloads_url?: string;   events_url?: string;   forks_url?: string;   git_commits_url?: string;   git_refs_url?: string;   git_tags_url?: string;   git_url?: string;   issue_comment_url?: string;   issue_events_url?: string;   issues_url?: string;   keys_url?: string;   labels_url?: string;   languages_url?: string;   merges_url?: string;   milestones_url?: string;   notifications_url?: string;   pulls_url?: string;   releases_url?: string;   ssh_url?: string;   stargazers_url?: string;   statuses_url?: string;   subscribers_url?: string;   subscription_url?: string;   tags_url?: string;   teams_url?: string;   trees_url?: string;   clone_url?: string;   mirror_url?: string;   hooks_url?: string;   svn_url?: string;   homepage?: string;   language?: string;   forks_count?: number;   stargazers_count?: number;   watchers_count?: number;   size?: number;   default_branch?: string;   open_issues_count?: number;   is_template?: boolean;   topics?: string[];   has_issues?: boolean;   has_projects?: boolean;   has_wiki?: boolean;   has_pages?: boolean;   has_downloads?: boolean;   archived?: boolean;   disabled?: boolean;   visibility?: string;   pushed_at?: string;   created_at?: string;   updated_at?: string;   permissions?: {     admin?: boolean;     maintain?: boolean;     push?: boolean;     triage?: boolean;     pull?: boolean;   };   allow_rebase_merge?: boolean;   temp_clone_token?: string;   allow_squash_merge?: boolean;   allow_auto_merge?: boolean;   delete_branch_on_merge?: boolean;   allow_update_branch?: boolean;   use_squash_pr_title_as_default?: boolean;   squash_merge_commit_title?: "PR_TITLE" | "COMMIT_OR_PR_TITLE";   squash_merge_commit_message?: "PR_BODY" | "COMMIT_MESSAGES" | "BLANK";   merge_commit_title?: "PR_TITLE" | "MERGE_MESSAGE";   merge_commit_message?: "PR_BODY" | "PR_TITLE" | "BLANK";   allow_merge_commit?: boolean;   subscribers_count?: number;   network_count?: number; } | null; temp_clone_token?: string; allow_squash_merge?: boolean; allow_auto_merge?: boolean; delete_branch_on_merge?: boolean; allow_update_branch?: boolean; use_squash_pr_title_as_default?: boolean; squash_merge_commit_title?: "PR_TITLE" | "COMMIT_OR_PR_TITLE"; squash_merge_commit_message?: "PR_BODY" | "COMMIT_MESSAGES" | "BLANK"; merge_commit_title?: "PR_TITLE" | "MERGE_MESSAGE"; merge_commit_message?: "PR_BODY" | "PR_TITLE" | "BLANK"; allow_merge_commit?: boolean; allow_forking?: boolean; web_commit_signoff_required?: boolean; subscribers_count?: number; network_count?: number; open_issues: number; watchers: number; master_branch?: string; starred_at?: string; anonymous_access_enabled?: boolean; }} GitHubRepoSchema
 */

/**
 * @typedef {{ key: string; name: string; url: string | null; spdx_id: string | null; node_id: string; html_url?: string; }} GitHubLicenseSchema
 */

/**
 * @typedef {{ name?: string | null; email?: string | null; login: string; id: number; node_id: string; avatar_url: string; gravatar_id: string | null; url: string; html_url: string; followers_url: string; following_url: string; gists_url: string; starred_url: string; subscriptions_url: string; organizations_url: string; repos_url: string; events_url: string; received_events_url: string; type: string; site_admin: boolean; starred_at?: string; }} GitHubUserSchema
 */

let GLOBAL_FINISHED_COUNT = 0;
let GLOBAL_ALL_COUNT = 0;

/**
 * Single line logger
 * @param {string} content content to print
 * @param {boolean} withNewline print `\n` at content end, default: `false`
 */
const print = (content, withNewline = false) => {
  stdout.write(`${content}${withNewline ? "\n" : ""}`);
};

/**
 * Get Repository clone urls and names
 * @param {string} token GitHub Access Token
 * @returns Array<[repo name, repo ssh_url]>
 *
 * GitHub docs here: https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#list-repositories-for-the-authenticated-user
 */
const getCloneUrls = async (token) => {
  const response = await fetch(
    "https://api.github.com/user/repos?type=owner&per_page=100",
    {
      method: "GET",
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${token}`,
        "X-GitHub-Api-Version": "2022-11-28",
      },
    },
  );
  /**
   * @type {GitHubRepoSchema[]}
   */
  const repositories = await response.json();
  GLOBAL_ALL_COUNT = repositories.length;
  return repositories.map((repo) => [repo.name, repo.ssh_url]);
};

/**
 * Clone Repositories
 * @param {string[][]} repoInfos Array<[repo name, repo ssh_url]>
 */
const cloneRepos = (repoInfos) => {
  print(`remote: ${GLOBAL_ALL_COUNT} repositories to clone...`, true);
  repoInfos.map((repoInfo) => {
    const [repoName, cloneUrl] = repoInfo;
    const p = spawn("git", ["clone", "--progress", cloneUrl], {});
    p.stderr.on("data", (data) => {
      /**
       * @type {string}
       */
      const dataText = data.toString();
      if (
        dataText.includes("處理 delta 中: 100%") &&
        dataText.includes("完成")
      ) {
        GLOBAL_FINISHED_COUNT += 1;
        print(
          `complete: \x1b[1m${repoName}\x1b[0m (${GLOBAL_FINISHED_COUNT}/${GLOBAL_ALL_COUNT})`,
          true,
        );
      }
    });
  });
};

/**
 * main function
 */
const main = async () => {
  const repoInfos = await getCloneUrls(argv[2]);
  cloneRepos(repoInfos);
};

main();
