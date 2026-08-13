# Role: `kristijorgji.devops.transfer`

## Task files

| File                    | Purpose                                          |
| ----------------------- | ------------------------------------------------ |
| `rsync_local_to_server` | Incremental push via `ansible.posix.synchronize` |

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

Requires the `ansible.posix` collection. Do **not** `delegate_to: 127.0.0.1` on synchronize.

Relative `ansible_ssh_private_key_file` paths are absolutized against `PWD` (ansible-playbook
cwd) before passing to `ssh -i`, because synchronize disables SSH ControlMaster.
