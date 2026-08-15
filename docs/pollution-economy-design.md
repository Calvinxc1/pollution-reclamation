# Pollution Economy: Design Notes

Status: **working design doc.** Sections are marked as *decided*, *leaning*, or *open* so
the settled parts can be told apart from the parts still being argued about. Captures
discussion from 2026-08-13 plus the mechanical research behind it, so the trade-offs are
written down before any recipes get balanced around them.

**Tier-1 intake and outflow have since been built.** See
[tier-1-implementation-status.md](tier-1-implementation-status.md) for what actually
exists, the tuned numbers, and what's still deliberately temporary. Everything else in
this document remains unimplemented design.

## Premise

Vanilla pollution is purely a cost. There is never a reason to want more of it, so the
only strategy is minimization. The opportunity for this mod is to make captured pollution
an *input* — something with a real upside — so the player faces a genuine decision instead
of a one-way optimization.

The mechanism for that already exists in the mod today and was almost invisible: the used
filter is bottled pollution. It only exists because the factory was dirty. The design
below generalizes that idea from an item into a fluid, and gives captured pollution more
than one possible fate.

## Scope

**Decided.** The capture / store / vent / process economy is **Nauvis-specific** and
applies to industrial pollution only. Gleba is intended to get a different mechanic
entirely rather than a reskin of this one — see the parked sketch at the end.

Vulcanus, Fulgora, and Aquilo have no airborne pollutant and are out of scope by
construction.

## Core loop

1. The factory emits pollution. Unavoidable, and scales with how hard you are pushing.
2. **Intake buildings** scrub ambient pollution and bottle it as a fluid.
3. The captured pollution fluid has three mutually exclusive sinks:
   - **Store it.** Tank farms. Safe, yields nothing, cost grows without bound.
   - **Vent it.** An outflow building with strongly positive emissions. Cheap disposal,
     and it relocates biter aggression to wherever you put it.
   - **Process it.** Later tier. Converts the fluid into materials and capabilities.

The three-way split matters. Store and vent are both disposal and would otherwise
collapse into "which disposal is cheaper." Adding the processing sink turns the decision
into a triangle: safety vs. cost vs. yield.

### Why fluid rather than item

Fluids cannot ride belts or be moved by inserters, so pollution has to travel on pipes and
tanks. That forces a real infrastructure commitment for anyone who wants to relocate their
pollution, which is exactly the effort curve we want. Vanilla storage tanks (25k capacity)
give sequestration for free, and "where do we put it" is a thematically honest problem for
carbon capture.

### The vent building is the novel piece

Factorio's attack logic is: pollution spreads chunk to chunk, nests absorb it, absorbed
pollution accumulates toward attack waves, and those waves path toward the pollution
source. A large remote emitter genuinely pulls attacks toward itself. That means a vent
site decouples *where the factory is* from *where the biters come*, which is a strategic
lever vanilla does not offer. **This is the most original idea in the concept and should
be protected as the mod's identity.**

### Graceful failure is already built in

If a player tanks everything and never vents, the tanks fill, the intake buildings' fluid
output backs up, they stall, and they stop scrubbing. Pollution resumes on its own.
Sequestration visibly stops working when you run out of room, which is exactly the story
that path should tell. **Do not accidentally engineer this away.**

## Tech structure

**Decided.** A single root technology unlocks a tier-one intake building *and* a tier-one
outflow building together, so the basic loop is complete and playable the moment it is
researched. From there the tree splits into two parallel branches, one per building
family, and neither is a prerequisite for the other.

Rationale: a player who only wants to scrub their base should never be forced up the vent
track, and vice versa. Branch choice is playstyle expression.

**Decided.** The branches are held in lockstep on **research cost and tier count**, so
neither reads as the "real" track and neither is a trap. They are explicitly *not* held in
lockstep on mechanics — see below.

**Open.** Exact tier count. Note that a wide throughput band bought purely through
building tiers is expensive in art, and the mod currently has one inherited building
sprite. The standard trick is three discrete building tiers for visible progression plus a
multiplier research line to widen the band without new prototypes. Factorio's own
convention is mostly three tiers.

**Leaning.** Processing hangs off a later point in the tree rather than off the root — see
the processing section.

## Building families

### The intake / outflow asymmetry

**This is the key design insight for the two branches.** They are under opposite spatial
pressures, and mirroring them mechanically would waste that.

Intake is ambient-capped and pollution is stored per chunk, so multiple intake buildings
in one chunk split the same pool. Placing them means spreading them out. A higher-tier
intake in thin air does not get its full rate — it gets whatever is actually there, so
raw-rate upgrades have **diminishing returns built in**.

