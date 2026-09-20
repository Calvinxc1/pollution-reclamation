# Tier-1 condenser and vaporizer: implementation status

Working notes for the first implementation pass at the pollution economy's tier-1
buildings, from the 2026-08-14 session. Companion to
[pollution-economy-design.md](pollution-economy-design.md), which holds the design
reasoning; this file holds what actually got built and what's tuned to what.

**Status: final for tier 1** as of 2026-09-19. Built on
`feature/pollution-economy-design` and merged to `dev` from there. Further work (the
air purifier rework first) happens on its own feature branches off `dev`.

## What works

A complete, playable capture/vent loop, verified running in a real save:

- **`pr_pollution-condenser`** ("Pollution condenser", the tier-1 intake building)
  draws ambient pollution from its chunk, consumes water as the scrubbing medium, and
  outputs `pr_polluted-water` fluid.
- **`pr_pollution-vaporizer`** ("Pollution vaporizer", the tier-1 outflow building)
  consumes that fluid and vents it back into the atmosphere
  wherever it's placed, relocating the biter aggression it attracts. It evaporates the
  water along with the pollution.
- **`control.lua`** gates condensers on real ambient pollution, and only on surfaces whose
  pollutant is `pollution`, so they can't manufacture fluid out of clean air or spores.

Confirmed working in-game: the loop runs, fluid is produced, and condensers register in
the global pollution statistics as genuine consumers. Confirmed *not* easily visible:
per-chunk reduction on the pollution overlay, since the rates are small relative to
typical base output. That's expected, not a bug.

## Current numbers

All first-pass, all deliberately adjustable. The exchange rate is the important part:

| Quantity | Value |
| --- | --- |
| Atmosphere-to-fluid exchange rate | **1 atmospheric unit = 10 fluid units** |
| Condenser atmospheric absorption | `-15/min` (entity `emissions_per_minute`) |
| Condenser fluid output | 10 per 4s craft = **150/min** at full uptime |
| Condenser water consumption | 10 per craft = **150/min**, 1:1 with pollution produced |
| Vaporizer fluid consumption | 10 per 4s craft = **150/min** |
| Vaporizer atmospheric emission | `+15/min` base x `1.1` recipe multiplier = **+16.5/min** |
| control.lua pollution threshold | 10 per condenser sharing the chunk: a chunk needs `10 x condensers in it` or none of them run |
| control.lua entities per tick | 4 |

Two derived figures worth keeping in mind:

- **The 10% venting tax.** The vaporizer releases more than the condenser captured (150 in vs. 165
  out, in fluid-equivalent terms) because boiling the water back off to re-release the
  pollution is its own inefficient, energy-hungry process. This is the design doc's
  "lossy round trip" biter-aggro mitigation, and the ratio reads identically in both
  scales since 1 atmospheric = 10 fluid.
- **Water is not returned.** The vaporizer evaporates the polluted water into the air,
  water and all, so every condenser needs a steady 150/min of fresh water. A water return
  was tried on 2026-09-19 and taken back out the same day: a straight outflow comes
  first, and closing the water loop is left for later.
- **Tank fill time.** One condenser at full uptime fills a vanilla 25,000-capacity storage
  tank in **~2h47m**. Jason confirmed this feels right. Real-world time will be longer
  whenever the threshold gate takes the building offline.

## Pollution sensor

Added 2026-09-19, red science, deliberately ahead of the economy itself so a player can
survey chunks before deciding where condensers are worth building.

- **`pr_pollution-sensor`** is a 1x1 building with its own placeholder art: a squat steel
  housing on a bolted base plate, blue band, green readout and a top intake grille. The
  world sprite is 96x96 at `scale = 0.5`, so the device is one tile wide, shifted down so
  the base plate sits on the tile instead of floating. It shows the pollution in its own
  chunk two ways: as an entity status line for a player standing next to it, and on its
  circuit output.
- **It is a `constant-combinator` underneath, and that is plumbing, not design.** That is
  the only entity type in Factorio that can put an arbitrary, script-set value on a
  circuit wire; everything else with a connector either takes input (lamps, inserters) or
  reports something fixed like charge or contents. The only inherited behaviour is the
  circuit output: the combinator's activity LED is replaced with empty sprites (its light
  offsets are mandatory, so they stay, pointing at nothing), the sprites are ours, and its
  window is replaced with ours.
