# Release Process

This document is for maintainers. Public users do not need access to the release automation infrastructure to install or use the mod.

The local Gitea instance is the source of truth for release automation. It is private infrastructure and is not expected to be publicly accessible.

GitHub is the public mirror. Public consumers should use the GitHub repository release artifacts rather than assuming access to the local Gitea server.

The mod version is defined in `src/info.json`. Release notes live in `src/changelog.txt` using the Factorio mod portal changelog format.

Versioning policy is documented in [semantic-versioning.md](semantic-versioning.md). The top changelog entry must match the `src/info.json` version.

## Factorio Mod Portal Status

Unlike the other New Eden Workshop mods, this mod is not yet published to the Factorio Mod Portal. `KrastorioAirPurifier` is already taken by the mod this repository continues from, so Pollution Reclamation needs its own portal listing under Jason's account before mod portal upload can be enabled here.

`deploy.yml` therefore only creates Gitea and GitHub releases for now. The `upload-factorio-mod-portal.py` and `post-discord-release.py` steps used by the other family mods are not wired into this repository's workflow yet. Add them back, following the [advanced-fluid-infrastructure](https://gitea.infra.newedenhomestead.net/factorio-modding/advanced-fluid-infrastructure) `deploy.yml` as a reference, once a portal listing exists and `FACTORIO_MOD_PORTAL_TOKEN` (and optionally `DISCORD_RELEASE_WEBHOOK_URL`) are configured.

## Branch Model

This repository uses a full GitFlow model:

- `dev` is the long-lived integration branch.
- `main` is the release branch.
- `feature/*` branches are short-lived implementation branches created from `dev` and merged back to `dev`.
- Release promotion uses short-lived `release/*` branches created from `dev`.
- `hotfix/*` branches are short-lived urgent-fix branches created from `main`, then merged or cherry-picked back to `dev` and any active release branch that needs the fix.

Do not commit ordinary implementation work directly on `dev`. Use this feature branch shape:

```text
dev -> feature/<topic> -> dev
```

Do not open recurring pull requests directly from `dev` to `main`. This Gitea instance keeps merged pull requests associated with their live head/base branch pair, so reusing `dev -> main` can block future pull requests after the first merge.

Use this promotion shape instead:

```text
dev -> release/<version-or-purpose> -> main
```

Example release branch names:

```text
release/0.1.1
release/0.2.0
release/public-readiness
release/docs-refresh
release/ci-maintenance
```

Use version-numbered release branches only when `src/info.json` is changing for a new mod release. Use purpose-named release branches for documentation, governance, CI, or other non-release promotions.

Use hotfix branches only for urgent fixes that must start from the current release line:

```text
main -> hotfix/<version-or-topic> -> main -> dev
```

When a hotfix lands on `main`, sync it back to `dev` before ordinary feature work continues. If a release branch is active, evaluate whether that branch also needs the hotfix.

## Local Checks

Run the full validation entrypoint before opening a release PR:

```sh
./scripts/validate.sh
```

Build the upload package locally with:

```sh
./scripts/package.sh
```

The package is written to `dist/` and named `{mod-name}_{version}.zip`.

## Feature Branch Procedure

For ordinary implementation work:

1. Ensure local `dev` is current.
2. Create a feature branch from `dev`:

   ```sh
   git checkout dev
   git pull --ff-only origin dev
   git checkout -b feature/<topic>
   ```

3. Commit the scoped change on `feature/<topic>`.
4. Run the appropriate validation, normally `./scripts/validate.sh`.
5. Before opening the pull request, confirm the feature branch is based on `origin/dev`:

   ```sh
   git fetch origin dev
   test "$(git merge-base HEAD origin/dev)" = "$(git rev-parse origin/dev)"
   ```

6. Open a pull request from `feature/<topic>` to `dev`. Do not target another `feature/*` branch.
7. Merge after review and validation.
8. Delete the feature branch after merge.

## Release Branch Procedure

When `dev` is ready to promote:

