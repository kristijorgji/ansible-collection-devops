#!/usr/bin/env python3
"""Keep-last-N janitor for versioned S3 key prefixes (git-SHA folders)."""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def parse_iso(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name, "")
    if raw == "":
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def env_int(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if raw == "":
        return default
    return int(raw)


def normalize_prefix(prefix: str) -> str:
    prefix = prefix.strip().lstrip("/")
    if not prefix.endswith("/"):
        prefix += "/"
    return prefix


def emit(payload: dict[str, Any], code: int = 0) -> None:
    print(json.dumps(payload, default=str, sort_keys=True))
    raise SystemExit(code)


def usage(msg: str) -> None:
    log(msg)
    emit({"error": msg, "skipped_reason": "usage"}, 2)


def list_common_prefixes(client: Any, bucket: str, prefix: str) -> list[str]:
    found: list[str] = []
    token: str | None = None
    while True:
        kwargs: dict[str, Any] = {
            "Bucket": bucket,
            "Prefix": prefix,
            "Delimiter": "/",
        }
        if token:
            kwargs["ContinuationToken"] = token
        resp = client.list_objects_v2(**kwargs)
        for item in resp.get("CommonPrefixes", []):
            found.append(item["Prefix"])
        if not resp.get("IsTruncated"):
            break
        token = resp.get("NextContinuationToken")
    return found


def max_last_modified(client: Any, bucket: str, prefix: str) -> datetime | None:
    newest: datetime | None = None
    token: str | None = None
    while True:
        kwargs: dict[str, Any] = {"Bucket": bucket, "Prefix": prefix}
        if token:
            kwargs["ContinuationToken"] = token
        resp = client.list_objects_v2(**kwargs)
        for obj in resp.get("Contents", []):
            last_modified = obj["LastModified"]
            if last_modified.tzinfo is None:
                last_modified = last_modified.replace(tzinfo=timezone.utc)
            else:
                last_modified = last_modified.astimezone(timezone.utc)
            if newest is None or last_modified > newest:
                newest = last_modified
        if not resp.get("IsTruncated"):
            break
        token = resp.get("NextContinuationToken")
    return newest


def load_history(client: Any, bucket: str, key: str) -> dict[str, Any] | None:
    try:
        resp = client.get_object(Bucket=bucket, Key=key)
    except ClientError as err:
        code = err.response.get("Error", {}).get("Code", "")
        if code in {"NoSuchKey", "404", "NotFound"}:
            return None
        raise
    body = resp["Body"].read()
    if not body:
        return None
    data = json.loads(body)
    if not isinstance(data, dict):
        return None
    return data


def put_history(client: Any, bucket: str, key: str, payload: dict[str, Any]) -> None:
    client.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(payload, indent=2, sort_keys=True).encode("utf-8"),
        ContentType="application/json",
    )


def key_is_safe(
    key: str,
    root_prefix: str,
    release_id: str,
    id_re: re.Pattern[str],
    reserved: set[str],
) -> bool:
    if not key.startswith(root_prefix):
        return False
    rest = key[len(root_prefix) :]
    if not rest or "/" not in rest:
        return False
    first, _remainder = rest.split("/", 1)
    if first in reserved or not id_re.fullmatch(first):
        return False
    return first == release_id


def delete_prefix_tree(
    client: Any,
    bucket: str,
    root_prefix: str,
    release_id: str,
    id_re: re.Pattern[str],
    reserved: set[str],
) -> list[str]:
    prefix = f"{root_prefix}{release_id}/"
    deleted: list[str] = []
    for _ in range(100):
        resp = client.list_objects_v2(Bucket=bucket, Prefix=prefix, MaxKeys=1000)
        contents = resp.get("Contents", [])
        if not contents:
            break
        objects = []
        for obj in contents:
            key = obj["Key"]
            if not key_is_safe(key, root_prefix, release_id, id_re, reserved):
                raise ValueError(f"refusing to delete unsafe key: {key}")
            objects.append({"Key": key})
        client.delete_objects(
            Bucket=bucket,
            Delete={"Objects": objects, "Quiet": True},
        )
        deleted.extend(item["Key"] for item in objects)
    return deleted


def basename_id(common_prefix: str, root_prefix: str) -> str:
    rest = common_prefix[len(root_prefix) :] if common_prefix.startswith(root_prefix) else common_prefix
    return rest.strip("/")


