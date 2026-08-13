# Pollution Economy: Design Notes

Status: **draft, exploratory.** Nothing here is committed to implementation. This
document captures the design direction discussed on 2026-08-13 and the mechanical
research behind it, so the trade-offs are written down before any recipes get
balanced around them.

## Premise

Vanilla pollution is purely a cost. There is never a reason to want more of it, so
the only strategy is minimization. The opportunity for this mod is to make captured
pollution an *input* — something with a real upside — so the player faces a genuine
decision instead of a one-way optimization.

The mechanism for that already exists in the mod today and was almost invisible: the
used filter is bottled pollution. It only exists because the factory was dirty. The
design direction below generalizes that idea from an item into a fluid, and gives the
captured pollution more than one possible fate.

## Core loop

1. The factory emits pollution. Unavoidable, and scales with how hard you are pushing.
2. **Capture buildings** scrub ambient pollution and bottle it as a fluid.
3. The captured pollution fluid has three mutually exclusive sinks:
   - **Store it.** Tank farms. Safe, yields nothing, cost grows without bound.
   - **Vent it.** A release building with strongly positive emissions. Cheap disposal,
     and it relocates biter aggression to wherever you put it.
   - **Process it.** Later tier. Converts the fluid into carbon, sulfur, and other
     materials. The actual economy branch.

The three-way split matters. Store and vent are both disposal and would otherwise
collapse into "which disposal is cheaper." Adding the processing sink turns the
decision into a triangle: safety vs. cost vs. yield.

### Why fluid rather than item

Fluids cannot ride belts or be moved by inserters, so pollution has to travel on pipes
and tanks. That forces a real infrastructure commitment for anyone who wants to
relocate their pollution, which is exactly the effort curve we want. Vanilla storage
tanks (25k capacity) give sequestration for free, and "where do we put it" is a
thematically honest problem for carbon capture.

### The vent building is the novel piece

Factorio's attack logic is: pollution spreads chunk to chunk, nests absorb it, absorbed
pollution accumulates toward attack waves, and those waves path toward the pollution
source. A large remote emitter genuinely pulls attacks toward itself. That means a vent
site decouples *where the factory is* from *where the biters come*, which is a strategic
lever vanilla does not offer. This is the most original idea in the concept and should
be protected as the mod's identity.

## The gating problem

**This is the single most important mechanical constraint, and it is not obvious.**

The current air purifier scrubs pollution via negative `emissions_per_minute` on its
energy source. Negative emissions floor at zero, so a purifier sitting in clean air
removes nothing. That part is self-limiting and correct.

But the *recipe* is not gated on ambient pollution at all. Nothing in the prototype
system checks the local pollution cloud before allowing a craft. A capture building
running a "produce captured pollution fluid" recipe will happily run forever in a
pristine chunk, manufacturing feedstock out of clean air.

If that is left unaddressed, the entire premise collapses: a player parks a capture
field in an untouched corner of the map and farms infinite pollution fluid without ever
polluting anything. Dirty play would no longer be what earns the dirty rewards.

**Therefore a `control.lua` is mandatory for this design.** The mod currently has none.
There is no prototype-only way to express "this recipe requires ambient pollution."

## Verified API surface (Factorio 2.1)

Confirmed against the current runtime docs rather than memory:

| Method | Signature |
| --- | --- |
| `LuaSurface.get_pollution` | `get_pollution(position) -> double` |
| `LuaSurface.set_pollution` | `set_pollution(position, amount)` |
| `LuaSurface.pollute` | `pollute(source, amount, prototype?)` |
| `LuaSurface.clear_pollution` | `clear_pollution()` |
| `LuaSurface.get_total_pollution` | `get_total_pollution() -> double` |

Pollution is stored per chunk, so `get_pollution` returns the same value for every
position within one chunk. That has a useful consequence: multiple capture buildings in
the same chunk naturally compete for the same pool, which organically encourages
spreading them out instead of stacking them.

**Open question:** `pollute()` takes an optional pollutant prototype, but
`get_pollution()` takes no pollutant argument. On Space Age surfaces where the pollutant
is spores rather than pollution, it is unclear which value `get_pollution` returns. Needs
in-game verification before any Gleba behavior is designed.

## Ingestion mechanism: options

### Option A — Prototype only, no script

Negative-emission machine running a recipe that outputs the fluid. This is the existing
air purifier pattern extended.

- **Pros:** zero script, zero runtime cost, trivially simple.
- **Cons:** fatally broken per the gating problem above. Produces fluid from clean air.
- **Verdict:** not viable on its own.

### Option B — Script-gated recipe, threshold toggle (recommended)

Same prototype as A, plus a `control.lua` that periodically reads
`get_pollution(entity.position)` and sets `entity.active` on or off against a threshold.

The threshold should be tuned so that a full craft's worth of absorption is actually
backed by pollution present in the chunk. Set it that way and fluid output is always
matched by real pollution removed.

- **Pros:** the engine does the hard part. Absorption accounting, the zero floor, and
  spatial distribution are all handled natively. The script only makes a yes/no
  decision, so there is very little to get wrong. Negative emissions only apply while
  the machine is actively crafting, so toggling couples absorption and production for
  free.
- **Cons:** binary. A machine is either at full rate or stopped, with no smooth response
  to a partially polluted chunk.
