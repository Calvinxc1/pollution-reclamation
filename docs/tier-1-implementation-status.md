# Tier-1 intake/outflow: implementation status

Working notes for the first implementation pass at the pollution economy's tier-1
buildings, from the 2026-08-14 session. Companion to
[pollution-economy-design.md](pollution-economy-design.md), which holds the design
reasoning; this file holds what actually got built, what's tuned to what, and what's
deliberately still temporary.

**Branch:** `feature/pollution-economy-design`. **Everything below is uncommitted** in
the working tree as of writing.

## What works

A complete, playable capture/vent loop, verified running in a real save:

- **`pr_pollution-intake`** draws ambient pollution from its chunk, consumes water as
  the scrubbing medium, and outputs `pr_captured-pollution` fluid.
- **`pr_pollution-outflow`** consumes that fluid and vents it back into the atmosphere
  wherever it's placed, relocating the biter aggression it attracts.
- **`control.lua`** gates intake on real ambient pollution, so it can't manufacture
  fluid out of clean air.

Confirmed working in-game: the loop runs, fluid is produced, and intakes register in
the global pollution statistics as genuine consumers. Confirmed *not* easily visible:
per-chunk reduction on the pollution overlay, since the rates are small relative to
typical base output. That's expected, not a bug.

## Current numbers

All first-pass, all deliberately adjustable. The exchange rate is the important part:

| Quantity | Value |
| --- | --- |
| Atmosphere-to-fluid exchange rate | **1 atmospheric unit = 10 fluid units** |
| Intake atmospheric absorption | `-15/min` (entity `emissions_per_minute`) |
| Intake fluid output | 10 per 4s craft = **150/min** at full uptime |
| Intake water consumption | 10 per craft = **150/min**, 1:1 with pollution produced |
| Outflow fluid consumption | 10 per 4s craft = **150/min** |
| Outflow atmospheric emission | `+15/min` base x `1.1` recipe multiplier = **+16.5/min** |
| control.lua pollution threshold | 10 (chunk pollution below this disables the intake) |
| control.lua entities per tick | 4 |

Two derived figures worth keeping in mind:

- **The 10% venting tax.** Outflow releases more than intake captured (150 in vs. 165
  out, in fluid-equivalent terms) because boiling the water back off to re-release the
  pollution is its own inefficient, energy-hungry process. This is the design doc's
  "lossy round trip" biter-aggro mitigation, and the ratio reads identically in both
  scales since 1 atmospheric = 10 fluid.
- **Tank fill time.** One intake at full uptime fills a vanilla 25,000-capacity storage
  tank in **~2h47m**. Jason confirmed this feels right. Real-world time will be longer
  whenever the threshold gate takes the building offline.

## Tech placement

`pr_pollution-economy` is a single root technology unlocking all four recipes (two
building recipes, two process recipes) together, per the design doc's "Decided" call
that a player should get a complete loop or none of it.

- **Cost:** 250 x (automation + logistic science), 30s. Green science tier.
- **Prerequisite:** `fluid-handling`, specifically. Not `steel-processing`/`engine`
  (which `fluid-handling` already requires transitively). The reason is concrete:
  `fluid-handling` is what unlocks `storage-tank` and `pump`. Without it a player could
  build the loop and connect it with plain pipes, but couldn't build a tank farm --
  one of the three core sinks in the design -- or pump over distance.

## Architecture notes

- **`src/control.lua`** is a thin entrypoint only, per governance. It wires Factorio
  events and owns `.valid` filtering of tracked entities.
- **`src/control/pollution-intake.lua`** holds the real logic and is deliberately pure
  and dependency-injected -- no `game`/`storage`/`script` access anywhere in it. That's
  what lets the same file load both inside Factorio and under a plain Lua interpreter
  for testing. `scripts/validate.sh` enforces this mechanically with a grep guard,
  because a stray global reference wouldn't fail at load time, only when that exact
  code path first executes.