Outflow has no such cap. Venting always delivers its full rate. What outflow actually
wants is a *predictable* plume, because a tight one funnels biters to a spot you have
walled and a loose one means attacks from several directions at once.

Therefore:

- **Intake tiers buy reach.** Tier one reads only its own chunk. Higher tiers pull from
  neighboring chunks as well, so late-game capture is fewer buildings covering more ground
  rather than a carpet of them. This converts the "early is a grind, late is mostly solved"
  goal into a spatial mechanic instead of a number, and it sidesteps the diminishing-returns
  problem because reach keeps mattering even in cleaned-up air.
- **Outflow tiers buy focus.** Tier one is deliberately uncontrolled. Higher tiers
  concentrate and aim the plume. The upgrade is "I can now aim my bait," which is a far
  more interesting purchase than "I vent twice as fast."

Both read as early-fiddly and late-controlled, through opposite mechanics, with investment
parity preserved.

### Intake building

Upgrade axes available, beyond raw throughput: activation threshold (how thin the air can
get before it stops), extraction efficiency at low concentration, chunk reach, footprint,
power draw, and filter consumption.

**Leaning.** Reach is the headline axis. Threshold and low-concentration efficiency are
natural secondary axes and reinforce the same fantasy — a high-tier intake keeps working in
air a tier-one cannot touch.

### Outflow building

**Open, but with a preferred progression.** Variations discussed:

- **Omnidirectional (tier one).** Engine emissions, natural diffusion, no control at all.
  The plume goes where it goes, which makes an early bait site a genuine gamble.
- **Directional.** Give the building a rotation and script emission into a cone downrange.
  You are now aiming.
- **Remote nozzle (preferred endpoint).** The vent machinery stays safe inside the base; a
  cheap, disposable nozzle sits far away in the killbox, fed by pipe. If biters chew
  through the nozzle you have lost a trivial building rather than your infrastructure. This
  fully delivers the decoupling premise and is the strongest version of the idea.
- **Pulsed release.** Orthogonal to the tiers rather than one of them — better as a mode or
  a circuit-controlled toggle. Stockpile, then dump in bursts. Gives control over *when*
  waves arrive rather than where, so an attack can be timed for just after repairs finish.
- **Line / corridor emission.** Emit along a line to funnel biters down a chosen path.
  Noted, not developed.

**Leaning.** Circuit-controllable venting in general is a natural fit and would let players
build genuinely clever aggro automation. 2.1 expanded circuit connections to more entity
types.

`pollute()` takes a source position, so none of this requires the vent to emit only into
its own chunk. Emission placement is fully scriptable.

### Processing building

**Decided.** Processing is an *advanced* use case, not part of the early loop. Early game
is intake and outflow only.

**Leaning.** First processing tier lands around late green or early blue science. That is
consistent with where the mod's existing tech already sits (`pr_air-purification` is 250
red-plus-green with steel and engine prereqs; the improved filter is already at blue), and
blue means oil is running, which is also where filter plastic comes from. The gate
justifies itself.

**Decided.** The first processing recipe is air scrubbing: captured pollution fluid plus a
consumable (filter or similar) produces a solid item. Pollution becomes matter.

**Decided, and important.** The processing building **emits pollution while running**. The
consequences are good:

- Those emissions go back into ambient air where intake buildings can recapture them,
  producing a genuinely recursive loop with convergent, diminishing returns rather than a
  runaway.
- That makes **placement** a real decision. Co-locate processing with the capture field and
  emissions get recaptured, tightening the loop at the cost of concentrating pollution in
  your industrial area. Site it far away and emissions escape, keeping the area clean but
  wasting them. Same "where do I put this" tension as the vent site, with an economic
  payoff instead of a defensive one, and it falls out of the mechanic rather than needing a
  rule.

**Hard invariant.** For any recipe intended to be net-clean, emission per craft must stay
**below** the pollution the consumed fluid represents. If it exceeds it, the loop diverges:
capture 100, emit 150, recapture that, and you have a machine producing unbounded items and
an unbounded pollution cloud. This is the one way the design genuinely breaks.

**Leaning — the clean/hot fork.** That same divergence, deliberately dialed and clearly
signposted, *is* the economy branch. So the cleanest expression of reduction-versus-economy
is not two buildings but **two recipes in the same building**:

- **Clean scrub.** Low yield, comfortably net-negative on pollution.
- **Hot process.** Much higher yield, net-positive on pollution, knowingly making the biter
  situation worse for more material.

