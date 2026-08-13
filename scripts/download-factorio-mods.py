#!/usr/bin/env python3
"""Download latest compatible Factorio Mod Portal releases for headless validation."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile


API_BASE_URL = "https://mods.factorio.com/api/mods"
PORTAL_BASE_URL = "https://mods.factorio.com"
BUILTIN_MODS = {"base", "core", "elevated-rails", "quality", "recycler", "space-age"}
DEPENDENCY_PATTERN = re.compile(r"^\s*(?P<prefix>\(\?\)|[+?!~]?)\s*(?P<name>[^\s<>=]+)")


class DownloadError(RuntimeError):
    pass


def request_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": "afi-ci-mod-downloader/1"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raise DownloadError(f"Mod Portal API request failed with HTTP {error.code}") from error
    except urllib.error.URLError as error:
        raise DownloadError(f"Mod Portal API request failed: {error.reason}") from error


def latest_compatible_release(mod_name: str, factorio_version: str) -> dict:
    response = request_json(f"{API_BASE_URL}/{urllib.parse.quote(mod_name, safe='')}/full")
    releases = [
        release
        for release in response.get("releases", [])
        if release.get("info_json", {}).get("factorio_version") == factorio_version
    ]
    if not releases:
        raise DownloadError(f"No Factorio {factorio_version} release found for {mod_name}")
    return max(releases, key=lambda release: release.get("released_at", ""))


def dependency_names(info_json: dict, include_optional: bool) -> list[str]:
    names: list[str] = []
    for dependency in info_json.get("dependencies", []):
        match = DEPENDENCY_PATTERN.match(dependency)
        if not match:
            raise DownloadError(f"Could not parse dependency declaration: {dependency!r}")
        prefix = match.group("prefix")
        name = match.group("name")
        if name in BUILTIN_MODS or prefix == "!":
            continue
        if prefix in {"?", "(?)"} and not include_optional:
            continue
        names.append(name)
    return names


def read_info_json(info_path: Path) -> dict:
    try:
        info = json.loads(info_path.read_text(encoding="utf-8"))
    except OSError as error:
        raise DownloadError(f"Could not read mod metadata: {info_path}") from error
    except json.JSONDecodeError as error:
        raise DownloadError(f"Could not parse mod metadata: {info_path}") from error
    if not isinstance(info, dict) or not isinstance(info.get("name"), str) or not info["name"]:
        raise DownloadError(f"Mod metadata has no valid name: {info_path}")
    return info


def authenticated_download_url(download_url: str, username: str, token: str) -> str:
    parsed = urllib.parse.urlsplit(urllib.parse.urljoin(PORTAL_BASE_URL, download_url))
    query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    query.extend((("username", username), ("token", token)))
    return urllib.parse.urlunsplit(parsed._replace(query=urllib.parse.urlencode(query)))


def archive_metadata(archive_path: Path) -> dict:
    try:
        with zipfile.ZipFile(archive_path) as archive:
            info_paths = [name for name in archive.namelist() if name == "info.json" or name.endswith("/info.json")]
            if len(info_paths) != 1:
                raise DownloadError(f"{archive_path.name} does not contain exactly one mod info.json")
            return json.loads(archive.read(info_paths[0]).decode("utf-8"))
    except zipfile.BadZipFile as error:
        raise DownloadError(f"Downloaded archive is not a valid ZIP: {archive_path.name}") from error


def download_release(mod_name: str, release: dict, mods_dir: Path, username: str, token: str) -> None:
    filename = Path(release.get("file_name", "")).name
    if not filename.endswith(".zip"):
        raise DownloadError(f"Mod Portal returned an invalid archive name for {mod_name}")
    release_version = release.get("version") or release.get("info_json", {}).get("version")
    if not release_version:
        raise DownloadError(f"Mod Portal returned no version for {mod_name}")
    destination = mods_dir / filename
    if destination.exists():
        metadata = archive_metadata(destination)
        if metadata.get("name") == mod_name and metadata.get("version") == release_version:
            print(f"Using {mod_name} {release_version}")
            return
        raise DownloadError(f"Existing archive has unexpected metadata: {destination.name}")

    download_url = authenticated_download_url(release["download_url"], username, token)
    request = urllib.request.Request(download_url, headers={"User-Agent": "afi-ci-mod-downloader/1"})
    temporary_path: Path | None = None
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            with tempfile.NamedTemporaryFile(dir=mods_dir, suffix=".part", delete=False) as temporary_file:
                temporary_path = Path(temporary_file.name)
                shutil.copyfileobj(response, temporary_file)
        metadata = archive_metadata(temporary_path)
        if metadata.get("name") != mod_name or metadata.get("version") != release_version:
            raise DownloadError(f"Downloaded archive metadata does not match {mod_name} {release_version}")
        temporary_path.replace(destination)
        temporary_path = None
        print(f"Downloaded {mod_name} {release_version}")
    except urllib.error.HTTPError as error:
        raise DownloadError(f"Mod download failed for {mod_name} with HTTP {error.code}") from error
    except urllib.error.URLError as error:
        raise DownloadError(f"Mod download failed for {mod_name}: {error.reason}") from error
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def download_mod_closure(
    mod_name: str,
    *,
    factorio_version: str,
    include_dependencies: bool,
    include_optional_dependencies: bool,
    mods_dir: Path,
    username: str,
    token: str,
    visited: set[str],
) -> None:
    if mod_name in visited:
        return
    visited.add(mod_name)
    release = latest_compatible_release(mod_name, factorio_version)
    if include_dependencies:
        for dependency in dependency_names(release.get("info_json", {}), include_optional_dependencies):
            download_mod_closure(
                dependency,
                factorio_version=factorio_version,
                include_dependencies=True,
                include_optional_dependencies=include_optional_dependencies,
                mods_dir=mods_dir,
                username=username,
                token=token,
                visited=visited,
            )
    download_release(mod_name, release, mods_dir, username, token)


def download_info_dependency_closure(
    info: dict,
    *,
    factorio_version: str,
    mods_dir: Path,
    username: str,
    token: str,
) -> None:
    # Only the dependencies declared directly on `info` are downloaded.
    # Deliberately not recursive: a downloaded dependency's own
    # optional/recommended/hidden-optional dependencies are not pulled in,
    # since that graph can reach arbitrarily far across the Mod Portal (e.g.
    # a hidden-optional compatibility shim several hops away with no
    # Factorio-version-compatible release).
    visited = {info["name"]}
    for dependency in dependency_names(info, include_optional=True):
        download_mod_closure(
            dependency,
            factorio_version=factorio_version,
            include_dependencies=False,
            include_optional_dependencies=True,
            mods_dir=mods_dir,
            username=username,
            token=token,
            visited=visited,
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download latest compatible Mod Portal releases into a Factorio mods directory."
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--mod", action="append", help="Mod Portal name to download; repeatable.")
    source.add_argument(
        "--from-info",
        type=Path,
        help="Read a local info.json and recursively download its complete dependency closure.",
    )
    parser.add_argument("--mods-dir", required=True, type=Path, help="Destination Factorio mods directory.")
    parser.add_argument(
        "--factorio-version",
        help="Factorio version to select (defaults to local metadata or 2.1).",
    )
    parser.add_argument(
        "--with-dependencies",
        action="store_true",
        help="Recursively download required and recommended Mod Portal dependencies.",
    )
    parser.add_argument(
        "--include-optional-dependencies",
        action="store_true",
        help="Include optional dependencies when used with --mod --with-dependencies.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.include_optional_dependencies and not (args.with_dependencies or args.from_info):
        raise DownloadError("--include-optional-dependencies requires --with-dependencies or --from-info")
    username = os.environ.get("FACTORIO_MOD_PORTAL_USERNAME")
    token = os.environ.get("FACTORIO_MOD_PORTAL_TOKEN")
    if not username or not token:
        raise DownloadError(
            "FACTORIO_MOD_PORTAL_USERNAME and FACTORIO_MOD_PORTAL_TOKEN must be set in the environment"
        )
    args.mods_dir.mkdir(parents=True, exist_ok=True)
    if args.from_info:
        info = read_info_json(args.from_info)
        factorio_version = args.factorio_version or info.get("factorio_version", "2.1")
        download_info_dependency_closure(
            info,
            factorio_version=factorio_version,
            mods_dir=args.mods_dir,
            username=username,
            token=token,
        )
    else:
        factorio_version = args.factorio_version or "2.1"
        visited: set[str] = set()
        for mod_name in args.mod:
            download_mod_closure(
                mod_name,
                factorio_version=factorio_version,
                include_dependencies=args.with_dependencies,
                include_optional_dependencies=args.include_optional_dependencies,
                mods_dir=args.mods_dir,
                username=username,
                token=token,
                visited=visited,
            )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except DownloadError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
