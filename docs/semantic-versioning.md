# Semantic Versioning Policy

Pollution Reclamation uses Semantic Versioning in `MAJOR.MINOR.PATCH` form, with the additional pre-`1.0.0` rules below for gameplay and prototype changes.

The canonical version is `src/info.json` field `version`. Release notes for that exact version must be the first entry in `src/changelog.txt`.

The current release automation creates release artifacts and publishes the GitHub release when a merge to `main` changes `src/info.json` version compared to the previous `main` commit. A version bump is therefore the normal deployment trigger. The main workflow may also retry missing public publication for the current version when a local Gitea release already exists but GitHub Releases does not list that version.

## Version Meaning

### Patch

Use a patch bump for compatible fixes that do not change expected progression, saved-game behavior, dependencies, or public prototype contracts.

Examples:

- Fixing a typo, locale text, changelog wording, or documentation.
- Fixing packaging, CI, or release automation without changing mod behavior.
- Correcting a prototype bug where the intended behavior was already clear.
- Compatibility cleanup that preserves the same unlocked entities and progression shape.

### Minor

Use a minor bump for compatible gameplay additions or balance changes that keep existing saves, dependencies, and public prototype names usable.

Examples:

- Adding a new filter, recipe, technology, or compatibility path.
- Changing progression numbers such as filtering efficiency, energy usage, recipe cost, prerequisites, or unlock timing.
- Adding new optional mod compatibility.
- Expanding Space Age environment support without removing existing behavior.

During `0.x` development, minor bumps are also the default for meaningful gameplay or prototype-surface changes, even when those changes might later be considered breaking after `1.0.0`.

### Major

Use a major bump for breaking changes after `1.0.0`.

Examples:

- Removing or renaming public prototype names.
- Removing technologies, recipes, items, entities, or locale keys that other mods or saves may reference.
- Changing dependency requirements in a way that prevents existing valid installs from loading.
- Introducing migrations that intentionally invalidate or substantially reshape existing saves.

Before `1.0.0`, breaking changes should normally advance the minor version, not the major version. For example, `0.1.0` to `0.2.0`.

## Release Procedure

1. Complete ordinary implementation on `feature/*` branches merged back to `dev`.
2. Decide the version bump before creating the release branch.
3. Update `src/info.json` to the new `MAJOR.MINOR.PATCH` version.
4. Add a new top entry to `src/changelog.txt` for the same version using Factorio's changelog format.
5. Keep the changelog entry focused on player-visible changes, compatibility changes, packaging/release changes, and migration risks.
6. Create a short-lived versioned branch from `dev`, such as `release/0.1.1`; do not open recurring `dev -> main` pull requests.
7. Run:

   ```sh
   ./scripts/validate.sh
   ./scripts/package.sh
   ```

8. Confirm the package name is `{mod-name}_{version}.zip`.
9. Open and merge the release pull request from the release branch to `main`.
10. The Gitea main workflow validates the mod, detects the version bump, packages the mod, and creates or updates the `v{version}` Gitea and GitHub releases.
11. Delete the release branch after merge and bring `main` ancestry back into `dev`.

## Non-Release Changes

Changes that should not produce a release must not change `src/info.json` version. They may still update documentation, CI, governance, or development files.

When a non-release change merges to `main`, the main workflow validates the mod but skips packaging, tagging, and release creation because the version did not change.

## Version Consistency Rules

- `src/info.json` must contain only `MAJOR.MINOR.PATCH`.
- The first `Version:` entry in `src/changelog.txt` must match `src/info.json`.
- Release tags use `v{version}`, for example `v0.1.0`.
- Release zip files use `{mod-name}_{version}.zip`, for example `pollution-reclamation_0.1.0.zip`.
- Do not reuse a released version for different mod contents except to repair a failed release artifact before public distribution.
