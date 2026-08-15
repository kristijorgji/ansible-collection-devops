# Role: `kristijorgji.devops.ssm`

Load optional `ssm_cache.yml` and fetch missing Parameter Store values into host vars.

---

## Table of contents

- [Task files](#task-files)
- [`include_cache`](#include_cache)
- [`read_from_definitions`](#read_from_definitions)

---

## Task files

| File                    | Purpose                                                          |
| ----------------------- | ---------------------------------------------------------------- |
| `include_cache`         | Include `environments/<env>/ssm_cache.yml` when the file exists  |
| `read_from_definitions` | `lookup('amazon.aws.aws_ssm')` for keys in `ssm_vars` not cached |

Requires the `amazon.aws` collection and controller `boto3`. On macOS export
`OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` or the lookup worker dies after `fork()`.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `include_cache`

Required: `environments_dir`, `env`.
Optional: `ssm_cache_path` (default `{{ environments_dir }}/{{ env }}/ssm_cache.yml`).

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.ssm
    tasks_from: include_cache
    apply:
      tags: always
  tags: always
```

---

## `read_from_definitions`

Required: `ssm_vars` (dict of fact name → SSM path), `ssm_reg`, `ssm_aws_access_key_id`,
`ssm_aws_secret_access_key`.
Optional: `read_ssm_label`, `ssm_ignore_cache` (force live fetch), `projectName` (log prefix).

Skips keys already defined (cache or earlier facts) via `varnames`. `set_fact` uses `no_log`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.ssm
    tasks_from: read_from_definitions
    apply:
      tags:
        - common-ssm
  vars:
    read_ssm_label: my_app
  tags:
    - common-ssm
```
