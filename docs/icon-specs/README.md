# Icon generation notes

Working artifacts from the 2026-08-13 session exploring AI-generated art via Bria
(FIBO), after the decision to replace all Krastorio-derived assets.

## Two tracks

- **In-game assets** follow vanilla Factorio's look: weathered, desaturated,
  matte industrial. See `../icon-candidates/item-pollution-filter-strip.png` for a
  finished example, a valid 120x64 mipmap strip produced end to end.
- **Mod portal icon** follows the New Eden Workshop chassis: hexagonal bronze ring,
  navy field, per-mod interior and accent colour.

## What worked

- **VGL / `structured_prompt`.** Bria's JSON schema made style controllable and
  attributes independently editable. Files here are successive versions of that spec.
- **Positive phrasing.** Naming failure modes ("not broken", "no stub") reproduced
  them. Removing that language from the spec and putting it in `negative_prompt`
  fixed malformed hubs in one pass.
- **Describing occupancy, not absence.** The missing chassis segment only appeared
  once the space was described as a gateway with pollution flowing through it,
  rather than as a missing segment.
- **Item icon pipeline.** Generate at 1024 on a magenta field, `remove_background`,
  then trim/square/downscale and build the mipmap strip programmatically.

## What did not work

Prompt-level control could not hold the chassis specification. Across ten
iterations, fixing one constraint reliably broke another: hub count, gap presence,
ring rotation, and palette could not be held simultaneously. The words "hexagon"
and "open gateway" are in direct tension: "hexagon" yields six hubs and a closed
ring; "gateway" or "open chain" yields the gap but the wrong hub count.

## Recommended next step

Draw the chassis deterministically in code. It is pure geometry (six circles on
hexagon vertices, five bars, a stripe and rivets per bar), so it can be exact and
reusable for every mod in the family. Use generation only for the interior
mechanism, which is what should vary and where the model performs well.

## Interior direction

The scrubber column is the stronger of the two concepts tested: one strong vertical
silhouette that survives thumbnail size, chartreuse haze entering from both sides,
clean teal output rising from the cap. The three-way sink schematic is more
conceptually complete but reads as texture when small.
