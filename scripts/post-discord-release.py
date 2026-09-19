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

# What is left for the changelog itself once the code fence is wrapped around it.
CHANGELOG_CHUNK_LIMIT = DISCORD_DESCRIPTION_LIMIT - len("```text\n\n```")


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
    return f"```text\n{text}\n```"


def split_section(section: str, limit: int = CHANGELOG_CHUNK_LIMIT) -> list:
    """Split a changelog section into parts that each fit one embed description.

    Splits on category boundaries first -- "  Bugfixes:" and friends -- so a
    part never begins mid-bullet. A single category larger than the limit is
    split again on bullet boundaries, and a single bullet larger than the limit
    is split on lines as a last resort, which is the only case that can break a
    sentence.

    Discord caps one embed description at 4096 characters and all embeds in a
    message at 6000 together, so a long section cannot be delivered as several
    embeds in one message. Each part becomes its own message instead.
    """
    if len(section) <= limit:
        return [section]

    def blocks(text):
        """Group lines under the category header they belong to."""
        grouped, current = [], []
        for line in text.split("\n"):
            is_header = (
                line.startswith("  ")
                and not line.startswith("    ")
                and line.rstrip().endswith(":")
            )
            if is_header and current:
                grouped.append("\n".join(current))
                current = []
            current.append(line)
        if current:
            grouped.append("\n".join(current))
        return grouped

    def split_line(line):
        """A single line longer than a whole embed. Cut it into limit-sized runs."""
        return [line[at:at + limit] for at in range(0, len(line), limit)]

    def split_oversized(block):
        """A category too large on its own: break it on bullets, then on lines."""
        pieces, current = [], []

        def flush():
            if current:
                pieces.append("\n".join(current))
                current.clear()

        for line in block.split("\n"):
            if len(line) > limit:
                flush()
                pieces.extend(split_line(line))
                continue

            candidate = "\n".join(current + [line])
            if current and len(candidate) > limit:
                flush()
                current.append(line)
            else:
                current.append(line)

        flush()
        return pieces

    parts, current = [], ""
    for block in blocks(section):
        if len(block) > limit:
            if current:
                parts.append(current)
                current = ""
            parts.extend(split_oversized(block))
            continue

        candidate = f"{current}\n{block}" if current else block
        if len(candidate) > limit:
            parts.append(current)
            current = block
        else:
            current = candidate

    if current:
        parts.append(current)
    return parts


def build_payloads(args: argparse.Namespace, section: str) -> list:
    """One payload per message. Long sections are delivered as several."""
    portal_url = args.portal_url or f"https://mods.factorio.com/mod/{args.mod_name}"
    previous_version = args.previous_version or "initial"
    parts = split_section(section)
    total = len(parts)

    payloads = []
    for index, part in enumerate(parts, start=1):
        title = f"{args.mod_title} {previous_version} -> {args.version}"
        if total > 1:
            title = f"{title} ({index}/{total})"
        payloads.append({
            "username": "Pollution Reclamation Releases",
            "allowed_mentions": {"parse": []},
            "embeds": [
                {
                    "title": title,
                    "url": portal_url,
                    "description": changelog_code_block(part),
                    "color": 3447003,
                }
            ],
        })
    return payloads


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
    payloads = build_payloads(args, section)

    if args.dry_run:
        print(json.dumps(payloads, indent=2))
        return 0

    if not args.webhook_url:
        fail("DISCORD_RELEASE_WEBHOOK_URL is required to post release notes.")

    # Posted in order and one at a time: Discord does not guarantee ordering
    # between concurrent webhook posts, and a numbered part arriving out of
    # sequence is worse than a slow post.
    for index, payload in enumerate(payloads, start=1):
        try:
            post_webhook(args.webhook_url, payload)
        except ApiError as error:
            fail(
                f"Discord webhook post failed on part {index} of {len(payloads)}: {error}"
            )

    if len(payloads) > 1:
        print(
            f"Posted Discord release changelog for {args.mod_name} {args.version} "
            f"in {len(payloads)} messages."
        )
    else:
        print(f"Posted Discord release changelog for {args.mod_name} {args.version}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
