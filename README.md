# Pollution Reclamation

Pollution Reclamation is a Factorio 2.1 mod that turns pollution into something you manage rather than only minimise: capture it from the air as a fluid, vent it somewhere else, or trap it in filters.

## Origin

This mod continues an independent line of [KrastorioAirPurifier](https://mods.factorio.com/mod/KrastorioAirPurifier) by Tarckmhog, itself a port of the air purifier from [Krastorio 2](https://mods.factorio.com/mod/Krastorio2) by raiguard, Krastor, and Linver. KrastorioAirPurifier has no public source repository and its author has no other public contact channel, so this repository is a from-scratch reconstruction of the released mod rather than a git fork, kept going as an independent mod under a new name and namespace.

## Requirements

- Factorio 2.1.
- English only for now. Translations from fluent speakers are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md#translations).
- Space Age is optional. The mod plays the same with or without it. It works with Nauvis pollution only; Gleba's spores are not handled yet.

## Features

- A pollution condenser that scrubs pollution out of the air around it into water, producing polluted water. It only runs where the air is actually polluted.
- A pollution vaporizer that evaporates polluted water into the air wherever it is placed, moving the biter attacks it attracts.
- Pollution filtering in Assembler 2 and 3, which traps the pollution in polluted water in a pollution filter and returns the water.
- Pollution filter restoration at blue science: a solvent made from sulfuric acid and light oil restores used filters in a chemical plant. Until then, filters are single-use.

## Installation

Install the released mod through the Factorio mod portal when available. Release packages are also attached to repository releases as `{mod-name}_{version}.zip`.

For local development, keep the repository layout intact and run validation from the repository root:

```sh
./scripts/validate.sh
```

Semantic versioning policy is documented in [docs/semantic-versioning.md](docs/semantic-versioning.md).

Release packaging and automated deployment are documented in [docs/release-process.md](docs/release-process.md).

Contribution guidelines are documented in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Pollution Reclamation is released under the [GNU General Public License v3.0](LICENSE), continuing the license of the Krastorio 2 and KrastorioAirPurifier work it derives from.

## Credits

- raiguard, Krastor, and Linver for the original Krastorio 2 air purifier design and code.
- Tarckmhog for the KrastorioAirPurifier port to Factorio 2.0, which this repository's source was reconstructed from.

## AI Disclosure

This mod is developed with substantial AI assistance. AI tools have contributed to code implementation, documentation, validation workflow setup, and release automation.

AI-assisted work in this repository is governed through the policy files under `.governance/`. Those policies are intended to keep AI contributions reviewable, scoped to the task at hand, and aligned with the repository's validation and release process.
