# Role: `kristijorgji.devops.deploy`

Deploy skip gate and commit marker.

## Task files (`tasks_from`)

| File            | Purpose                                              |
| --------------- | ---------------------------------------------------- |
| `check_needed`  | Compare remote HEAD + optional lockfile to marker    |
| `write_marker`  | Write `.ansible-deploy-commit` after build/transfer  |

## `check_needed` variables

Required: `deploy_check_git_repo_url`, `deploy_check_git_branch`, `deploy_check_server_code_path`.
Optional: `deploy_check_build_code_path`, `deploy_check_build_delegate`, `deploy_check_lockfile`,
`deploy_check_fact_name`, `deploy_check_label`, `force_deploy`.
Build-host lockfile stat uses `become_in_build_machine`; never become on localhost.

## `write_marker` variables

Required: `projectName`, `commitHash`, `serverCodePath`.
Optional: `deploy_commit_marker_dir` (default `serverCodePath`).
