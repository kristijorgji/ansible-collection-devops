# Role: `kristijorgji.devops.docker`

Install Docker CE (or distro packages), enable the engine, optionally add users to the
`docker` group, and install Compose as a plugin and/or a standalone binary.

This role does **not** deploy Compose stacks, reverse proxies, or container images.

Debian family only in v1 (Ubuntu 22.04/24.04, Debian 12). Architectures amd64 and arm64
are mapped from `ansible_architecture` — there is no silent amd64 fallback.

---

## Table of contents

- [Task files](#task-files)
- [Versioning](#versioning)
- [Idempotency and upgrades](#idempotency-and-upgrades)
- [`install`](#install)
- [`compose`](#compose)
- [`users`](#users)

---

## Task files

| File      | Purpose                                                           |
| --------- | ----------------------------------------------------------------- |
| `install` | Facts, apt repo, engine packages, service, group members, Compose |
| `compose` | Compose plugin (CE) and/or standalone GitHub binary               |
| `users`   | Append `docker_users` to group `docker`                           |

`main.yml` imports `install`, so `roles: [kristijorgji.devops.docker]` converges the engine.
Call `tasks_from: install` for the same work from `include_role`.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## Versioning

| Setting  | Engine (`docker_engine_version`) / plugin (`docker_compose_plugin_version`) | Standalone (`docker_compose_standalone_version`) |
| -------- | --------------------------------------------------------------------------- | ------------------------------------------------ |
| empty    | No apt pin; `docker_packages_state: present` keeps the installed package    | n/a (standalone default is `latest`)             |
| `latest` | Use `docker_packages_state: latest` (not this string on engine/plugin)      | GitHub `releases/latest/download`                |
| pin      | Apt version string, e.g. `5:28.3.3-1~ubuntu.24.04~noble`                    | GitHub tag, e.g. `v5.6.1`                        |

Production consumers typically pin the standalone binary and leave the engine at
`present` (no surprise upgrades). `docker_packages_state: latest` upgrades CE packages.

Pinned CE / plugin packages are `apt-mark` held.

---

## Idempotency and upgrades

- `docker_packages_state: present` does not bump installed CE packages.
- `docker_packages_state: latest` does.
- Switching `docker.io` → CE with `docker_remove_conflicts: true` (default) removes
  conflicting distro packages and **may restart the engine**. Containers with a restart
  policy come back.
- Writing `/etc/docker/daemon.json` from a non-empty `docker_daemon_options` notifies a
  restart. Leave it `{}` to leave an existing file unmanaged.

---

## `install`

Optional: `docker_users`, `docker_install_source` (`ce` \| `distro` \| `skip`),
`docker_packages_state`, `docker_engine_version`, `docker_install_buildx`,
`docker_remove_conflicts`, `docker_apt_channel`, `docker_apt_arch`, `docker_repo_url`,
`docker_service_state`, `docker_service_enabled`, `docker_daemon_options`,
`docker_compose_install` (`plugin` \| `standalone` \| `both` \| `none`),
`docker_compose_plugin_version`, `docker_compose_standalone_version`,
`docker_compose_standalone_path`, `docker_skip`.

`docker_skip: true` is a full no-op. `docker_install_source: skip` still runs service,
users, and Compose (no package changes).

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.docker
    tasks_from: install
    apply:
      tags: docker
  tags: docker
```

Classic role include (same tasks as `install`):

```yaml
roles:
  - role: kristijorgji.devops.docker
    tags: docker
    vars:
      docker_users:
        - "{{ ansible_user }}"
```

Pin versions:

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.docker
    tasks_from: install
  vars:
    docker_engine_version: "5:28.3.3-1~ubuntu.24.04~noble"
    docker_compose_standalone_version: v5.6.1
    docker_packages_state: present
```

Plugin only (no hyphen binary):

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.docker
    tasks_from: install
  vars:
    docker_compose_install: plugin
```

Skip the role:

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.docker
    tasks_from: install
  vars:
    docker_skip: true
```

| Variable                            | Default                             | Meaning                                                                              |
| ----------------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------ |
| `docker_install_source`             | `ce`                                | `ce` = Docker Inc. repo. `distro` = OS `docker.io`. `skip` = do not change packages. |
| `docker_packages_state`             | `present`                           | `present` or `latest`.                                                               |
| `docker_engine_version`             | `""`                                | Empty = no pin. Otherwise apt version for `docker-ce` / `docker-ce-cli`.             |
| `docker_install_buildx`             | `true`                              | Install `docker-buildx-plugin` (CE) or `docker-buildx` (distro).                     |
| `docker_remove_conflicts`           | `true`                              | When `ce`: remove `docker.io` and related distro packages (engine may restart).      |
| `docker_apt_channel`                | `stable`                            | `stable` or `test`.                                                                  |
| `docker_apt_arch`                   | `""`                                | Empty = from facts (`amd64` or `arm64`).                                             |
| `docker_repo_url`                   | `https://download.docker.com/linux` | Base URL; distribution comes from `ansible_distribution`.                            |
| `docker_service_state`              | `started`                           | `service` state.                                                                     |
| `docker_service_enabled`            | `true`                              | Enable on boot.                                                                      |
| `docker_users`                      | `[]`                                | Usernames appended to group `docker`. Empty = no group changes.                      |
| `docker_daemon_options`             | `{}`                                | If non-empty, write `/etc/docker/daemon.json` and restart.                           |
| `docker_compose_install`            | `both`                              | `plugin`, `standalone`, `both`, or `none`.                                           |
| `docker_compose_plugin_version`     | `""`                                | Empty = no pin on `docker-compose-plugin`.                                           |
| `docker_compose_standalone_version` | `latest`                            | `latest` or a GitHub tag such as `v5.6.1`.                                           |
| `docker_compose_standalone_path`    | `/usr/local/bin/docker-compose`     | Standalone binary path.                                                              |
| `docker_skip`                       | `false`                             | If true, the role is a no-op.                                                        |

`docker_install_source: distro` plus `docker_compose_install: plugin` fails (no CE plugin).
`distro` plus `both` installs the standalone binary only.

---

## `compose`

Optional: `docker_compose_install`, `docker_compose_standalone_version`,
`docker_compose_standalone_path`. Requires facts from `install` (or a previous
`install` on the same host) so Compose GitHub arch is set.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.docker
    tasks_from: compose
    apply:
      tags: docker
  tags: docker
```

Call `install` first unless you already ran the full role (Compose needs
`docker_compose_github_arch` from facts).

---

## `users`

Optional: `docker_users` (list of usernames). Empty list is a no-op. Never assumes `ubuntu`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.docker
    tasks_from: users
    apply:
      tags: docker
  vars:
    docker_users:
      - deploy
  tags: docker
```
