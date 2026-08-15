# Role: `kristijorgji.devops.transfer`

Rsync helpers for pushing build artefacts and preparing server paths.

---

## Table of contents

- [Task files](#task-files)
- [`rsync_local_to_server`](#rsync_local_to_server)
- [`rsync_paths_to_server`](#rsync_paths_to_server)
- [`prune_and_rsync`](#prune_and_rsync)
- [`wipe_dir_keep_inode`](#wipe_dir_keep_inode)

---

## Task files

| File                    | Purpose                                          |
| ----------------------- | ------------------------------------------------ |
| `rsync_local_to_server` | Incremental push via `ansible.posix.synchronize` |
| `rsync_paths_to_server` | Partial monorepo path list + commit marker       |
| `prune_and_rsync`       | Optional prune shell, full-tree rsync, marker    |
| `wipe_dir_keep_inode`   | Clear dir contents; keep bind-mount inode        |

Requires `ansible.posix`. Do not `delegate_to: 127.0.0.1` on synchronize.

Relative `ansible_ssh_private_key_file` paths are absolutized against `PWD` before
`ssh -i` (synchronize disables SSH ControlMaster).

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `rsync_local_to_server`

Required: `projectName`, `codePath`, `serverCodePath`.
Optional: `rsync_src` (default `{{ codePath }}/`), `rsync_dest_suffix`,
`rsync_exclude` (default `['.git']`), `rsync_run_transfer` (default `true`).

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.transfer
    tasks_from: rsync_local_to_server
  vars:
    projectName: my_app
    codePath: /path/to/app
    serverCodePath: /var/www/app
    rsync_src: /path/to/app/build/
    rsync_dest_suffix: /build
```

---

## `rsync_paths_to_server`

Required: `projectName`, `monorepo_local_code_path`, `serverCodePath`, and either
`monorepo_sync_src` or `monorepo_sync_paths`.
Optional: `monorepo_deploy_marker_path`, `commitHash` (for the marker).

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.transfer
    tasks_from: rsync_paths_to_server
  vars:
    projectName: my_app
    monorepo_local_code_path: /path/to/mono
    serverCodePath: /var/www/app
    monorepo_sync_paths:
      - apps/web
      - packages/ui
```

---

## `prune_and_rsync`

Required: `projectName`, `codePath`, `serverCodePath`, `delegate_build_to_host`.
Optional: `pnpm_prune_shell`, `pnpm_run_prune`, `pnpm_run_transfer`,
`pnpm_rsync_exclude_extra`, `become_in_build_machine`, `commitHash`.

Callers set `delegate_build_to_host: 127.0.0.1` — full transfer is local-build only.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.transfer
    tasks_from: prune_and_rsync
  vars:
    projectName: my_app
    codePath: /path/to/app
    serverCodePath: /var/www/app
    delegate_build_to_host: 127.0.0.1
    pnpm_prune_shell: "rm -rf .next/cache"
```

---

## `wipe_dir_keep_inode`

Required: `projectName`, `serverCodePath`.

Clears contents without deleting the directory inode (safe for bind mounts).

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.transfer
    tasks_from: wipe_dir_keep_inode
    apply:
      become: "{{ become_in_build_machine | default(false) }}"
  vars:
    projectName: my_app
    serverCodePath: /src/my_app
```