- **Entity tracking** covers all nine ways an intake can appear or disappear (including
  `on_entity_died` for biter destruction, which is easy to miss since it isn't mining).
  Incomplete coverage here would let a real intake run permanently ungated -- exactly
  the exploit `control.lua` exists to prevent.
- **`tests/lua/pollution_intake_test.lua`** tests order-independent invariants only,
  never a specific traversal sequence. Factorio's `pairs()`/`next()` is a deterministic
  insertion-order reimplementation that no stock Lua interpreter reproduces, so
  asserting an exact order would just encode the local interpreter's incidental hash
  behavior as if it were spec.

### Correction to the design doc

The design doc originally specified gating via `entity.active`. **That property is
read-only in Factorio 2.1** -- writing to it errors or silently no-ops. The actual
lever is `entity.disabled_by_script`, which `active` reads back as `false` when set.
The doc has been corrected in place; flagging it here too since it would silently break
the mod's core mechanism if it crept back in.

## Temporary state -- must be undone before any release

**`src/prototypes/diagnostic-overrides.lua`** exists purely to make the loop testable in
an active save right now. It:

- enables all four recipes without any research,
- reduces both building recipes to a single iron plate,
- switches both buildings to a `void` energy source (no power draw), preserving
  `emissions_per_minute`.

**To undo:** delete that file and its `require` line at the bottom of `src/data.lua`.
Nothing else is affected -- it's deliberately isolated as a last-loaded post-processing
pass so it never tangles with the real definitions. None of its numbers are balance
decisions; don't let them leak into playtesting notes.

## Placeholder art

Both buildings are re-tinted, rescaled copies of vanilla `chemical-plant` (intake green,
outflow orange). Jason's stated bar for now is functional visibility, not looks.

Things that were genuinely fixed rather than left sloppy, worth not regressing:

- **2x2 footprint** is intentional and load-bearing, replacing chemical-plant's native
  3x3. Sprite `scale`, every layer's `shift`, and the smoke plume's per-direction anchor
  points all scale by the same `FOOTPRINT_SCALE` (2/3) -- the smoke anchors specifically
  were a real in-game misalignment bug, since they live outside the fields a naive
  scale-only pass would touch.
- **Pipe connections** must sit strictly *inside* the collision box, not at the tile
  edge (a real load error, caught by the Factorio load-check). Positions scale
  chemical-plant's own genuinely off-center connector positions rather than using
  arbitrary centered points.
- **Connector placement on intake:** water in at the north-west corner, pollution out at
  the south-east -- diagonally opposite, so the two pipe runs don't crowd each other.

A search of every `assembling-machine`/`furnace` with fluid boxes across all ~90
installed mods (via `factorio --dump-data`) found **no 2x2 fluid-handling crafting
machine anywhere** to copy correct proportions from; the smallest is native 3x3. Exact
pixel alignment isn't achievable with borrowed 3x3 art -- it needs art actually drawn
for 2x2.

Concept art for the eventual real intake building is archived in
[concept-art/pollution-intake/](concept-art/pollution-intake), with
`chatgpt-concept-02.png` as the current primary reference and an in-progress 3D model
being built from it outside this repo.

## Verification

```sh
FACTORIO_BIN="/home/jcherry/Games/steam/steamapps/common/Factorio/bin/x64/factorio" \
  PR_REQUIRE_FACTORIO=1 ./scripts/validate.sh
```

The local Factorio install is symlinked at `~/.factorio/mods/pollution-reclamation ->
<repo>/src`, so changes are live on the next mod reload. **Note:** that symlink was
found pointing at the mod's old pre-rename directory (`k2-air-purifier-recycled`) and
was repaired during this session -- worth re-checking if prototypes ever seem stale.

Without `PR_REQUIRE_FACTORIO=1` and `FACTORIO_BIN`, `validate.sh` skips the real
load-check and only runs JSON/changelog checks, Python tests, Lua tests, and `luac`
syntax checks. The real load-check is the only thing that catches prototype schema
errors, and it caught two during this session that nothing else would have.

## Open, not yet decided

- Tier counts for intake, outflow, and processing families -- all still unspecified.
- Whether balance constants should graduate from hardcoded Lua values into startup
  settings once playtested.
- Outflow's progression past tier 1 (the design doc's preferred endpoint is a remote,
  disposable nozzle fed by pipe; nothing beyond tier 1 is built).
- The whole processing branch. Nothing from it exists yet.
- Whether the mod's GitHub mirror should be made public (currently private, while
  `docs/release-process.md` describes it as the public mirror).
