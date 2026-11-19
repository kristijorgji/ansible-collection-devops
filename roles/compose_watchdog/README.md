# Role: `kristijorgji.devops.compose_watchdog`

Cron watchdog that runs `docker compose up -d` (or `docker-compose`) for listed
project directories. Optional executable hooks run first. `state: absent` removes
the cron entry and the script.

---

## Table of contents

- [Task files](#task-files)
- [`install`](#install)
- [`recreate`](#recreate)

---

## Task files

| File       | Purpose                                             |
| ---------- | --------------------------------------------------- |
| `install`  | Script, log/hooks dirs, and cron (or remove them)   |
| `recreate` | `up -d --force-recreate` for paths that have a file |

`main.yml` imports `install`. Call `tasks_from: recreate` from post_tasks.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `install`

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.compose_watchdog
    tasks_from: install
    apply:
      tags: docker-watchdog
  vars:
    compose_watchdog_paths:
      - /opt/stack
    compose_watchdog_compose_command: docker-compose
  tags: docker-watchdog
```

| Variable                           | Default                                     | Meaning                                    |
| ---------------------------------- | ------------------------------------------- | ------------------------------------------ |
| `compose_watchdog_state`           | `present`                                   | `present` or `absent`.                     |
| `compose_watchdog_paths`           | `[]`                                        | Project directories passed to the script.  |
| `compose_watchdog_schedule`        | `*/5 * * * *`                               | Five-field cron schedule.                  |
| `compose_watchdog_log_dir`         | `/var/log/docker-watchdog`                  | Log directory (arg 1 to the script).       |
| `compose_watchdog_hooks_dir`       | `/etc/docker-watchdog.d`                    | Executable `*.sh` drop-ins.                |
| `compose_watchdog_script_path`     | `/usr/local/bin/docker-compose-up.sh`       | Installed script path.                     |
| `compose_watchdog_cron_name`       | `Ansible: docker-compose up (watchdog)`     | Cron unique name (updated in place).       |
| `compose_watchdog_cron_user`       | `root`                                      | Cron user.                                 |
| `compose_watchdog_compose_command` | `docker compose`                            | Command used for `up -d`.                  |
| `compose_watchdog_up_timeout`      | `60`                                        | Seconds; `0` disables `timeout`.           |
| `compose_watchdog_compose_files`   | `compose.yaml` / `yml` / `docker-compose.*` | Filenames that mean "this dir is a stack". |

`DOCKER_WATCHDOG_HOOKS_DIR` still overrides the hooks directory at runtime.
`WATCHDOG_LOG_DIR` is exported to hooks.

---

## `recreate`

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.compose_watchdog
    tasks_from: recreate
    apply:
      tags: docker-recreate
  tags: docker-recreate
```

Runs `<compose_command> up -d --force-recreate` in each `compose_watchdog_recreate_paths`
directory that contains a compose file. Default recreate paths equal `compose_watchdog_paths`.