1. Ensure local `main` and `dev` are current.
2. Create a release branch from `dev`:

   ```sh
   git checkout dev
   git pull --ff-only origin dev
   git checkout -b release/<version-or-purpose>
   git push origin release/<version-or-purpose>
   ```

3. Open a pull request from `release/<version-or-purpose>` to `main`.
4. Confirm CI passes.
5. Merge the release PR into `main`.
6. Delete the release branch after merge.
7. Merge or fast-forward `main` back into `dev` so `dev` contains the release merge ancestry.

## Hotfix Procedure

Use hotfix branches only when the fix must start from the current `main` release line:

1. Ensure local `main` is current.
2. Create a hotfix branch from `main`:

   ```sh
   git checkout main
   git pull --ff-only origin main
   git checkout -b hotfix/<version-or-topic>
   ```

3. Apply the fix, version, and changelog changes required for the hotfix.
4. Run `./scripts/validate.sh` and any release-specific checks.
5. Open a pull request from `hotfix/<version-or-topic>` to `main`.
6. After the hotfix reaches `main`, merge or cherry-pick the same fix back to `dev`.
7. If a `release/*` branch is active, evaluate whether it must receive the hotfix before closing the work.

## Main Validation and Release

The Gitea main workflow runs on pushes to `main`.

It always validates the mod. It compares the current `src/info.json` version to the previous `main` version, then packages and publishes the mod only when the version changed.

This means a version bump is the normal deployment trigger. Changes merged to `main` without a version bump are validated but do not create a package, tag, Gitea release, or GitHub release unless the current version already has a local Gitea release and GitHub Releases is missing that version.

Expected non-release promotion path:

```text
dev -> release/public-readiness -> main
```

Expected versioned release path:

```text
dev -> release/0.1.1 -> main
```

The workflow uses the built-in Gitea Actions token:

```text
${{ secrets.GITEA_TOKEN }}
```

The workflow requests:

```yaml
permissions:
  contents: read
  releases: write
```

No separate local Gitea release token is required unless repository or owner Actions settings clamp the built-in token below `releases: write`.

Release artifacts created in local Gitea are also published to the public GitHub mirror so public users do not need access to private Gitea URLs.

## GitHub Release Upload

The version-bump release path creates or updates a matching GitHub release in the public mirror repository after the local Gitea release is created.

The workflow requires this repository secret:

```text
GH_RELEASE_TOKEN
```

Use a GitHub fine-grained personal access token scoped to the public mirror repository:

```text
Calvinxc1/pollution-reclamation
```

The token must have repository `Contents` permission set to `Read and write`. GitHub's release API uses repository contents permission for creating releases and uploading release assets.

Do not name the secret with a `GITHUB_` prefix. Gitea and GitHub Actions reserve that prefix for built-in runtime values, so the workflow uses `GH_RELEASE_TOKEN`.

The workflow target repository is configured as:

```text
GITHUB_RELEASE_REPOSITORY=Calvinxc1/pollution-reclamation
```

**This GitHub mirror repository does not exist yet.** Create it (public, matching the family's mirror pattern) before relying on this step, or `deploy.yml`'s GitHub release step will fail on the first real release.

The upload helper waits for the mirrored commit to become visible on GitHub before creating the release, then attaches the same package zip used for the local Gitea release.

The upload helper is:

```sh
./scripts/create-github-release.py --repo "$GITHUB_RELEASE_REPOSITORY" --tag "v$MOD_VERSION" --target "$RELEASE_TARGET" --title "$MOD_NAME $MOD_VERSION" --body-file src/changelog.txt --asset "$PACKAGE_PATH"
```

Do not run this helper manually unless intentionally publishing or repairing a GitHub release for the version in `src/info.json`.

## Factorio Mod Portal Upload

Not yet enabled for this repository. See [Factorio Mod Portal Status](#factorio-mod-portal-status) above.

## Discord Release Announcement

Not yet enabled for this repository. See [Factorio Mod Portal Status](#factorio-mod-portal-status) above.