Same machine, same input fluid, one decision — the same shape as the restore-versus-reclaim
fork on the filters. That repetition is a feature: it teaches the mod's central idea twice
with the same grammar.

**Caveat on the hot process.** It should emit at a rate that *outruns any realistic capture
field*, so co-locating scrubbers around it visibly fails to keep up. That makes it an honest
commitment rather than something quietly neutralized. Structurally this is elegant: running
dirty pairs naturally with having invested in the outflow track, since a player who already
built a bait site can afford the extra heat. Two independently chosen branches reinforce
each other at the top of the tree without a hard-wired dependency.

## What processing should produce

### The governing principle: be a source, not a chain

**Decided.** Pollution processing terminates fast. Captured pollution becomes *one* raw
intermediate, and that intermediate converts into things that already exist. Do not build
stage two and three of a refining ladder — Extended Vanilla already built that, better,
with art. See the compatibility section.

What this mod uniquely owns is the part nobody else has: **the only way to turn emissions
into matter.**

### Materials are the floor, capabilities are the ceiling

**Leaning, and a reframe worth holding onto.** The instinct to output coal, carbon, and
trace metals keeps running into a wall, because pollution as a competitive ore source
undercuts mining and steps on every other mod. The way out is that the interesting outputs
are not materials but **capabilities** — things you can only do *because* you polluted:

- **Bait concentrate.** Processed into a concentrated form that produces a much stronger
  aggro draw per unit when vented. Directly serves the outflow track, so processing becomes
  valuable even to a player indifferent to materials. It is also the only item in the mod
  whose entire purpose is to make your own life harder on purpose, which is on-theme.
- **Remediation agent.** Spend processed material to decontaminate ground or accelerate
  tree regrowth. Trees genuinely absorb pollution, so this is mechanically real rather than
  decorative, and it gives the clean-play branch a destination it currently lacks.
- **Dirty modules.** Modules already sit on a pollution axis in vanilla, so a module buying
  real productivity at a heavy emissions penalty is native to the game's grammar. It also
  deliberately closes the loop: more emissions, more feedstock, more modules, with biter
  pressure as the only brake.

Materials should be a modest, honest trickle — enough to make the machine worth running,
never enough to replace mining.

### Later directions, not yet worked

- **Fractionation.** The natural step past a single generic residue: higher tech separates
  captured pollution into distinct outputs. The oil-refinery shape, which players already
  understand, and it makes pollution feel like a material with composition.
- **Carbon into Space Age chains.** Carbon is a real SA intermediate. Processed pollution as
  an alternate carbon source plugs the mod into existing production rather than a closed
  loop that only feeds itself. Strongest integration play available for near-zero new
  content.
- **Evolution interaction.** Noted as powerful and unexplored. Anything that touches
  evolution factor directly is a large lever and needs care.

## Mod compatibility

### Extended Vanilla: Refining

**Researched 2026-08-13** by reading the local checkout (`extended-vanilla-local`,
`ev-refining` 4.0.2 / installed 4.0.3). This is a mod Jason actively plays, so compatibility
is a requirement rather than a nicety.

What it owns — a full solid-material processing tree:

- Stone -> gravel -> fine-sand
- Coal -> coal-dust -> coal-chunk -> coal-clump, plus enrichment to enriched-coal
- Uranium crushing / purifying / enriching chains
- Its own building families: jaw crusher, crushers 1-3, electrolysis chambers 1-3,
  purifying chambers 1-2
- Its own recipe categories: `crushing0-3`, `enriching1-3`, `purifying1-2`
- Downstream sinks already built: explosives, grenades, plastics, rocket fuel, bricks,
  landfill, advanced coal liquefaction, elite oil processing

Notably it adds **no custom fluids** — everything runs on vanilla water, steam, and the oil
chain.

**Implication.** If Pollution Reclamation builds its own crushing-and-refining ladder it is
not adjacent to EV, it is competing with it, and on Jason's own save there would be two
parallel ways to make sand.

**The integration pattern to follow.** EV itself does this — it ships
`prototypes/mods/krastorio2.lua`, `aai-industry.lua`, and `bzmods.lua`, adapting its outputs
when those mods are present. Do the same in reverse: soft-depend on `ev-refining`, and when
it is loaded, output into *its* item namespace (coal-dust, fine-sand, gravel) rather than
minting near-duplicates. A player running both then gets "my smokestacks feed my crusher
line," which is better than either mod alone. Without EV, fall back to vanilla coal and
stone.

