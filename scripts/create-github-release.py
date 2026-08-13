#!/usr/bin/env python3
import argparse
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


GITHUB_API_URL = "https://api.github.com"
GITHUB_UPLOADS_URL = "https://uploads.github.com"
GITHUB_API_VERSION = "2022-11-28"

# GitHub has been observed to create the underlying git tag as a side effect of
# a release-creation POST, then reject that same call with 422 "Published
# releases must have a valid tag" -- apparently a tag/commit indexing race on
# GitHub's end, not anything wrong with the request. A short retry clears it.
INVALID_TAG_RETRY_ATTEMPTS = 5
INVALID_TAG_RETRY_DELAY_SECONDS = 10


class ApiError(RuntimeError):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body}")
        self.status = status
        self.body = body


def fail(message: str, status: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(status)


def api_request(
    token: str,
    method: str,
    url: str,
    *,
    body: bytes | None = None,
    headers: dict[str, str] | None = None,
) -> dict | list | None:
    request_headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": GITHUB_API_VERSION,
    }
    if headers:
        request_headers.update(headers)

    request = urllib.request.Request(url, data=body, headers=request_headers, method=method)

    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            response_body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        error_body = error.read().decode("utf-8", errors="replace")
        raise ApiError(error.code, error_body) from error
    except urllib.error.URLError as error:
        fail(f"Request failed: {error}")

    if not response_body:
        return None

    try:
        return json.loads(response_body)
    except json.JSONDecodeError as error:
        fail(f"Expected JSON response, got: {response_body}\n{error}")


def github_url(path: str) -> str:
    return f"{GITHUB_API_URL}{path}"


def upload_url(path: str) -> str:
    return f"{GITHUB_UPLOADS_URL}{path}"


def release_by_tag(token: str, repo: str, tag: str) -> dict | None:
    encoded_tag = urllib.parse.quote(tag, safe="")
    try:
        response = api_request(token, "GET", github_url(f"/repos/{repo}/releases/tags/{encoded_tag}"))
    except ApiError as error:
        if error.status == 404:
            return None
        raise

    if not isinstance(response, dict):
        fail(f"Release lookup did not return an object: {response}")
    return response


def wait_for_commit(token: str, repo: str, target: str, attempts: int, delay_seconds: int) -> None:
    encoded_target = urllib.parse.quote(target, safe="")
    for attempt in range(1, attempts + 1):
        try:
            api_request(token, "GET", github_url(f"/repos/{repo}/commits/{encoded_target}"))
            print(f"GitHub mirror has target commit {target}.")
            return
        except ApiError as error:
            if error.status != 404 or attempt == attempts:
                raise
            print(
                f"GitHub mirror does not have {target} yet; retrying "
                f"({attempt}/{attempts})."
            )
            time.sleep(delay_seconds)


def _is_invalid_tag_error(error: ApiError) -> bool:
    if error.status != 422:
        return False
    try:
        body = json.loads(error.body)
    except json.JSONDecodeError:
        return False
    return any(
        "valid tag" in str(entry.get("message", ""))
        for entry in body.get("errors", [])
        if isinstance(entry, dict)
    )