- **The trade is power.** A constant combinator has no energy source, so the sensor cannot
  require electricity; it reads wherever it is planted. It was a powered `small-lamp`
  copy until 2026-09-19, when the circuit output was chosen over the power requirement.
- **The output signal is the player's.** A fresh sensor outputs on `signal-P`; the player
  can change it in the sensor's own window, and each update rewrites only the slot's
  value, keeping their signal. An emptied slot is refilled with the default.
- **It reads pollution, not whatever the surface happens to emit.** `get_pollution`
  answers for whichever pollutant a surface uses, so on Gleba it returns a spore count.
  The gate has always refused to run a condenser on that; the sensor did not, and until
  2026-09-19 would have labelled a spore reading "Chunk pollution" and put it on the
  wire -- on the one surface where the gate had already said no. Both now ask the same
  question through one helper, and a non-pollution surface reads as no pollution and
  outputs zero. Found while cross-checking the window against the gate, and covered by
  tests in both directions.
- **It only outputs when it is wired.** An unwired sensor leaves the circuit output
  switched off rather than quietly holding a value, so a sensor that isn't connected to
  anything isn't pretending to be. The player's signal choice survives the wire being
  cut and comes back when it is reconnected. The status line is unaffected either way --
  a sensor with no wire still reads its chunk for anyone standing next to it.
- **It has its own window, not the combinator's.** Opening a sensor gives the player a
  window shaped like a vanilla entity's -- status line, entity preview, and a circuit
  panel beside it holding the one setting the sensor has -- instead of the combinator's
  logistic-section interface, which has nothing to do with a gauge. The panel follows
  the wiring the way vanilla's does: shown when the sensor is connected, and openable by
  hand from a circuit-network button when it isn't. Once the player opens it by hand it
  stays open.
- **That window is a reproduction, and has to be.** The engine builds an entity's real
  circuit panel from that prototype's own control behaviour, and a mod cannot add a
  control to it. `player.gui.relative` only anchors a separate frame to one of the 79
  stock GUI types on one of four sides (measured 2026-09-19) -- there is no anchor
  inside the circuit panel. So the panel here is ours, built from the same vanilla
  styles the engine uses: `entity_frame`, `entity_button_frame`, `wide_entity_button`,
  `status_image`, and `utility/circuit_network_panel` for the button. Each of those
  names was checked against the installed 2.1 data rather than assumed.
- **Where it lives.** `src/runtime/sensor-gui.lua`, deliberately outside `src/control/`,
  which is reserved for pure, dependency-injected logic the plain-Lua tests can load.
  GUI code cannot be pure, so the gate logic it drives stays testable on its own.
- **`pr_pollution-sensing`** unlocks it: 25 automation science at 15s, after `radar`,
  vanilla's own survey instrument (itself 20). `pr_pollution-control` requires it in turn,
  so a player can always read a chunk before building anything that acts on one.
  The recipe costs 5 iron plates and 2 electronic circuits.
- **Sensors share the condensers' check budget.** `control.lua` visits
  `CHUNKS_PER_TICK` occupied chunks per tick, and a sensor refreshes when its chunk comes
  up: with 400 occupied chunks that's about 1.7 seconds. Fine for a readout, and it keeps
  the runtime cost flat no matter how many buildings stand in those chunks. The gate
  itself no longer depends on that cadence for correctness -- see the chunk population
  rule below.
- **It reuses the condenser's own gate code.** The sensor is tracked in the same table
  with a `sensor` role, so the number it displays is read through the same helpers that
  decide whether condensers run, and the readout cannot drift from the rule. The window
  goes through those helpers too -- `reading`, `is_pollution`, `status_label` -- rather
  than recomputing the number for display, which is what let the two disagree once.
  Sensors are excluded from a chunk's condenser population, since they absorb nothing
  and must not raise the bar their neighbours have to clear.
- **One number on purpose.** The tracking also knows how many condensers share the chunk
  and what that chunk needs to run them; showing that is left to a later sensor tier.