**Open lanes.** EV has no sulfur, no carbon, and nothing pollution-specific. Those are clear.

### Krastorio 2

The mod is already hard-incompatible with Krastorio2 (`! Krastorio2` in dependencies), since
this content derives from it. Be careful about echoing K2's metal-processing chain shapes
even where there is no direct conflict.

## Implementation: the gating problem

**This is the single most important mechanical constraint, and it is not obvious.**

The current air purifier scrubs pollution via negative `emissions_per_minute` on its energy
source. Negative emissions floor at zero, so a purifier in clean air removes nothing. That
part is self-limiting and correct.

But the *recipe* is not gated on ambient pollution at all. Nothing in the prototype system
checks the local pollution cloud before allowing a craft. An intake building running a
"produce captured pollution fluid" recipe will happily run forever in a pristine chunk,
manufacturing feedstock out of clean air.

Left unaddressed, the premise collapses: a player parks a capture field in an untouched
corner of the map and farms infinite pollution fluid without ever polluting anything.

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

Pollution is stored per chunk, so `get_pollution` returns the same value for every position
within one chunk. Useful consequence: multiple intake buildings in the same chunk naturally
compete for the same pool, which organically encourages spreading them out.

### Airborne pollutants and per-surface scoping (resolved)

`pollute()` takes an optional pollutant prototype but `get_pollution()` takes none, which
initially looked ambiguous on spore surfaces. Checked against shipped prototype data, and it
is not ambiguous: **each surface has at most one pollutant type**, so `get_pollution` is
implicitly scoped to that surface's pollutant.

`airborne-pollutant` is a real prototype type. Vanilla plus Space Age ships exactly two:
`pollution` (base) and `spores` (space-age).

| Planet | `pollutant_type` |
| --- | --- |
| Nauvis | `pollution` |
| Gleba | `spores` |
| Vulcanus | nil |
| Fulgora | nil |
| Aquilo | nil |

Consequences:

- The gating design would carry to Gleba unchanged if used there.
- Three of five planets have no airborne pollutant at all, which is what bounds scope.
- Spores and pollution are materially different: both set `affects_evolution = true`, but
  spores have `damages_trees = false` and `affects_water_tint = false`.
- The mod's existing emissions handling is already correct. Declaring
  `{ pollution = -X, spores = -Y }` and letting the engine apply whichever matches the
  surface is the right pattern.

**Remaining verification:** inferred from prototype data rather than documented runtime
behavior. Confirm in-game on a Gleba save near a spore source with
`/c game.print(game.player.surface.get_pollution(game.player.position))`.

## Ingestion mechanism: options

### Option A — Prototype only, no script

Negative-emission machine running a recipe that outputs the fluid.

- **Pros:** zero script, zero runtime cost.
- **Cons:** fatally broken per the gating problem. Produces fluid from clean air.
- **Verdict:** not viable alone.

### Option B — Script-gated recipe, threshold toggle (recommended)

Same prototype as A, plus a `control.lua` that periodically reads
`get_pollution(entity.position)` and sets `entity.disabled_by_script` against a threshold,
tuned so a full craft's absorption is actually backed by pollution present in the chunk.
(`LuaEntity.active` is read-only, computed from `disabled_by_script` among other causes —
confirmed against the Factorio 2.1 runtime API while implementing tier 1. Setting `active`
directly would error or no-op; `disabled_by_script` is the actual lever, and `active` reads
back `false` as a side effect of setting it.)

- **Pros:** the engine does the hard part — absorption accounting, the zero floor, spatial
  distribution. The script makes one yes/no decision. Negative emissions only apply while
  actively crafting, so toggling couples absorption and production for free.
- **Cons:** binary, with no smooth response to a partially polluted chunk.
- **Verdict:** best foundation. Start here.

### Option C — Script-gated with duty cycling

As B, but the script varies how much of each interval the machine spends active,
proportional to available pollution.

- **Pros:** smooth throughput scaling; capture fields degrade gracefully as they clean an
  area.
- **Cons:** modestly more script, visible stutter.
- **Verdict:** natural upgrade once the basic loop is proven.

### Option D — Fully scripted absorption

No recipe. Script reads pollution, removes it via `set_pollution`, inserts fluid using the
2.1 fluid API (`add_fluid` and friends — `LuaEntity.fluidbox` was **removed** in 2.1, so
older example code will not work).

- **Pros:** total control, arbitrary curves.
- **Cons:** by far the most code; reimplements what the engine already does correctly.
- **Verdict:** only if B and C cannot express a needed behavior. Do not start here.

### Performance note

