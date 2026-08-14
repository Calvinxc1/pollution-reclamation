# Pollution Reclamation

Pollution Reclamation is a Factorio 2.1 mod that adds a standalone air purification and pollution filtering system: an air purifier building that consumes electricity and pollution filters to actively erase pollution, with a restore recipe for used filters and an advanced filter tier for higher throughput.

## Origin

This mod continues an independent line of [KrastorioAirPurifier](https://mods.factorio.com/mod/KrastorioAirPurifier) by Tarckmhog, itself a port of the air purifier from [Krastorio 2](https://mods.factorio.com/mod/Krastorio2) by raiguard, Krastor, and Linver. KrastorioAirPurifier has no public source repository and its author has no other public contact channel, so this repository is a from-scratch reconstruction of the released mod rather than a git fork, kept going as an independent mod under a new name and namespace.

## Requirements

- Factorio 2.1.
- Space Age is optional. The mod adjusts filter recipes and adds Gleba spore filtering when Space Age is active, and works without it.

## Features

- An air purifier building that consumes electricity and pollution filters to actively remove pollution.
- A restore recipe that reclaims used filters with water, with a chance of recovering raw materials.
- An advanced filter tier with higher throughput and, on Space Age saves, spore filtering for Gleba.
- Two configurable startup settings for filtering efficiency.

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