- Verified headless: the reading matched `get_pollution` exactly as pollution rose and
  fell, a lamp wired to the sensor read the same number off `signal-P` (366, 507, 410),
  and a condenser beside a sensor kept running normally. The wiring rule was measured the
  same way on 2026-09-19: an unwired sensor had its output switched off with no slot
  written at all, while still showing its status line; wiring two together put
  `signal-P = 505` on the wire against a surface reading of 504.8; cutting the wire
  switched the output back off and kept `signal-P` selected. The Gleba rule was checked
  on a real Gleba surface rather than only in the unit tests: with 640 polluted into each,
  the Nauvis sensor read 545 on a green diode while the Gleba sensor -- whose surface
  reports 640 of `spores` through the same call -- said "no pollution on this surface" on
  a yellow one and wrote nothing. The window itself is the one part that cannot be
  checked this way -- a headless run has no player to open it -- so it needs an in-game
  look.

## The walk is over chunks, not buildings

Changed 2026-09-19, after asking what this does at megabase scale.

Pollution is stored per chunk, and the gate's verdict is per chunk and all-or-nothing by
design -- so both ends of the calculation were already chunk-scoped while the loop was
building-scoped. Five condensers in a chunk meant five `get_pollution` calls returning
the same number, five identical comparisons, and five writes of the same answer.

`state.chunks` is now the index and the iteration unit: `{ condensers, sensors,
condenser_count, applied }` per occupied chunk, built from the same build/mine events
that already maintained `entity_chunk`. **Only chunks holding a tracked building are in
it** -- never the map's chunks at large, which on a big save outnumber these by orders of
magnitude, and scanning those would be far worse than what this replaced.

A visit is one pollution read and one comparison, whatever is standing there. Sensors
still get individual attention, since each has its own status line and circuit output,
but they read from the chunk's one sample -- which is also what now makes it impossible
for a sensor and the condensers beside it to report different pollution. Condensers get
written **only when the verdict changes**: `applied` holds what was last written, so a
chunk sitting comfortably above or below its bar touches no entity at all.

Measured, 8,000 condensers packed at 3-tile spacing (about 100 per chunk, 81 chunks):

| | old | new |
|---|---|---|
| mod cost above baseline | 0.197 ms/tick | 0.092 ms/tick |
| lap over everything tracked | 33.3 s | 0.34 s |

The cost figure is the smaller half of the story -- the mod was never expensive, and even
the old number is about 1% of a 16.67 ms frame. The lap is the part that matters, because
it bounds how stale a sensor's reading gets and how long a crowded chunk can be overdrawn
between checks.

**How much it buys depends on layout, and the layout is favourable.** The shared-read
saving scales with buildings per chunk: condensers spread one per chunk would give
`chunks == buildings` and no lap improvement at all. That was the first reading of the
all-or-nothing rule and it was wrong -- concentration is the intended play (see the
design doc), so the dense figures above are the representative case rather than the
optimistic one. Better still, the two pull the same way: concentrating keeps the chunk
count small while the building count grows, and the lap is over chunks. A 5,000-condenser
farm at ~100 per chunk is 50 chunks, a 0.2 s lap.

The saving that survives any layout at all, dense or sparse, is writing nothing when a
verdict hasn't changed -- at rest that is nearly every chunk, nearly every lap.

**The trade.** Another mod setting `disabled_by_script` on one of our condensers would
not be corrected until that chunk's verdict next flips. Nothing else has business
touching it, membership changes invalidate the cached verdict, and `control.lua` rebuilds
the whole state on every mod change, so any drift clears on the next update.

## Tech placement

`pr_pollution-control` ("Pollution control") is a single root technology unlocking all four recipes (two
building recipes, two process recipes) together, per the design doc's "Decided" call
that a player should get a complete loop or none of it.

- **Cost:** 250 x (automation + logistic science), 30s. Green science tier.
- **Prerequisites:** `fluid-handling` and `pr_pollution-sensing`.
- **On `fluid-handling`,** specifically. Not `steel-processing`/`engine`
  (which `fluid-handling` already requires transitively). The reason is concrete:
  `fluid-handling` is what unlocks `storage-tank` and `pump`. Without it a player could
  build the loop and connect it with plain pipes, but couldn't build a tank farm --
  one of the three core sinks in the design -- or pump over distance.

## Architecture notes

