# Role: `kristijorgji.devops.nodejs`

Node.js build helpers via **nvm** or **Docker**, for **pnpm / yarn / npm**.

Prefer **`pnpm_*`** entrypoints when using pnpm (they only set `node_package_manager: pnpm`).
Call generics with `node_package_manager: yarn|npm|pnpm` for other managers.

---

## Table of contents

- [Task files](#task-files-tasks_from)
- [Scripts](#scripts-files)
- [Important variables](#important-variables)
- [Example: pnpm_build](#example-pnpm_build)

---

## Task files (`tasks_from`)

| File                                             | Purpose                                                 |
| ------------------------------------------------ | ------------------------------------------------------- |
| **`pnpm_build`**                                 | Convenience: `node_build_executor` `native` \| `docker` |
| `pnpm_nvm_exec`                                  | Native install + optional `node_command` (pnpm)         |
| `pnpm_ensure_builder_image`                      | Build builder image once (pnpm)                         |
| `pnpm_docker_install`                            | Install in Docker (pnpm)                                |
| `pnpm_docker_exec`                               | Run `node_command` in Docker (pnpm)                     |
| `nvm_exec` / `docker_*` / `ensure_builder_image` | Same primitives; set `node_package_manager`             |
| `nvm_server_exec`                                | Server-side nvm use + install/command (no delegate)     |
| `pnpm_server_install`                            | Wrapper: pnpm production install on inventory host      |

Task log names use greppable **`native:`** / **`docker:`** prefixes.

---

## Scripts (`files/`)

| Script                      | Purpose                                                       |
| --------------------------- | ------------------------------------------------------------- |
| `nvm_init.sh`               | Source nvm (Homebrew macOS or `~/.nvm` / `$NVM_DIR` on Linux) |
| `npm_cross_platform_env.sh` | Emit `npm_config_*` for `linux/*` and optional `windows/*`    |
| `yarn_install.sh`           | Shell helper: `S_NODE_VERSION` + optional platform/`prod`     |

Mac + Ubuntu/Linux are mandatory. Native Windows shells fail clearly; use WSL or Docker.

---

## Important variables

| Variable                         | Default        | Notes                                                  |
| -------------------------------- | -------------- | ------------------------------------------------------ |
| `projectName`                    | —              | Required (log prefix)                                  |
| `codePath`                       | —              | App path on build host                                 |
| `delegate_build_to_host`         | —              | e.g. `127.0.0.1`                                       |
| `become_in_build_machine`        | `false`        | Play/site policy: allow become on remote               |
| `node_become`                    | unset          | Optional override of play policy                       |
| `node_become_effective`          | computed       | Policy **and** host ≠ `127.0.0.1`                      |
| `node_package_manager`           | `pnpm`         | `pnpm` \| `yarn` \| `npm`                              |
| `node_build_executor`            | `native`       | For `pnpm_build` only                                  |
| `node_version`                   | `22.16.0`      | nvm / Docker Node                                      |
| `node_pm_version`                | `9.15.4`       | corepack pnpm/yarn version                             |
| `node_build_store_path`          | `~/pnpm-store` | Host cache (tilde expands on build host)               |
| `node_command`                   | `""`           | e.g. `pnpm build`                                      |
| `node_run_install`               | `true`         | Skip install when false                                |
| `node_install_args`              | `""`           | Override map `install_args` when non-empty             |
| `node_apply_cross_platform`      | `false`        | Set `npm_config_*` for linux targets                   |
| `node_docker_extra_volume_flags` | `""`           | Extra `-v` for docker exec                             |
| `github_packages_token`          | `""`           | Optional → `NODE_AUTH_TOKEN`                           |
| `dockerBuilderImage`             | —              | e.g. `pnpm-builder:22.16.0`                            |
| `docker_target_platform`         | `linux/amd64`  | Docker / cross-platform                                |
| `serverCodePath`                 | —              | Required for `nvm_server_exec` / `pnpm_server_install` |
| `pnpm_run_server_install`        | `true`         | Skip server install when false                         |
| `pnpm_server_install_production` | `true`         | Add `--production` to server pnpm install              |

Role tasks use `node_become_effective` (never escalate on localhost). Pass play
`become_in_build_machine` unchanged — do **not** rebind it in `include_role`
`vars` to an expression that references itself (Ansible recursive-loop error).
Optional `node_become` overrides the play policy without shadowing that name.

---

## Example: `pnpm_build`

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: pnpm_build
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    dockerBuilderImage: "pnpm-builder:22.16.0"
    node_build_executor: native
    node_command: "pnpm build"
    node_build_store_path: "~/pnpm-store"
    # become_in_build_machine from play/site; localhost stay false via role
```
