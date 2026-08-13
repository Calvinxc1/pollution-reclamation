#!/usr/bin/env python3
import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


class ApiError(RuntimeError):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body}")
        self.status = status
        self.body = body


def fail(message: str, status: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(status)


def api_request(
    base_url: str,
    token: str,
    method: str,
    path: str,
    *,
    body: bytes | None = None,
    headers: dict[str, str] | None = None,
) -> dict | None:
    request_headers = {
        "Authorization": f"token {token}",
        "Accept": "application/json",
    }
    if headers:
        request_headers.update(headers)

    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/v1{path}",
        data=body,
        headers=request_headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
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


def multipart_file_body(field_name: str, file_path: Path) -> tuple[bytes, str]:
    boundary = f"----afi-{uuid.uuid4().hex}"
    content_type = mimetypes.guess_type(file_path.name)[0] or "application/zip"
    header = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="{field_name}"; filename="{file_path.name}"\r\n'
        f"Content-Type: {content_type}\r\n\r\n"
    ).encode("utf-8")
    footer = f"\r\n--{boundary}--\r\n".encode("utf-8")
    return header + file_path.read_bytes() + footer, boundary


def release_by_tag(base_url: str, token: str, repo: str, tag: str) -> dict | None:
    encoded_tag = urllib.parse.quote(tag, safe="")
    try:
        return api_request(base_url, token, "GET", f"/repos/{repo}/releases/tags/{encoded_tag}")
    except ApiError as error:
        if error.status == 404:
            return None
        raise


def create_release(args: argparse.Namespace, token: str) -> dict:
    existing = release_by_tag(args.server_url, token, args.repo, args.tag)
    if existing:
        print(f"Using existing release {args.tag}.")
        return existing

    payload = {
        "tag_name": args.tag,
        "target_commitish": args.target,
        "name": args.title,
        "body": args.body_file.read_text(encoding="utf-8") if args.body_file else "",
        "draft": False,
        "prerelease": False,
    }

    try:
        release = api_request(
            args.server_url,
            token,
            "POST",
            f"/repos/{args.repo}/releases",
            body=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
    except ApiError as error:
        if error.status == 409:
            release = release_by_tag(args.server_url, token, args.repo, args.tag)
            if release:
                print(f"Using release {args.tag} created by another run.")
                return release
        raise

    if not release or "id" not in release:
        fail(f"Create release did not return a release id: {release}")

    print(f"Created release {args.tag}.")
    return release


def delete_existing_asset(base_url: str, token: str, repo: str, release: dict, asset_name: str) -> None:
    for asset in release.get("assets", []):
        if asset.get("name") != asset_name:
            continue
        asset_id = asset.get("id")
        if asset_id is None:
            fail(f"Existing asset has no id: {asset}")
        api_request(
            base_url,
            token,
            "DELETE",
            f"/repos/{repo}/releases/{release['id']}/assets/{asset_id}",
        )
        print(f"Deleted existing release asset {asset_name}.")


def upload_asset(args: argparse.Namespace, token: str, release: dict) -> None:
    upload_body, boundary = multipart_file_body("attachment", args.asset)
    encoded_name = urllib.parse.quote(args.asset.name)
    response = api_request(
        args.server_url,
        token,
        "POST",
        f"/repos/{args.repo}/releases/{release['id']}/assets?name={encoded_name}",
        body=upload_body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    if not response or response.get("name") != args.asset.name:
        fail(f"Upload did not return expected asset: {response}")
    print(f"Uploaded release asset {args.asset.name}.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a Gitea release and attach a package zip.")
    parser.add_argument("--server-url", required=True)
    parser.add_argument("--repo", required=True, help="owner/repo")
    parser.add_argument("--tag", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--asset", required=True, type=Path)
    parser.add_argument("--body-file", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    token = os.environ.get("GITEA_RELEASE_TOKEN")
    if not token:
        fail("GITEA_RELEASE_TOKEN is required.")
    if not args.asset.is_file():
        fail(f"Release asset not found: {args.asset}")
    if args.body_file and not args.body_file.is_file():
        fail(f"Release body file not found: {args.body_file}")

    try:
        release = create_release(args, token)
        delete_existing_asset(args.server_url, token, args.repo, release, args.asset.name)
        upload_asset(args, token, release)
    except ApiError as error:
        fail(str(error))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
