# Role: `kristijorgji.devops.transfer`

Rsync helpers for pushing build artefacts and preparing server paths.

---

## Table of contents

- [Task files](#task-files)
- [Variables](#variables)
- [Notes](#notes)

---

## Task files

| File                    | Purpose                                          |
| ----------------------- | ------------------------------------------------ |
| `rsync_local_to_server` | Incremental push via `ansible.posix.synchronize` |
| `rsync_paths_to_server` | Partial monorepo path list + commit marker       |
| `prune_and_rsync`       | Optional prune shell, full-tree rsync, marker    |
| `wipe_dir_keep_inode`   | Clear dir contents; keep bind-mount inode        |

---

## Variables

| Variable             | Default           | Notes                                           |
| -------------------- | ----------------- | ----------------------------------------------- |
| `projectName`        | —                 | Required                                        |
| `codePath`           | —                 | Local source root (used if `rsync_src` omitted) |
| `serverCodePath`     | —                 | Remote destination root                         |
| `rsync_src`          | `{{ codePath }}/` | Local path to sync                              |
| `rsync_dest_suffix`  | `""`              | Appended to `serverCodePath`                    |
| `rsync_exclude`      | `['.git']`        | Passed as `--exclude=`                          |
| `rsync_run_transfer` | `true`            | Skip when false                                 |

`rsync_paths_to_server` also uses `monorepo_local_code_path` plus `monorepo_sync_src` or
`monorepo_sync_paths`. `prune_and_rsync` may use prune-related vars and
`delegate_build_to_host` / `become_in_build_machine` for prune on the build host.
See task file headers for required vars.

---

## Notes

Requires the `ansible.posix` collection. Do **not** `delegate_to: 127.0.0.1` on synchronize.

Relative `ansible_ssh_private_key_file` paths are absolutized against `PWD` (ansible-playbook
cwd) before passing to `ssh -i`, because synchronize disables SSH ControlMaster.
