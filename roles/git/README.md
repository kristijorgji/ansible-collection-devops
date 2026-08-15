# Role: `kristijorgji.devops.git`

GitHub SSH setup, multi-project build-host resolution, shallow clone, and `commitHash`.

---

## Table of contents

- [Task files](#task-files-tasks_from)
- [clone_and_facts](#clone_and_facts)
- [prepare_ssh](#prepare_ssh)
- [resolve_build_hosts](#resolve_build_hosts)
- [prepare_ssh_for_projects](#prepare_ssh_for_projects)
- [cleanup_ssh_for_projects](#cleanup_ssh_for_projects)

---

## Task files (`tasks_from`)

| File                       | Purpose                                                       |
| -------------------------- | ------------------------------------------------------------- |
| `clone_and_facts`          | Stat/wipe stale checkout, shallow clone, set `commitHash`     |
| `prepare_ssh`              | known_hosts, deploy key, `~/.ssh/config.d` Include + template |
| `resolve_build_hosts`      | Unique build hosts for active `projects` / `project`          |
| `prepare_ssh_for_projects` | Loop `prepare_ssh` on each resolved build host                |
| `cleanup_ssh_for_projects` | Remove deploy key from each resolved build host               |

Does not set ECR/docker image facts — consumers add those after clone.

---

## `clone_and_facts`

Required: `projectName`, `gitBranch`, `codePath`, `git_repo_url`, `remote_github_private_key_path`.
Optional: `preserve_code_path_mount`, `become_in_build_machine`, `skip_git`, `env`.

Pass `apply.delegate_to` / `apply.become` so local vs remote build hosts stay intact.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.git
    tasks_from: clone_and_facts
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
      become: "{{ become_in_build_machine }}"
  vars:
    projectName: my_app
    gitBranch: main
    codePath: /path/to/checkout
    git_repo_url: "ssh://git@github.com/org/repo.git"
```

---

## `prepare_ssh`

Required: `local_github_private_key_path`, `remote_github_private_key_path`,
`ssh_config_template_path`, `ssh_config_dest_path`.

The SSH config **template stays in the consumer** (Host alias conventions differ). Pass
`apply.delegate_to` when installing on a remote build host.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.git
    tasks_from: prepare_ssh
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
      become: "{{ become_in_build_machine if delegate_build_to_host != '127.0.0.1' else false }}"
  vars:
    ssh_config_template_path: "{{ environments_dir }}/common/templates/ssh_config.j2"
```

---

## `resolve_build_hosts`

Requires playbook vars `projects` (list) and `project` (`all` or one name). Sets
`_project_git_prepare_hosts` (unique list).

Resolution per `projectName`:

1. `delegate_<projectName>_build_to_host` if defined
2. Else `inventory_hostname` vs `127.0.0.1` from `<projectName>_build_on_remote`
3. Else `delegate_build_to_host` if defined
4. Else `127.0.0.1`

---

## `prepare_ssh_for_projects`

Requires: `projects`, `project`, `environments_dir`, `become_in_build_machine`.
Optional: `ssh_config_template_path` (defaults to
`{{ environments_dir }}/common/templates/ssh_config.j2` when unset).

Skips when `env == "local"` or `skip_git` is defined. Become is off for `127.0.0.1`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.git
    tasks_from: prepare_ssh_for_projects
```

---

## `cleanup_ssh_for_projects`

Re-resolves hosts (safe if facts were cleared), then deletes
`remote_github_private_key_path` on each. Same skip/become rules as prepare.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.git
    tasks_from: cleanup_ssh_for_projects
```
