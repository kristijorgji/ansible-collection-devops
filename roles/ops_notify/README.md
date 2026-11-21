# Role: `kristijorgji.devops.ops_notify`

Host-level notifier so cron and other jobs can send email (SMTPS and/or SendGrid), post webhooks,
and ping Healthchecks.io-style URLs. Empty defaults make the role a no-op: missing recipients,
SMTP, API key, webhooks, or ping URLs skip that channel.

`alert` and `ping` always exit 0 (send failures go to stderr) so they never fail a cron job.
`run` exits with the wrapped command's status.

The role is not tied to a project. Include it from any playbook; set recipients, keys, SMTP, and
healthcheck URLs in that inventory's group_vars.

Same-domain recipients (recipient domain equals the `From` domain) use SMTPS when host/user/password
are set. Any other recipient uses the SendGrid API when the key is set. Mixed `ops_notify_email_to`
lists are split across both channels.

---

## Table of contents

- [Task files](#task-files)
- [`install`](#install)

---

## Task files

| File      | Purpose                                              |
| --------- | ---------------------------------------------------- |
| `install` | Packages, group, script, and env file                |

`main.yml` imports `install`.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `install`

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.ops_notify
    tasks_from: install
    apply:
      tags: ops-notify
  vars:
    ops_notify_email_from: "Ops <noreply@example.com>"
    ops_notify_email_to:
      - admin@example.com
    ops_notify_smtp_host: mail.example.com
    ops_notify_smtp_port: 465
    ops_notify_smtp_user: app@example.com
    ops_notify_smtp_password: "{{ vault_app_smtp_pass }}"
  tags: ops-notify
```

Or `roles: [kristijorgji.devops.ops_notify]`.

The script is `0755` at `/usr/local/bin/ops-notify` (no Jinja; default env
`/etc/ops-notify/ops-notify.env`). Config directory `0750`, env file `0640`, owner
`ops_notify_user` / `ops_notify_group`. Cron users that must read the env go in
`ops_notify_members`. `jq` and `curl` are installed so SendGrid JSON stays valid with quoted
or ANSI bodies.

Override values per inventory. Do not put ping UUIDs or SMTP passwords in plaintext group_vars —
use vault.

### Commands

```shell
ops-notify alert --event job.failed --severity error \
  --subject "job failed exit=1" --body-file /tmp/run.log

ops-notify ping my-check start
ops-notify ping my-check success --body-file /tmp/run.log
ops-notify ping my-check fail --body-file /tmp/run.log

ops-notify run --check my-check --alert-event job.failed -- \
  /usr/local/bin/your-cron.sh
```

| Command | Behaviour |
| ------- | --------- |
| `alert` | Email each `OPS_NOTIFY_EMAIL_TO` over SMTPS when the recipient domain matches `From` and SMTP is configured; otherwise SendGrid `POST https://api.sendgrid.com/v3/mail/send`. Slack webhooks send `{"text": "<subject>\n<body>"}`; `json` webhooks send `event`, `severity`, `subject`, `body`, `host`, `time`. Body is capped at 10 KB. |
| `ping` | POST to `OPS_NOTIFY_HC_<CHECK>` (`success`), `<url>/start`, or `<url>/fail`. Missing URL returns 0 with no request. |
| `run` | `ping start`, run the command (output teed to stdout and a temp file), then `ping success` or `ping fail` with the last 100 lines. On failure, `alert` when `--alert-event` is set. Exit status is the command's. |

### Dry-run

```shell
OPS_NOTIFY_DRY_RUN=1 ops-notify alert --event test --severity warn --subject "dry run"
```

Prints each request (`url=` and `payload=`) to stderr instead of sending. SMTP URLs look like
`smtps://host:465`. SendGrid and SMTP passwords are redacted. Override the env path with
`OPS_NOTIFY_ENV_FILE`.

### Healthchecks

Create checks at [Healthchecks.io](https://healthchecks.io) (or any ping URL with `/start` and
`/fail` suffixes). Map names to URLs in group_vars:

```yaml
ops_notify_healthchecks:
  my-check: "{{ vault_ops_notify_hc_my_check }}"
```

Each key becomes `OPS_NOTIFY_HC_<UPPER_SNAKE_NAME>` (so `my-check` → `OPS_NOTIFY_HC_MY_CHECK`).

| Variable                      | Default                                      | Description                                                                                                     |
| ----------------------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `ops_notify_user`             | `root`                                       | Owner of the config directory and env file.                                                                     |
| `ops_notify_group`            | `ops-notify`                                 | Group that may read the env file.                                                                               |
| `ops_notify_manage_group`     | `true`                                       | Create `ops_notify_group` and add `ops_notify_members`.                                                         |
| `ops_notify_members`          | `[]`                                         | Extra host users appended to `ops_notify_group` (project cron users).                                           |
| `ops_notify_config_dir`       | `/etc/ops-notify`                            | Config directory.                                                                                               |
| `ops_notify_env_path`         | `{{ ops_notify_config_dir }}/ops-notify.env` | Env file path.                                                                                                  |
| `ops_notify_dir_mode`         | `"0750"`                                     | Config directory mode.                                                                                          |
| `ops_notify_env_mode`         | `"0640"`                                     | Env file mode (group-readable for shared hosts).                                                                |
| `ops_notify_email_to`         | `[]`                                         | Recipient list. Joined with commas into `OPS_NOTIFY_EMAIL_TO`.                                                  |
| `ops_notify_email_from`       | `""`                                         | From address (display name allowed). Empty skips email.                                                         |
| `ops_notify_sendgrid_api_key` | `""`                                         | SendGrid API key. Empty skips the SendGrid path.                                                                |
| `ops_notify_smtp_host`        | `""`                                         | SMTPS host. Empty skips same-domain SMTP.                                                                       |
| `ops_notify_smtp_port`        | `465`                                        | SMTPS port.                                                                                                     |
| `ops_notify_smtp_user`        | `""`                                         | SASL username.                                                                                                  |
| `ops_notify_smtp_password`    | `""`                                         | SASL password.                                                                                                  |
| `ops_notify_webhooks`         | `[]`                                         | List of `{ name, url, format }` where `format` is `slack` or `json`. Stored as newline-separated `format\|url`. |
| `ops_notify_healthchecks`     | `{}`                                         | Map of check name → ping URL.                                                                                   |
