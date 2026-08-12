# Role: `kristijorgji.devops.nodejs`

Node.js build helpers via **nvm + pnpm** (default) or **Docker**.

## Task files (`tasks_from`)

| File | Purpose |
| --- | --- |
| `nvm_exec` | Native install + optional `pnpm_nvm_command` |
| `ensure_builder_image` | Build `pnpm-builder:<node>` once |
| `docker_install` | `pnpm install` in Docker |
| `docker_exec` | Run `pnpm_docker_command` in Docker |

## Important variables

| Variable | Default | Notes |
| --- | --- | --- |
| `projectName` | — | Required (log prefix) |
| `codePath` | — | App path on build host |
| `delegate_build_to_host` | — | e.g. `127.0.0.1` |
| `pnpm_node_version` | `22.16.0` | nvm / Docker Node |
| `pnpm_builder_version` | `9.15.4` | pnpm via corepack |
| `pnpm_build_store_path` | `~/.pnpm-store` | Host store |
| `pnpm_nvm_command` | — | e.g. `pnpm build` |
| `pnpm_nvm_apply_cross_platform` | `false` | Set `npm_config_*` for linux targets |
| `github_packages_token` | `""` | Optional → `NODE_AUTH_TOKEN` |
| `dockerBuilderImage` | — | e.g. `pnpm-builder:22.16.0` |
| `docker_target_platform` | `linux/amd64` | Docker / cross-platform |

## nvm on macOS and Linux

`files/nvm_init.sh` loads Homebrew nvm (`/opt/homebrew` or `/usr/local`) then `$HOME/.nvm`.