- **Verdict:** best foundation. Start here.

### Option C — Script-gated with duty cycling

As B, but instead of a hard on/off, the script varies how much of each interval the
machine spends active, proportional to available pollution.

- **Pros:** smooth throughput scaling. A lightly polluted chunk yields a trickle rather
  than nothing, which feels much better at the margins and makes capture fields
  degrade gracefully as they clean an area.
- **Cons:** modestly more script, and the machine visibly stutters.
- **Verdict:** the natural upgrade from B once the basic loop is proven. Worth doing if
  the binary behavior feels bad in play.

### Option D — Fully scripted absorption

No crafting recipe at all. The script reads pollution, removes it directly via
`set_pollution`, and inserts fluid into the entity using the 2.1 fluid API
(`add_fluid` and friends — note `LuaEntity.fluidbox` was **removed** in 2.1, so any
older example code found online will not work).

- **Pros:** total control. Arbitrary absorption curves, partial capture, exotic
  behavior.
- **Cons:** by far the most code. Must manually handle fluid capacity checks, power
  draw, working animations, and per-entity update cost. Reimplements things the engine
  already does correctly.
- **Verdict:** only if B and C genuinely cannot express a needed behavior. Do not start
  here.

### Performance note

Whichever option, do not poll every capture building every tick. Use a rolling iterator
that processes a slice of entities per tick, or check all of them on an `on_nth_tick`
interval. RampantEvolutionFixed uses exactly this pattern (a stored `next()` cursor over
a table) and is a good local reference implementation.

## Balance targets

Vanilla emission rates, read directly from `base/prototypes/entity` at Factorio 2.1.14
rather than from memory:

| Entity | Pollution/min |
| --- | --- |
| Boiler | 30 |
| Burner mining drill | 12 |
| Electric mining drill | 10 |
| Pumpjack | 10 |
| Burner generator | 10 |
| Oil refinery | 6 |
| Assembling machine 1 | 4 |
| Steel furnace | 4 |
| Chemical plant | 4 |
| Centrifuge | 4 |
| Assembling machine 2 | 3 |
| Stone furnace | 2 |
| Assembling machine 3 | 2 |
| Electric furnace | 1 |

The current air purifier scrubs **75/min** at default settings (configurable 50/75/100).

### The problem with the current rate

A small early mining outpost — call it eight electric drills — emits roughly 80/min. At
75/min per building, a *single* purifier nearly covers it. That is far too strong for
the intended feel.

### Target curve

The design goal is that early capture is easily outstripped by a real base, and that
relocating even a small outpost's pollution takes visible dedication, while late-game
capture becomes a mostly solved problem.

- **Early tier: roughly 15/min per building.** An 80/min mining outpost then needs about
  six capture buildings, each drawing power and consuming filters. That is a genuine
  commitment for an early-game player, and it makes "reroute my outpost's pollution back
  to the main base" a real project rather than an afterthought.
- **A modest early main base** (ten boilers, twenty drills, twenty assemblers) runs
  around 580/min. At 15/min that is thirty-nine buildings, which is correctly
  infeasible. The early tier should not be able to offset a whole base.
- **Late tier: roughly 150/min per building**, via upgrades, modules, or a higher-tier
  building. The same 580/min base is then covered by four buildings, which is the
  "mostly solved" end state.

That is roughly a 10x scaling band across the tech tree, which leaves comfortable room
for two or three intermediate steps.

## Risks and open questions

- **Aggro redirection could trivialize biters.** If capture is efficient enough, a
  player builds one remote killbox and the main base is never attacked again, converting
  an ongoing pressure mechanic into a puzzle solved once. Mitigation: make the round
  trip lossy, so venting a tank releases meaningfully more pollution than capturing it
  removed. Redirecting aggression then costs bigger waves in exchange for choosing where
  they land. Capture is also never total, so the base always leaks some.
- **Rampant Evolution coupling.** RampantEvolutionFixed makes evolution pollution-driven,
  which makes this whole economy far more interesting. But balancing *assuming* Rampant
  means the mod plays flat for vanilla-evolution players. Design the trade-off to bite
  under vanilla evolution and let Rampant users get a naturally sharper version.
- **Sequestration as a degenerate strategy.** Tank farms are a legitimate answer, but
  confirm the land and material cost actually escalates fast enough to force a decision
  eventually.
- **Space Age spores.** Behavior of `get_pollution` on spore-based surfaces is unverified
  (see API section). Gleba support should be deferred until that is tested.
- **Filter role.** Filters most likely stay as the capture building's consumable, which
  preserves the original Krastorio flavor. Confirm this rather than assuming it, since it
  interacts with the existing restore recipes.

## Existing mechanics worth preserving

Verified in the current source:

- Basic restore: used filter + 100 water -> filter, plus coal at 50%.
- Improved restore: used improved filter + 100 water -> improved filter, plus coal at
  50% and stone at 50%.
- `pr_air-cleaning-2` carries `emissions_multiplier = 3.0`. Since the building's
  emissions are negative, this makes the improved recipe scrub roughly three times as
  fast. The "improved" tier is a throughput multiplier on the same building, not a
  separate machine.

The restore loop is already a mild material source rather than pure cost recovery, which
is a good foundation for the processing branch to build on.
