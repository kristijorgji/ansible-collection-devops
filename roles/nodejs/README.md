# Role: `kristijorgji.devops.nodejs`

Node.js build helpers via nvm or Docker, for pnpm / yarn / npm.

Prefer `pnpm_*` entrypoints when using pnpm. Call generics with
`node_package_manager: yarn|npm|pnpm` for other managers.

---

## Table of contents

- [Task files](#task-files)
- [`pnpm_build`](#pnpm_build)
- [`pnpm_nvm_exec`](#pnpm_nvm_exec)
- [`pnpm_ensure_builder_image`](#pnpm_ensure_builder_image)
- [`pnpm_docker_install`](#pnpm_docker_install)
- [`pnpm_docker_exec`](#pnpm_docker_exec)
- [`nvm_exec`](#nvm_exec)
- [`docker_install`](#docker_install)
- [`docker_exec`](#docker_exec)
- [`ensure_builder_image`](#ensure_builder_image)
- [`nvm_server_exec`](#nvm_server_exec)
- [`pnpm_server_install`](#pnpm_server_install)
- [`pm_resolve`](#pm_resolve)

---

## Task files

| File                        | Purpose                                              |
| --------------------------- | ---------------------------------------------------- |
| `pnpm_build`                | Native or Docker pnpm install + optional command     |
| `pnpm_nvm_exec`             | Wrapper: `nvm_exec` with `node_package_manager=pnpm` |
| `pnpm_ensure_builder_image` | Wrapper: builder image for pnpm                      |
| `pnpm_docker_install`       | Wrapper: Docker install for pnpm                     |
| `pnpm_docker_exec`          | Wrapper: Docker command for pnpm                     |
| `nvm_exec`                  | Native nvm install + optional `node_command`         |
| `docker_install`            | Install in the builder container                     |
| `docker_exec`               | Run `node_command` in the builder container          |
| `ensure_builder_image`      | Build the Docker builder image once                  |
| `nvm_server_exec`           | nvm use + install/command on the inventory host      |
| `pnpm_server_install`       | Wrapper: production pnpm install on the server       |
| `pm_resolve`                | Validate manager and set `node_pm_cfg`               |

Role tasks use `node_become_effective` (never escalate on localhost). Pass play
`become_in_build_machine` unchanged — do not rebind it in `include_role` vars.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `pnpm_build`

Required: `projectName`, `codePath`, `delegate_build_to_host`.
Optional: `node_build_executor` (`native` \| `docker`), `node_command`,
`dockerBuilderImage`, `node_version`, `node_pm_version`, `node_run_install`,
`github_packages_token`, `become_in_build_machine`.

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
```

---

## `pnpm_nvm_exec`

Required: `projectName`, `codePath`, `delegate_build_to_host`.
Optional: `node_command`, `node_run_install`, `node_version`, `github_packages_token`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: pnpm_nvm_exec
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    node_command: "pnpm build"
```

---

## `pnpm_ensure_builder_image`

Required: `dockerBuilderImage`, `delegate_build_to_host`.
Optional: `node_version`, `node_pm_version`, `node_ensure_builder_run_once`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: pnpm_ensure_builder_image
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    dockerBuilderImage: "pnpm-builder:22.16.0"
    delegate_build_to_host: 127.0.0.1
```

---

## `pnpm_docker_install`

Required: `projectName`, `codePath`, `delegate_build_to_host`, `dockerBuilderImage`.
Optional: `node_run_install`, `github_packages_token`, `docker_target_platform`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: pnpm_docker_install
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    dockerBuilderImage: "pnpm-builder:22.16.0"
```

---

## `pnpm_docker_exec`

Required: `projectName`, `codePath`, `delegate_build_to_host`, `dockerBuilderImage`,
`node_command`.
Optional: `node_docker_extra_volume_flags`, `docker_target_platform`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: pnpm_docker_exec
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    dockerBuilderImage: "pnpm-builder:22.16.0"
    node_command: "pnpm build"
```

---

## `nvm_exec`

Required: `projectName`, `codePath`, `delegate_build_to_host`, `node_package_manager`.
Optional: `node_command`, `node_run_install`, `node_version`, `node_pm_version`,
`node_apply_cross_platform`, `github_packages_token`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: nvm_exec
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    node_package_manager: yarn
    node_command: "yarn build"
```

---

## `docker_install`

Required: `projectName`, `codePath`, `delegate_build_to_host`, `dockerBuilderImage`,
`node_package_manager`.
Optional: `node_run_install`, `github_packages_token`, `docker_target_platform`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: docker_install
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    dockerBuilderImage: "yarn-builder:18.16.0"
    node_package_manager: yarn
```

---

## `docker_exec`

Required: `projectName`, `codePath`, `delegate_build_to_host`, `dockerBuilderImage`,
`node_package_manager`, `node_command`.
Optional: `node_docker_extra_volume_flags`, `docker_target_platform`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: docker_exec
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    dockerBuilderImage: "yarn-builder:18.16.0"
    node_package_manager: yarn
    node_command: "yarn build"
```

---

## `ensure_builder_image`

Required: `dockerBuilderImage`, `delegate_build_to_host`, `node_package_manager`.
Optional: `node_version`, `node_pm_version`, `node_ensure_builder_run_once`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: ensure_builder_image
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    dockerBuilderImage: "pnpm-builder:22.16.0"
    delegate_build_to_host: 127.0.0.1
    node_package_manager: pnpm
```

---

## `nvm_server_exec`

Required: `projectName`, `serverCodePath`, `node_package_manager`.
Optional: `node_command`, `node_run_install`, `node_version`,
`pnpm_run_server_install`, `pnpm_server_install_production`.

Runs on the inventory host (no `delegate_to`). Node must already be installed via nvm.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: nvm_server_exec
  vars:
    projectName: my_app
    serverCodePath: /var/www/app
    node_package_manager: pnpm
    node_run_install: true
```

---

## `pnpm_server_install`

Required: `projectName`, `serverCodePath`.
Optional: `pnpm_run_server_install`, `pnpm_server_install_production`, `node_version`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: pnpm_server_install
  vars:
    projectName: my_app
    serverCodePath: /var/www/app
```

---

## `pm_resolve`

Required: `node_package_manager` (must be a key in `node_package_managers`).
Sets `node_pm_cfg`. Used by the other nodejs task files; rarely called directly.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: pm_resolve
  vars:
    node_package_manager: pnpm
```
