# Contributing

Contributions are welcome through pull requests against the `dev` branch.

Create ordinary implementation work on short-lived `feature/*` branches from `dev`, then open pull requests back to `dev`. Do not base feature branches on other feature branches, do not target feature pull requests at other feature branches, and do not commit ordinary feature work directly on `dev`.

Before opening a pull request, run:

```sh
./scripts/validate.sh
```

For release packaging checks, also run:

```sh
./scripts/package.sh
```

Versioning rules are documented in [docs/semantic-versioning.md](docs/semantic-versioning.md). Pull requests that change released mod behavior should state whether they require a patch, minor, or major bump.

## Scope

Pollution Reclamation owns the pollution condenser and pollution vaporizer buildings, polluted water and solvent fluids, pollution filter items and recipes, filter restoration, and the pollution technologies for Factorio 2.1.

Keep changes focused on that scope. Compatibility fixes are welcome when they preserve the mod's existing recipes and progression and do not move unrelated gameplay systems into this repository.

## Translations

The mod ships in English only for now. Versions 0.1.x also shipped a French translation, but that came in with the source reconstructed from the released KrastorioAirPurifier mod, which itself descends from Krastorio 2. Nobody maintaining this repository speaks French, so that text couldn't be checked, and it could not have been kept accurate as names and descriptions changed. It was removed rather than shipped unverified.

Translations are welcome from people fluent in the language. Add a `src/locale/<language-code>/strings.cfg` that mirrors the keys in `src/locale/en/strings.cfg`, and open a pull request against `dev`. Please say in the pull request that you are fluent in the language, since the maintainers can't review the wording themselves.

## AI-Assisted Contributions

This repository permits AI-assisted work. Contributions should still be reviewed, tested, and explained like any other change.

The `.governance/` directory is intentionally public. It documents the guardrails used for AI-assisted development in this repository, including task scoping, validation expectations, release discipline, and review posture.

## Release Discipline

Do not publish, tag, upload to the Factorio mod portal, or modify release automation as part of a contribution unless the pull request is explicitly about release work.

Version changes belong in `src/info.json` and should be paired with `src/changelog.txt` updates.

Promotions to `main` must use a short-lived `release/*` branch created from `dev`. Do not open recurring pull requests directly from `dev` to `main`.

Urgent release-line fixes use short-lived `hotfix/*` branches from `main`. After a hotfix reaches `main`, sync the fix back to `dev` and evaluate any active release branch for the same fix.