- **`src/control.lua`** is a thin entrypoint only, per governance. It wires Factorio
  events, owns `.valid` filtering of tracked entities, and hands the engine's `defines`
  constants to the pure module. That injection runs from `on_init`,
  `on_configuration_changed` *and* `on_load`: loading an existing save runs neither of
  the first two, and it used to be redone every tick to cover that gap.
- **`src/control/pollution-condenser.lua`** holds the real logic for both tracked
  buildings -- gating condensers and reporting for sensors -- through one chunk index and
  one set of helpers, so the number a sensor shows cannot disagree with the number the gate
  tests. The file keeps its condenser-era name because the storage key and module path
  are the ones a shipped save already refers to. It is deliberately pure
  and dependency-injected -- no `game`/`storage`/`script` access anywhere in it. That's
  what lets the same file load both inside Factorio and under a plain Lua interpreter
  for testing. `scripts/validate.sh` enforces this mechanically with a grep guard,
  because a stray global reference wouldn't fail at load time, only when that exact
  code path first executes.
- **`src/runtime/`** is for the code that has to touch Factorio at runtime and therefore
  cannot be pure: today that is `sensor-gui.lua`, the sensor's window. The split is the
  point -- the purity guard covers `src/control/` only, so GUI code isn't forced into a
  shape it can't take, and the gate logic it drives doesn't lose its tests to keep it
  company.
- **Entity tracking** covers all nine ways a condenser can appear or disappear (including
  `on_entity_died` for biter destruction, which is easy to miss since it isn't mining).
  Incomplete coverage here would let a real condenser run permanently ungated -- exactly
  the exploit `control.lua` exists to prevent.
- **`tests/lua/pollution_condenser_test.lua`** tests order-independent invariants only,
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

## Diagnostic overrides (removed)

The in-save testing above used a temporary `src/prototypes/diagnostic-overrides.lua`,
loaded last from `src/data.lua`. It enabled all four recipes without research, cut both
building recipes to a single iron plate, and switched both buildings to a `void` energy
source while keeping `emissions_per_minute`. It was deleted before this work merged to
`dev`, so the real tech gate, build costs, and power draw are what ship. None of its
numbers were balance decisions; don't let them leak into playtesting notes. If quick
in-save testing is needed again, recreate it locally and keep it out of commits.

## Placeholder art

**All art in the mod is placeholder** (Jason, 2026-09-19): each piece does its basic job
of making things recognisable in game, but none of it is the intended final look. The
README says so for players.

| Asset | Current placeholder |
| --- | --- |
| Condenser and vaporizer buildings | re-tinted, rescaled vanilla `chemical-plant` (deferred) |
| Pollution sensor (building, item, tech) | AI-generated renders of a squat sensor housing |
| Polluted water, solvent (fluid icons) | AI-generated droplets |
| Pollution filter, used pollution filter (items) | AI-generated renders of one filter cartridge |
| Pollution filtering, Pollution filter restoration (recipes) | AI-generated renders |
| Pollution filtering, Pollution filter restoration (techs) | the matching filter renders, at 256 px |
| Pollution control (tech) | the polluted water droplet, until building art exists |
| Mod thumbnail | AI-generated, see `docs/icon-specs/` |

Every AI-generated icon was cut down from a 1254 px render with real transparency: the
body alpha solidified, sub-17 alpha specks dropped, then downscaled into the standard
mipmap strip (120x64 for items, fluids and recipes; 480x256 for techs). The source
renders are kept in `docs/icon-candidates/`.

On the buildings: condenser green, vaporizer orange. Jason's stated bar for now is
functional visibility, not looks.

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
- **Connector placement on condenser:** water in at the north-west corner, pollution out at
  the south-east -- diagonally opposite, so the two pipe runs don't crowd each other.

A search of every `assembling-machine`/`furnace` with fluid boxes across all ~90
installed mods (via `factorio --dump-data`) found **no 2x2 fluid-handling crafting
machine anywhere** to copy correct proportions from; the smallest is native 3x3. Exact
pixel alignment isn't achievable with borrowed 3x3 art -- it needs art actually drawn
for 2x2.

The fluid's icon, `src/graphics/icons/fluids/polluted-water.png`, is a grimy
version of vanilla water's droplet in the same 120x64 four-mipmap strip, cut from a
supplied image whose four droplets were drawn per mipmap size. The fluid was
introduced as `pr_captured-pollution` ("Captured pollution") and renamed to
`pr_polluted-water` ("Polluted water") on 2026-09-19, before it ever shipped. The
buildings were renamed the same day, also before shipping: `pr_pollution-intake`
became `pr_pollution-condenser` and `pr_pollution-outflow` became
`pr_pollution-vaporizer`.

Concept art for the eventual real condenser building is archived in
[concept-art/pollution-condenser/](concept-art/pollution-condenser), with
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

- Tier counts for the intake, outflow, and processing families -- all still unspecified.
- Whether balance constants should graduate from hardcoded Lua values into startup
  settings once playtested.
- Outflow's progression past tier 1 (the design doc's preferred endpoint is a remote,
  disposable nozzle fed by pipe; nothing beyond tier 1 is built).
