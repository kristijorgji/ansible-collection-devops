#!/usr/bin/env bash
# Purpose: host-level ops notifier for cron and other jobs (any project on the box).
# Usage:
#   ops-notify alert --event <id> --severity error|warn --subject <s> [--body-file <f>]
#   ops-notify ping <check> start|success|fail [--body-file <f>]
#   ops-notify run --check <name> [--alert-event <id>] -- <cmd...>
# Env:     /etc/ops-notify/ops-notify.env (override with OPS_NOTIFY_ENV_FILE)
# Channels: SMTPS and/or SendGrid email, slack|json webhooks, Healthchecks.io-style ping URLs
# Exit:    alert/ping always 0 (send failures go to stderr); run returns the command status
# Dry-run: OPS_NOTIFY_DRY_RUN=1 prints url= and payload= to stderr instead of POSTing
set -uo pipefail

ENV_FILE="${OPS_NOTIFY_ENV_FILE:-/etc/ops-notify/ops-notify.env}"
BODY_LIMIT=10240
SENDGRID_URL="https://api.sendgrid.com/v3/mail/send"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090,SC1091
  . "$ENV_FILE"
  set +a
fi

OPS_NOTIFY_EMAIL_TO="${OPS_NOTIFY_EMAIL_TO:-}"
OPS_NOTIFY_EMAIL_FROM="${OPS_NOTIFY_EMAIL_FROM:-}"
OPS_NOTIFY_SENDGRID_API_KEY="${OPS_NOTIFY_SENDGRID_API_KEY:-}"
OPS_NOTIFY_SMTP_HOST="${OPS_NOTIFY_SMTP_HOST:-}"
OPS_NOTIFY_SMTP_PORT="${OPS_NOTIFY_SMTP_PORT:-465}"
OPS_NOTIFY_SMTP_USER="${OPS_NOTIFY_SMTP_USER:-}"
OPS_NOTIFY_SMTP_PASSWORD="${OPS_NOTIFY_SMTP_PASSWORD:-}"
OPS_NOTIFY_WEBHOOKS="${OPS_NOTIFY_WEBHOOKS:-}"

usage() {
  cat >&2 <<'EOF'
usage:
  ops-notify alert --event <id> --severity error|warn --subject <s> [--body-file <f>]
  ops-notify ping <check> start|success|fail [--body-file <f>]
  ops-notify run --check <name> [--alert-event <id>] -- <cmd...>
EOF
}

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

read_body() {
  local file="${1:-}"
  if [[ -z "$file" || ! -f "$file" ]]; then
    printf ''
    return 0
  fi
  head -c "$BODY_LIMIT" "$file"
}