Do not poll every intake building every tick. Use a rolling iterator processing a slice per
tick, or `on_nth_tick`. RampantEvolutionFixed uses exactly this pattern (a stored `next()`
cursor) and is a good local reference.

## Balance targets

Vanilla emission rates, read directly from `base/prototypes/entity` at Factorio 2.1.14:

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

The current air purifier scrubs **75/min** at default (configurable 50/75/100).

### The problem with the current rate

A small early mining outpost — eight electric drills — emits roughly 80/min. At 75/min per
building, a *single* purifier nearly covers it. Far too strong for the intended feel.

### Target curve

- **Early tier: roughly 15/min per building.** An 80/min outpost needs about six buildings,
  each drawing power and consuming filters. A genuine commitment, making "reroute my
  outpost's pollution" a real project.
- **A modest early main base** (ten boilers, twenty drills, twenty assemblers) runs about
  580/min. At 15/min that is thirty-nine buildings — correctly infeasible.
- **Late tier: roughly 150/min per building.** The same base is covered by four, the
  "mostly solved" end state.

Roughly a 10x band, leaving room for two or three intermediate steps. Note this band is
about *effective* capture, which for intake includes reach, not only per-building rate.

## Risks and open questions

- **Aggro redirection could trivialize biters.** If capture is efficient enough, one remote
  killbox means the main base is never attacked again, converting ongoing pressure into a
  puzzle solved once. Mitigation: make the round trip lossy, so venting releases meaningfully
  more than capturing removed. Capture is also never total, so the base always leaks.
- **Rampant Evolution coupling.** RampantEvolutionFixed makes evolution pollution-driven,
  which sharpens this whole economy. But balancing *assuming* Rampant means the mod plays
  flat for vanilla-evolution players. Design the trade-off to bite under vanilla evolution
  and let Rampant users get a naturally sharper version.
- **Sequestration as a degenerate strategy.** Tank farms are legitimate, but confirm the
  land and material cost escalates fast enough to force a decision eventually.
- **Filter role.** Filters most likely stay the intake building's consumable, preserving the
  Krastorio flavor. Confirm rather than assume, since it interacts with the restore recipes.
- **Art budget.** Every building tier needs a sprite set, and the mod has one inherited
  building sprite today. This constrains tier count more than balance does.
- **Tier counts.** Unspecified for all three families.
- **Processing tiers past the first.** Unspecified.

## Existing mechanics worth preserving

Verified in the current source:

- Basic restore: used filter + 100 water -> filter, plus coal at 50%.
- Improved restore: used improved filter + 100 water -> improved filter, plus coal at 50%
  and stone at 50%.
- `pr_air-cleaning-2` carries `emissions_multiplier = 3.0`. Since the building's emissions
  are negative, the improved recipe scrubs roughly three times as fast. The "improved" tier
  is a throughput multiplier on the same building, not a separate machine.

The restore loop is already a mild material source rather than pure cost recovery, which is
a good foundation for the processing branch.

---

# Parked: Gleba spore routing sketch

Status: **rough sketch, parked, not evaluated.** Recorded 2026-08-13 to capture the shape of
the idea before attention returned to Nauvis. Deliberately not critiqued. Do not treat
anything here as decided or as having survived review.

Gleba is intended to get a mechanic of its own rather than a reskin of the Nauvis capture /
vent / process loop.

## Shape of the idea

A new **planter** building. Rather than emitting spores into the atmosphere the way normal
Gleba agriculture does, it captures its own spore output at the source and exposes it
through an **extra pipe connection**, making spores a routable substance instead of an
ambient emission.

From there the player chooses how spores move through the base:

- **Centralized.** Spores stay managed at the harvest points. Risk concentrated where the
  planters are.
- **Dispersed.** Spores piped out through the base, optionally via **leaky pipes** that
  release slowly along their length. Risk spreads across the whole base rather than pooling
  at harvest sites, and the base itself becomes exposed.

The intended tension is between concentrating spore pressure at a defensible point and
accepting diffuse, base-wide pressure instead.

## Open threads, not yet worked

- The upside of the dispersed option is not yet specified. As sketched, dispersal spreads
  risk without a stated benefit, so the choice is not yet a trade-off.
- Whether "leaky pipes" is a distinct prototype, a property of normal pipes carrying the
  spore fluid, or a separate entity.
- How the planter relates to vanilla Gleba agriculture: replacement, alternative, or upgrade.
- Whether piped spores are the same fluid concept as Nauvis captured pollution or a wholly
  separate substance.
- Whether any of the Nauvis processing branch applies to spores at all.
