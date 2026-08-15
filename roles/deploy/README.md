# Role: `kristijorgji.devops.deploy`

Deploy skip gate (`check_needed`) and commit marker (`write_marker`).

---

## Table of contents

- [Task files](#task-files)
- [`check_needed`](#check_needed)
- [`write_marker`](#write_marker)

---

## Task files

| File           | Purpose                                           |
| -------------- | ------------------------------------------------- |
| `check_needed` | Compare remote HEAD + optional lockfile to marker |
| `write_marker` | Write `.ansible-deploy-commit` after transfer     |

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `check_needed`

Required: `deploy_check_git_repo_url`, `deploy_check_git_branch`, `deploy_check_server_code_path`.
Optional: `deploy_check_build_code_path`, `deploy_check_build_delegate`, `deploy_check_lockfile`,
`deploy_check_fact_name`, `deploy_check_label`, `force_deploy`, `projectName`.

Sets `deploy_build_needed` (or `deploy_check_fact_name`). Build-host lockfile stat uses
`become_in_build_machine`; never become on localhost.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.deploy
    tasks_from: check_needed
  vars:
    projectName: my_app
    deploy_check_git_repo_url: "ssh://git@github.com/org/repo.git"
    deploy_check_git_branch: main
    deploy_check_server_code_path: /var/www/app
```

---

## `write_marker`

Required: `projectName`, `commitHash`, `serverCodePath`.
Optional: `deploy_commit_marker_dir` (default `serverCodePath`).

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.deploy
    tasks_from: write_marker
  vars:
    projectName: my_app
    commitHash: "{{ commitHash }}"
    serverCodePath: /var/www/app
```