json_escape() {
  local s="${1:-}"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.argv[1])[1:-1])' "$s"
    return
  fi
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  s=${s//$'\b'/\\b}
  s=${s//$'\f'/\\f}
  s=${s//$'\033'/\\u001b}
  printf '%s' "$s"
}

json_string() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg s "${1:-}" '$s'
  else
    printf '"%s"' "$(json_escape "${1:-}")"
  fi
}

redact() {
  local s="${1:-}"
  local key="${OPS_NOTIFY_SENDGRID_API_KEY:-}"
  local pass="${OPS_NOTIFY_SMTP_PASSWORD:-}"
  if [[ -n "$key" ]]; then
    s=${s//"$key"/REDACTED}
  fi
  if [[ -n "$pass" ]]; then
    s=${s//"$pass"/REDACTED}
  fi
  printf '%s' "$s"
}

http_post() {
  local url="$1"
  local payload="$2"
  local auth="${3:-}"

  if [[ "${OPS_NOTIFY_DRY_RUN:-}" == "1" ]]; then
    printf 'DRY_RUN url=%s\n' "$(redact "$url")" >&2
    printf 'DRY_RUN payload=%s\n' "$(redact "$payload")" >&2
    return 0
  fi

  local args=(-sS -m 10 -o /dev/null -w '%{http_code}' --data-binary "$payload")
  if [[ -n "$auth" ]]; then
    args+=(-H "Authorization: Bearer ${auth}" -H "Content-Type: application/json")
  fi

  local code errfile err
  errfile="$(mktemp)"
  code="$(curl "${args[@]}" "$url" 2>"$errfile" || true)"
  if [[ ! "$code" =~ ^2 ]]; then
    err="$(cat "$errfile" 2>/dev/null || true)"
    printf 'ops-notify: request failed url=%s http=%s %s\n' "$url" "${code:-000}" "$err" >&2
  fi
  rm -f "$errfile"
}

parse_from() {
  local from="${1:-}"
  FROM_NAME=""
  FROM_EMAIL="$from"
  if [[ "$from" == *'<'*'>'* ]]; then
    FROM_NAME="$(trim "${from%%<*}")"
    FROM_EMAIL="${from##*<}"
    FROM_EMAIL="${FROM_EMAIL%>}"
    FROM_EMAIL="$(trim "$FROM_EMAIL")"
  fi
}

email_domain() {
  local addr
  addr="$(trim "${1:-}")"
  if [[ "$addr" == *'<'*'>'* ]]; then
    addr="${addr##*<}"
    addr="${addr%>}"
    addr="$(trim "$addr")"
  fi
  printf '%s' "${addr##*@}"
}

hc_env_name() {
  local name="${1:-}"
  local snake="${name//-/_}"
  snake="${snake//./_}"
  snake="${snake// /_}"
  snake="$(printf '%s' "$snake" | tr '[:lower:]' '[:upper:]')"
  printf 'OPS_NOTIFY_HC_%s' "$snake"
}

send_smtps() {
  local subject="$1"
  local body="$2"
  shift 2
  local rcpts=("$@")
  local host="${OPS_NOTIFY_SMTP_HOST}"
  local port="${OPS_NOTIFY_SMTP_PORT:-465}"
  local user="${OPS_NOTIFY_SMTP_USER}"
  local pass="${OPS_NOTIFY_SMTP_PASSWORD}"
  local url="smtps://${host}:${port}"
  local to_header=""
  local part

  if [[ ${#rcpts[@]} -eq 0 ]]; then
    return 0
  fi
  to_header="$(IFS=', '; echo "${rcpts[*]}")"

  if [[ "${OPS_NOTIFY_DRY_RUN:-}" == "1" ]]; then
    printf 'DRY_RUN url=%s\n' "$url" >&2
    printf 'DRY_RUN payload=From: %s To: %s Subject: %s\n' \
      "${OPS_NOTIFY_EMAIL_FROM}" "$to_header" "$subject" >&2
    return 0
  fi

  local eml errfile code
  eml="$(mktemp)"
  errfile="$(mktemp)"
  local mid
  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    mid="$(tr -d '[:space:]' </proc/sys/kernel/random/uuid)"
  else
    mid="$(openssl rand -hex 16)"
  fi
  {
    printf 'From: %s\r\n' "${OPS_NOTIFY_EMAIL_FROM}"
    printf 'To: %s\r\n' "$to_header"
    printf 'Subject: %s\r\n' "$subject"
    printf 'Date: %s\r\n' "$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
    printf 'Message-ID: <%s@%s>\r\n' "$mid" "$(email_domain "$FROM_EMAIL")"
    printf 'MIME-Version: 1.0\r\n'
    printf 'Content-Type: text/plain; charset=UTF-8\r\n'
    printf '\r\n'
    printf '%s' "$body"
    printf '\r\n'
  } >"$eml"

  local args=(
    -sS -m 20 -o /dev/null -w '%{http_code}'
    --ssl-reqd
    --url "$url"
    --user "${user}:${pass}"
    --mail-from "$FROM_EMAIL"
    --upload-file "$eml"
  )
  for part in "${rcpts[@]}"; do
    args+=(--mail-rcpt "$part")
  done

  code="$(curl "${args[@]}" 2>"$errfile" || true)"
  if [[ -s "$errfile" ]] || [[ "$code" =~ ^[45] ]]; then
    printf 'ops-notify: request failed url=%s http=%s %s\n' \
      "$url" "${code:-000}" "$(cat "$errfile" 2>/dev/null || true)" >&2
  fi
  rm -f "$eml" "$errfile"
}

send_sendgrid() {
  local subject="$1"
  local body="$2"
  shift 2
  local rcpts=("$@")
  local key="${OPS_NOTIFY_SENDGRID_API_KEY:-}"
  if [[ -z "$key" || ${#rcpts[@]} -eq 0 ]]; then
    return 0
  fi
  if [[ -z "$body" ]]; then
    body="${subject:- }"
  fi

  local payload=""
  if command -v jq >/dev/null 2>&1; then
    local emails_json="[]"
    local part
    for part in "${rcpts[@]}"; do
      emails_json="$(jq -c --arg e "$part" '. + [$e]' <<<"$emails_json")"
    done
    payload="$(jq -n \
      --argjson emails "$emails_json" \
      --arg from_email "$FROM_EMAIL" \
      --arg from_name "$FROM_NAME" \
      --arg subject "$subject" \
      --arg body "$body" \
      '{
        personalizations: [{to: ($emails | map({email: .}))}],
        from: ({email: $from_email} + if $from_name == "" then {} else {name: $from_name} end),
        subject: $subject,
        content: [{type: "text/plain", value: $body}]
      }')"
  else
    local to_parts="" part esc
    for part in "${rcpts[@]}"; do
      esc="$(json_escape "$part")"
      to_parts="${to_parts:+$to_parts,}{\"email\":\"${esc}\"}"
    done
    local from_json
    from_json="{\"email\":\"$(json_escape "$FROM_EMAIL")\""
    if [[ -n "$FROM_NAME" ]]; then
      from_json="${from_json},\"name\":\"$(json_escape "$FROM_NAME")\""
    fi
    from_json="${from_json}}"
    payload="{\"personalizations\":[{\"to\":[${to_parts}]}],\"from\":${from_json},\"subject\":\"$(json_escape "$subject")\",\"content\":[{\"type\":\"text/plain\",\"value\":\"$(json_escape "$body")\"}]}"
  fi

  http_post "$SENDGRID_URL" "$payload" "$key"
}

send_email() {
  local subject="$1"
  local body="$2"
  local to_raw="${OPS_NOTIFY_EMAIL_TO:-}"
  if [[ -z "$to_raw" ]]; then
    return 0
  fi

  parse_from "${OPS_NOTIFY_EMAIL_FROM:-}"
  if [[ -z "$FROM_EMAIL" ]]; then
    return 0
  fi

  local from_domain smtp_ready
  from_domain="$(email_domain "$FROM_EMAIL")"
  smtp_ready=0
  if [[ -n "${OPS_NOTIFY_SMTP_HOST}" && -n "${OPS_NOTIFY_SMTP_USER}" && -n "${OPS_NOTIFY_SMTP_PASSWORD}" ]]; then
    smtp_ready=1
  fi

  local smtp_rcpts=() sg_rcpts=() part rcpt_domain
  IFS=',' read -r -a _ops_notify_emails <<< "$to_raw"
  for part in "${_ops_notify_emails[@]}"; do
    part="$(trim "$part")"
    [[ -z "$part" ]] && continue
    rcpt_domain="$(email_domain "$part")"
    if [[ "$smtp_ready" -eq 1 && -n "$from_domain" && "$rcpt_domain" == "$from_domain" ]]; then
      smtp_rcpts+=("$part")
    elif [[ -n "${OPS_NOTIFY_SENDGRID_API_KEY}" ]]; then
      sg_rcpts+=("$part")
    fi
  done

  if [[ ${#smtp_rcpts[@]} -gt 0 ]]; then
    send_smtps "$subject" "$body" "${smtp_rcpts[@]}"
  fi
  if [[ ${#sg_rcpts[@]} -gt 0 ]]; then
    send_sendgrid "$subject" "$body" "${sg_rcpts[@]}"
  fi
}

send_webhooks() {
  local event="$1"
  local severity="$2"
  local subject="$3"
  local body="$4"
  local host time_utc payload line format url text
  host="$(hostname -s 2>/dev/null || hostname || printf 'unknown')"
  time_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    format="${line%%|*}"
    url="${line#*|}"
    format="$(trim "$format")"
    url="$(trim "$url")"
    [[ -z "$url" ]] && continue
    case "$format" in
      slack)
        text="${subject}"
        if [[ -n "$body" ]]; then
          text="${subject}"$'\n'"${body}"
        fi
        payload="{\"text\":$(json_string "$text")}"
        ;;
      json)
        payload="$(printf '{"event":%s,"severity":%s,"subject":%s,"body":%s,"host":%s,"time":%s}' \
          "$(json_string "$event")" \
          "$(json_string "$severity")" \
          "$(json_string "$subject")" \
          "$(json_string "$body")" \
          "$(json_string "$host")" \
          "$(json_string "$time_utc")")"
        ;;
      *)
        printf 'ops-notify: unknown webhook format %s\n' "$format" >&2
        continue
        ;;
    esac
    http_post "$url" "$payload"
  done <<<"${OPS_NOTIFY_WEBHOOKS}"
}

cmd_alert() {
  local event="" severity="" subject="" body_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --event)
        event="${2:-}"
        shift 2
        ;;
      --severity)
        severity="${2:-}"
        shift 2
        ;;
      --subject)
        subject="${2:-}"
        shift 2
        ;;
      --body-file)
        body_file="${2:-}"
        shift 2
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        printf 'ops-notify alert: unknown argument %s\n' "$1" >&2
        usage
        return 0
        ;;
    esac
  done

  if [[ -z "$event" || -z "$severity" || -z "$subject" ]]; then
    printf 'ops-notify alert: --event, --severity, and --subject are required\n' >&2
    usage
    return 0
  fi
  if [[ "$severity" != "error" && "$severity" != "warn" ]]; then
    printf 'ops-notify alert: --severity must be error or warn\n' >&2
    return 0
  fi

  local body
  body="$(read_body "$body_file")"
  send_email "$subject" "$body"
  send_webhooks "$event" "$severity" "$subject" "$body"
  return 0
}

cmd_ping() {
  local check="" status="" body_file=""
  if [[ $# -ge 1 && "$1" != --* ]]; then
    check="$1"
    shift
  fi
  if [[ $# -ge 1 && "$1" != --* ]]; then
    status="$1"
    shift
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body-file)
        body_file="${2:-}"
        shift 2
        ;;
      *)
        printf 'ops-notify ping: unknown argument %s\n' "$1" >&2
        usage
        return 0
        ;;
    esac
  done

  if [[ -z "$check" || -z "$status" ]]; then
    printf 'ops-notify ping: check name and start|success|fail are required\n' >&2
    usage
    return 0
  fi
  case "$status" in
    start | success | fail) ;;
    *)
      printf 'ops-notify ping: status must be start, success, or fail\n' >&2
      return 0
      ;;
  esac

  local var url body
  var="$(hc_env_name "$check")"
  url="$(printenv "$var" 2>/dev/null || true)"
  if [[ -z "$url" ]]; then
    return 0
  fi
  case "$status" in
    start) url="${url%/}/start" ;;
    fail) url="${url%/}/fail" ;;
    success) url="${url%/}" ;;
  esac
  body="$(read_body "$body_file")"
  http_post "$url" "$body"
  return 0
}

cmd_run() {
  local check="" alert_event=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        check="${2:-}"
        shift 2
        ;;
      --alert-event)
        alert_event="${2:-}"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      -h | --help)
        usage
        return 2
        ;;
      *)
        printf 'ops-notify run: unknown argument %s\n' "$1" >&2
        usage
        return 2
        ;;
    esac
  done

  if [[ -z "$check" || $# -eq 0 ]]; then
    printf 'ops-notify run: --check <name> and -- <cmd...> are required\n' >&2
    usage
    return 2
  fi

  local log body rc
  log="$(mktemp)"
  body="$(mktemp)"
  cmd_ping "$check" start
  "$@" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  tail -n 100 "$log" >"$body"
  if [[ "$rc" -eq 0 ]]; then
    cmd_ping "$check" success --body-file "$body"
  else
    cmd_ping "$check" fail --body-file "$body"
    if [[ -n "$alert_event" ]]; then
      cmd_alert --event "$alert_event" --severity error \
        --subject "ops-notify: ${check} failed (exit=${rc})" --body-file "$body"
    fi
  fi
  rm -f "$log" "$body"
  return "$rc"
}

main() {
  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    usage
    exit 2
  fi
  shift
  case "$cmd" in
    alert)
      cmd_alert "$@"
      exit 0
      ;;
    ping)
      cmd_ping "$@"
      exit 0
      ;;
    run)
      cmd_run "$@"
      exit $?
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'ops-notify: unknown command %s\n' "$cmd" >&2
      usage
      exit 2
      ;;
  esac
}

main "$@"