- The rest of the processing branch. Its first piece, pollution filtering with filter
  restoration, is built; see the design doc.
- Later pollution sensor tiers: showing a chunk's condenser count and what it must hold
  to run them (the tracking already knows both), and a circuit-network output.
- Whether the mod's GitHub mirror should be made public (currently private, while
  `docs/release-process.md` describes it as the public mirror).

## Known gaps in tier 1

Found in the 2026-09-19 doc review.

- **Spore surfaces bypassed the gate (fixed 2026-09-19).** The condenser absorbs
  `pollution` only, but `get_pollution()` returns the surface's own pollutant, which is
  spores on Gleba, so a condenser there passed the threshold on spores and made polluted
  water for free. The gate now also requires the surface's `pollutant_type` to be
  `pollution`, which also covers planets with no pollutant. Checked in a headless run:
  with spores at 240 on a real Gleba surface the condenser stays disabled and makes
  nothing, while a Nauvis condenser runs. This is a guard only; Gleba's own mechanic
  stays deferred.
- **The sensor reported spores as pollution (fixed 2026-09-19).** The same family of
  bug as the one above, one level up. `can_capture` had been taught to require the
  surface's pollutant to be `pollution`, but `report()` -- what the sensor shows and
  puts on the wire -- only checked that *some* pollutant existed. On Gleba a sensor
  would have read `Chunk pollution: 640` from a spore count and put 640 on the circuit
  network, on the very surface where the gate had already refused to run a condenser.
  The sensor exists to report the rule, so the two disagreeing is the one thing it must
  not do. Both now ask through a single helper (`M.POLLUTANT`, `is_pollution`,
  `status_label`), and the window calls those helpers rather than recomputing the
  reading for display -- the duplicate arithmetic was how they drifted apart. Checked on
  a real Gleba surface: 640 polluted into each, Nauvis reads 545 on a green diode while
  Gleba says "no pollution on this surface" on a yellow one and writes nothing.
- **The sensor's icon never used its mipmaps (fixed 2026-09-19).** Its icon file is a
  120x64 mipmap strip (64+32+16+8) like every other icon here, but the item and the
  entity declared `icon_size = 64` with no `icon_mipmaps`, so the engine read only the
  first square and the icon rendered unsmoothed wherever it is drawn small. Factorio
  does not complain about this, which is why a passing load check never caught it --
  it was found by comparing the declarations against the files. Confirmed fixed against
  a `--dump-data`.
- **Grouped condensers outran their chunk (fixed 2026-09-19).** Each condenser used to
  compare its chunk against a flat threshold of 10, ignoring the others drawing on the
  same pool. Since the gate only re-checks a slice of condensers per tick, a crowded
  chunk could empty between one condenser's checks; absorption then stops at zero while
  the recipes keep running, producing fluid no removed pollution backs. **Measured** with
  225 condensers packed into one chunk holding 60 pollution: 71.8 units' worth of fluid
  came from 56 removed, about 29% unbacked.

  The threshold is now per condenser sharing the chunk, all or nothing: a chunk must hold
  `threshold x condensers in that chunk` before any of them run. All-or-nothing needs no
  arbitration between condensers in a chunk and no rotation to stay fair. It is not a
  penalty on concentration -- see "Concentration is the intended play" in the design doc:
  the bar is a stock requirement, so a chunk inside a factory carries far more than its
  condensers claim. What it refuses is a crowd the chunk cannot back. Re-measured after
  the fix: the same dense block produced 25.0 against 25.7 removed, and a normal field of
  one condenser per chunk still runs at its full 150 fluid/min each.