def create_or_update_release(args: argparse.Namespace, token: str) -> dict:
    body = args.body_file.read_text(encoding="utf-8") if args.body_file else ""
    existing = release_by_tag(token, args.repo, args.tag)
    payload = {
        "tag_name": args.tag,
        "target_commitish": args.target,
        "name": args.title,
        "body": body,
        "draft": False,
        "prerelease": False,
    }

    if existing:
        release_id = existing.get("id")
        if release_id is None:
            fail(f"Existing release has no id: {existing}")
        response = api_request(
            token,
            "PATCH",
            github_url(f"/repos/{args.repo}/releases/{release_id}"),
            body=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        if not isinstance(response, dict) or "id" not in response:
            fail(f"Update release did not return a release id: {response}")
        print(f"Updated GitHub release {args.tag}.")
        return response

    for attempt in range(1, INVALID_TAG_RETRY_ATTEMPTS + 1):
        try:
            response = api_request(
                token,
                "POST",
                github_url(f"/repos/{args.repo}/releases"),
                body=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
        except ApiError as error:
            release = release_by_tag(token, args.repo, args.tag)
            if release:
                print(f"Using GitHub release {args.tag} created by another run.")
                return release
            if _is_invalid_tag_error(error) and attempt < INVALID_TAG_RETRY_ATTEMPTS:
                print(
                    f"GitHub rejected tag {args.tag!r} as invalid on attempt "
                    f"{attempt}/{INVALID_TAG_RETRY_ATTEMPTS} (likely tag/commit "
                    f"indexing lag on GitHub's end); retrying."
                )
                time.sleep(INVALID_TAG_RETRY_DELAY_SECONDS)
                continue
            raise
        else:
            break

    if not isinstance(response, dict) or "id" not in response:
        fail(f"Create release did not return a release id: {response}")

    print(f"Created GitHub release {args.tag}.")
    return response


def release_assets(token: str, repo: str, release: dict) -> list[dict]:
    release_id = release.get("id")
    if release_id is None:
        fail(f"Release has no id: {release}")

    response = api_request(
        token,
        "GET",
        github_url(f"/repos/{repo}/releases/{release_id}/assets?per_page=100"),
    )
    if not isinstance(response, list):
        fail(f"List assets did not return a list: {response}")
    return response


def delete_existing_asset(token: str, repo: str, release: dict, asset_name: str) -> None:
    for asset in release_assets(token, repo, release):
        if asset.get("name") != asset_name:
            continue
        asset_id = asset.get("id")
        if asset_id is None:
            fail(f"Existing asset has no id: {asset}")
        api_request(
            token,
            "DELETE",
            github_url(f"/repos/{repo}/releases/assets/{asset_id}"),
        )
        print(f"Deleted existing GitHub release asset {asset_name}.")


def upload_asset(args: argparse.Namespace, token: str, release: dict) -> None:
    release_id = release.get("id")
    if release_id is None:
        fail(f"Release has no id: {release}")

    encoded_name = urllib.parse.quote(args.asset.name)
    content_type = mimetypes.guess_type(args.asset.name)[0] or "application/zip"
    response = api_request(
        token,
        "POST",
        upload_url(f"/repos/{args.repo}/releases/{release_id}/assets?name={encoded_name}"),
        body=args.asset.read_bytes(),
        headers={
            "Content-Type": content_type,
            "Accept": "application/vnd.github+json",
        },
    )
    if not isinstance(response, dict) or response.get("name") != args.asset.name:
        fail(f"Upload did not return expected asset: {response}")
    print(f"Uploaded GitHub release asset {args.asset.name}.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a GitHub release and attach a package zip.")
    parser.add_argument("--repo", required=True, help="owner/repo")
    parser.add_argument("--tag", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--asset", required=True, type=Path)
    parser.add_argument("--body-file", type=Path)
    parser.add_argument("--mirror-wait-attempts", type=int, default=12)
    parser.add_argument("--mirror-wait-seconds", type=int, default=10)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    token = os.environ.get("GH_RELEASE_TOKEN")
    if not token:
        fail("GH_RELEASE_TOKEN is required.")
    if not args.asset.is_file():
        fail(f"Release asset not found: {args.asset}")
    if args.body_file and not args.body_file.is_file():
        fail(f"Release body file not found: {args.body_file}")

    try:
        wait_for_commit(token, args.repo, args.target, args.mirror_wait_attempts, args.mirror_wait_seconds)
        release = create_or_update_release(args, token)
        delete_existing_asset(token, args.repo, release, args.asset.name)
        upload_asset(args, token, release)
    except ApiError as error:
        fail(str(error))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
