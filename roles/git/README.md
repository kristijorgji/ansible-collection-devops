# Role: `kristijorgji.devops.git`

Shallow clone and `commitHash` fact.

## Task files (`tasks_from`)

| File              | Purpose                                      |
| ----------------- | -------------------------------------------- |
| `clone_and_facts` | Stat/wipe stale checkout, clone, set commit  |

## Variables

Required: `projectName`, `gitBranch`, `codePath`, `git_repo_url`, `remote_github_private_key_path`.
Optional: `preserve_code_path_mount`, `become_in_build_machine`, `skip_git`, `env`.

Pass `apply.delegate_to` / `apply.become` from the caller so local vs remote build hosts stay intact.
Does not set ECR/docker image facts — consumers add those after clone.
