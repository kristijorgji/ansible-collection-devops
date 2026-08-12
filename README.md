# kristijorgji.devops

Public Ansible collection of reusable **devops build and transfer** helpers.
Install the whole collection; call only the roles you need.

## Install

```yaml
# collections/requirements.yml
collections:
  - name: https://github.com/kristijorgji/ansible-collection-devops.git
    type: git
    version: v0.1.0
```

```shell
ansible-galaxy collection install -r collections/requirements.yml
```

## Roles

| Role | Purpose |
| --- | --- |
| `kristijorgji.devops.nodejs` | Native nvm + pnpm install/build, optional Docker builder |
| `kristijorgji.devops.transfer` | Rsync a local tree to a remote server path |

More roles can be added under `roles/` in later versions without renaming the collection.

## Quick examples

### Native pnpm install + build

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: nvm_exec
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    pnpm_node_version: "22.16.0"
    pnpm_builder_version: "9.15.4"
    pnpm_nvm_command: "pnpm build"
```

### Rsync build output to a server

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

See each role’s `README.md` for variables.

## Requirements

- Ansible Core ≥ 2.15
- For `transfer`: `ansible.posix` collection
- For native Node builds: [nvm](https://github.com/nvm-sh/nvm) on the build host (Homebrew or `~/.nvm`)
