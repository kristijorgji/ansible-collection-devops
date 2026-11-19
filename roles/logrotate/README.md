# Role: `kristijorgji.devops.logrotate`

Render one `/etc/logrotate.d/<name>` file per entry. All paths in an entry share
one block. `logrotate -d` must not print a line starting with `error`, which
rejects overlapping globs that would skip the whole file.

Defaults include `su root root` so files directly under Ubuntu `/var/log`
(group-writable `adm`) still rotate. Override `options.su` per entry if needed.

---

## Table of contents

- [Task files](#task-files)
- [`install`](#install)

---

## Task files

| File      | Purpose                                        |
| --------- | ---------------------------------------------- |
| `install` | Install the package and render or remove files |

`main.yml` imports `install`.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `install`

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.logrotate
    tasks_from: install
    apply:
      tags: logrotate
  vars:
    logrotate_entries:
      - name: app-logs
        paths:
          - /var/log/app/*.log
        options:
          copytruncate: true
          rotate: 14
  tags: logrotate
```

Sharedscripts example:

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.logrotate
    tasks_from: install
  vars:
    logrotate_entries:
      - name: proxy-access
        paths:
          - /var/log/proxy/*.log
        options:
          sharedscripts: true
          maxsize: 50M
          postrotate: "kill -USR1 $(cat /run/nginx.pid)"
```

| Variable             | Default                                                               | Meaning                                                                     |
| -------------------- | --------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `logrotate_conf_dir` | `/etc/logrotate.d`                                                    | Destination directory.                                                      |
| `logrotate_defaults` | daily / rotate 14 / compress / delaycompress / missingok / notifempty | Base options, including `su root root`.                                     |
| `logrotate_entries`  | `[]`                                                                  | `{name, paths, state, comment, options}`. `state: absent` removes the file. |

`options` keys: frequency, rotate, compress, delaycompress, missingok, notifempty,
copytruncate, sharedscripts, maxsize, minsize, size, dateext, create, su,
prerotate, postrotate.