def main() -> None:
    bucket = os.environ.get("S3_JANITOR_BUCKET", "").strip()
    region = os.environ.get("S3_JANITOR_REGION", "eu-central-1").strip() or "eu-central-1"
    prefix = os.environ.get("S3_JANITOR_PREFIX", "").strip()
    live_id = os.environ.get("S3_JANITOR_LIVE_ID", "").strip()
    keep_releases = env_int("S3_JANITOR_KEEP_RELEASES", 10)
    grace_days = env_int("S3_JANITOR_GRACE_DAYS", 7)
    max_delete = env_int("S3_JANITOR_MAX_DELETE", 20)
    dry_run = env_bool("S3_JANITOR_DRY_RUN", False)
    reserved_raw = os.environ.get("S3_JANITOR_RESERVED", "shared,.janitor")
    reserved = {item.strip() for item in reserved_raw.split(",") if item.strip()}
    reserved.update({"shared", ".janitor"})
    pattern_raw = os.environ.get("S3_JANITOR_ID_PATTERN", r"(?i)^[0-9a-f]{7,40}$")

    if not bucket:
        usage("S3_JANITOR_BUCKET is required")
    if not prefix:
        usage("S3_JANITOR_PREFIX is required")
    if not live_id:
        usage("S3_JANITOR_LIVE_ID is required")
    if keep_releases < 1 or grace_days < 0 or max_delete < 1:
        usage("KEEP_RELEASES >= 1, GRACE_DAYS >= 0, MAX_DELETE >= 1")

    try:
        id_re = re.compile(pattern_raw)
    except re.error as err:
        usage(f"invalid S3_JANITOR_ID_PATTERN: {err}")

    prefix = normalize_prefix(prefix)
    history_key = os.environ.get("S3_JANITOR_HISTORY_KEY", "").strip() or f"{prefix}.janitor/history.json"
    if not history_key.startswith(prefix + ".janitor/"):
        usage("S3_JANITOR_HISTORY_KEY must be under {prefix}.janitor/")

    if not id_re.fullmatch(live_id):
        usage(f"S3_JANITOR_LIVE_ID does not match id pattern: {live_id}")

    summary: dict[str, Any] = {
        "bucket": bucket,
        "deleted": [],
        "delete": [],
        "dry_run": dry_run,
        "history_key": history_key,
        "history_seeded": False,
        "keep": [],
        "live": live_id,
        "prefix": prefix,
        "skipped_reason": "",
    }

    try:
        client = boto3.client("s3", region_name=region)
        common = list_common_prefixes(client, bucket, prefix)
        existing: list[str] = []
        ignored: list[str] = []
        for common_prefix in common:
            release_id = basename_id(common_prefix, prefix)
            if not release_id or release_id in reserved:
                ignored.append(release_id or common_prefix)
                continue
            if not id_re.fullmatch(release_id):
                ignored.append(release_id)
                log(f"ignoring non-id prefix: {common_prefix}")
                continue
            existing.append(release_id)

        summary["ignored"] = sorted(set(ignored))
        summary["existing"] = sorted(existing)

        if live_id not in existing:
            summary["skipped_reason"] = "live_prefix_missing"
            log(f"live prefix missing: {prefix}{live_id}/")
            emit(summary)

        history = load_history(client, bucket, history_key)
        history_by_id: dict[str, datetime] = {}
        if history:
            for item in history.get("releases", []) or []:
                sha = str(item.get("sha", "")).strip()
                uploaded_at = str(item.get("uploaded_at", "")).strip()
                if not sha or not uploaded_at:
                    continue
                try:
                    history_by_id[sha] = parse_iso(uploaded_at)
                except ValueError:
                    log(f"skipping history row with invalid uploaded_at: {sha}")
        else:
            summary["history_seeded"] = True
            log("history.json missing; seeding recency from LastModified")

        recency: dict[str, datetime] = {}
        for release_id in existing:
            if release_id in history_by_id:
                recency[release_id] = history_by_id[release_id]
                continue
            newest = max_last_modified(client, bucket, f"{prefix}{release_id}/")
            if newest is None:
                log(f"empty prefix skipped: {prefix}{release_id}/")
                continue
            recency[release_id] = newest
            summary["history_seeded"] = True

        now = utcnow()
        recency[live_id] = now

        ranked = sorted(recency.items(), key=lambda item: item[1], reverse=True)
        keep: set[str] = {live_id}
        grace_cutoff = now - timedelta(days=grace_days)
        for index, (release_id, uploaded_at) in enumerate(ranked):
            if index < keep_releases:
                keep.add(release_id)
            if uploaded_at >= grace_cutoff:
                keep.add(release_id)

        keep &= set(existing) | {live_id}
        delete = sorted(sha for sha in existing if sha not in keep)
        summary["keep"] = sorted(keep, key=lambda sha: recency.get(sha, now), reverse=True)
        summary["delete"] = delete

        if len(delete) > max_delete:
            summary["skipped_reason"] = "circuit_breaker"
            log(f"circuit breaker: {len(delete)} candidates > max_delete {max_delete}")
            emit(summary)

        if dry_run:
            log("dry-run: no deletes and history.json not written")
            emit(summary)

        deleted_ids: list[str] = []
        for release_id in delete:
            delete_prefix_tree(client, bucket, prefix, release_id, id_re, reserved)
            deleted_ids.append(release_id)
            log(f"deleted prefix {prefix}{release_id}/")

        remaining = [sha for sha in summary["keep"] if sha in existing or sha == live_id]
        remaining = [sha for sha in remaining if sha not in deleted_ids]
        history_payload = {
            "live": live_id,
            "releases": [
                {"sha": sha, "uploaded_at": iso(recency[sha])}
                for sha in remaining
            ],
            "updated_at": iso(now),
            "version": 1,
        }
        put_history(client, bucket, history_key, history_payload)
        summary["deleted"] = deleted_ids
        emit(summary)
    except SystemExit:
        raise
    except (BotoCoreError, ClientError, ValueError, json.JSONDecodeError, OSError) as err:
        log(f"aws/script error: {err}")
        summary["skipped_reason"] = "aws_error"
        summary["error"] = str(err)
        emit(summary)


if __name__ == "__main__":
    main()
