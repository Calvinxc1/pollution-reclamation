#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


DISCORD_DESCRIPTION_LIMIT = 4096


class ApiError(RuntimeError):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body}")
        self.status = status
        self.body = body


def fail(message: str, status: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(status)


def add_wait_query(webhook_url: str) -> str:
    parsed = urllib.parse.urlsplit(webhook_url)
    query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    if not any(key == "wait" for key, _ in query):
        query.append(("wait", "true"))
    return urllib.parse.urlunsplit(parsed._replace(query=urllib.parse.urlencode(query)))


def extract_changelog_section(changelog: str, version: str) -> str:
    lines = changelog.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line.strip() == f"Version: {version}":
            start = index
            break

    if start is None:
        fail(f"Could not find changelog section for version {version}.")

    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].strip().startswith("Version: "):
            end = index
            break
        if lines[index].startswith("-" * 10) and index > start:
            end = index
            break

    section = "\n".join(lines[start:end]).strip()
    if not section:
        fail(f"Changelog section for version {version} is empty.")
    return section


def changelog_code_block(text: str) -> str:
    overhead = len("```text\n\n```")
    limit = DISCORD_DESCRIPTION_LIMIT - overhead
    if len(text) > limit:
        fail(
            "Changelog section is too long for one Discord embed description "
            f"({len(text)} > {limit} characters)."
        )
    return f"```text\n{text}\n```"


def build_payload(args: argparse.Namespace, section: str) -> dict:
    portal_url = args.portal_url or f"https://mods.factorio.com/mod/{args.mod_name}"
    previous_version = args.previous_version or "initial"
    return {
        "username": "Pollution Reclamation Releases",
        "allowed_mentions": {"parse": []},
        "embeds": [
            {
                "title": f"{args.mod_title} {previous_version} -> {args.version}",
                "url": portal_url,
                "description": changelog_code_block(section),
                "color": 3447003,
            }
        ],
    }


def post_webhook(webhook_url: str, payload: dict) -> None:
    request = urllib.request.Request(
        add_wait_query(webhook_url),
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "pollution-reclamation-release",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            response.read()
    except urllib.error.HTTPError as error:
        error_body = error.read().decode("utf-8", errors="replace")
        raise ApiError(error.code, error_body) from error
    except urllib.error.URLError as error:
        fail(f"Discord webhook request failed: {error}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Post a release changelog section to Discord.")
    parser.add_argument("--mod-name", required=True)
    parser.add_argument("--mod-title", required=True)
    parser.add_argument("--previous-version", default=os.environ.get("PREVIOUS_MOD_VERSION", ""))
    parser.add_argument("--version", required=True)
    parser.add_argument("--changelog-file", required=True, type=Path)
    parser.add_argument("--portal-url")
    parser.add_argument("--webhook-url", default=os.environ.get("DISCORD_RELEASE_WEBHOOK_URL"))
    parser.add_argument("--dry-run", action="store_true", help="Print the Discord payload without posting.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.changelog_file.is_file():
        fail(f"Changelog file not found: {args.changelog_file}")

    section = extract_changelog_section(args.changelog_file.read_text(encoding="utf-8"), args.version)
    payload = build_payload(args, section)

    if args.dry_run:
        print(json.dumps(payload, indent=2))
        return 0

    if not args.webhook_url:
        fail("DISCORD_RELEASE_WEBHOOK_URL is required to post release notes.")

    try:
        post_webhook(args.webhook_url, payload)
    except ApiError as error:
        fail(f"Discord webhook post failed: {error}")

    print(f"Posted Discord release changelog for {args.mod_name} {args.version}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
