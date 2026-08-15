-- Placeholder entity: deep-copied and re-tinted from vanilla chemical-plant
-- until this mod has a custom-art pipeline. Only the fields below are
-- deliberately overridden; everything else (sounds, circuit connector,
-- corpse, etc.) is inherited as-is from the copy.

-- chemical-plant is a native 3x3 building; this mod's buildings are meant
-- to hold a 2x2 grid footprint. Two things follow from shrinking the
-- collision box below: the inherited sprite needs a matching scale-down so
-- it doesn't visually overhang the smaller footprint, and the fluid box's
-- pipe connection needs repositioning to the new, smaller edge instead of
-- chemical-plant's original 3x3-scaled corner position.
local FOOTPRINT_SCALE = 2 / 3

-- chemical-plant's animation layers use `apply_recipe_tint` to dynamically
-- color internal tanks/pipes from whatever recipe is loaded. This building
-- has a fixed_recipe and no useful per-recipe tint to derive, so strip that
-- dynamic behavior everywhere it appears and replace it with a flat static
-- tint instead, giving the building a distinct, predictable look. Rescales
-- every sprite layer's `scale` at the same time, for the reason above.
-- Spatial offset fields, in addition to `scale`, that need to shrink
-- proportionally or they stay anchored to chemical-plant's original 3x3
-- geometry while the sprite itself renders smaller -- confirmed the hard
-- way as a real in-game smoke-plume misalignment on the first cut of this
-- file, which only rescaled `scale`/tint and left these untouched.
local SCALED_OFFSET_FIELDS = {
  "shift",
  "north_position",
  "east_position",
  "south_position",
  "west_position",
}

local function adjust_graphics(node, tint, scale_factor)
  if type(node) ~= "table" then
    return
  end
  if node.apply_recipe_tint then
    node.apply_recipe_tint = nil
    node.tint = tint
  end
  if type(node.scale) == "number" then
    node.scale = node.scale * scale_factor
  end
  for _, field in ipairs(SCALED_OFFSET_FIELDS) do
    local offset = node[field]
    if type(offset) == "table" and type(offset[1]) == "number" and type(offset[2]) == "number" then
      offset[1] = offset[1] * scale_factor
      offset[2] = offset[2] * scale_factor
    end
  end
  for _, value in pairs(node) do
    adjust_graphics(value, tint, scale_factor)
  end
end

local intake = util.table.deepcopy(data.raw["assembling-machine"]["chemical-plant"])

intake.name = "pr_pollution-intake"
intake.icon = "__base__/graphics/icons/chemical-plant.png"
intake.minable.result = "pr_pollution-intake"
intake.fast_replaceable_group = nil
intake.fixed_recipe = "pr_pollution-capture"
intake.crafting_categories = { "pr_pollution-intake-category" }

-- 2x2 footprint (same shape vanilla stone-furnace uses for its own 2x2
-- building), replacing chemical-plant's native 3x3 collision/selection box.
intake.collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } }
intake.selection_box = { { -0.85, -0.85 }, { 0.85, 0.85 } }

-- Two fluid boxes: water in (the scrubbing medium -- see pr_pollution-capture,
-- which consumes water 1:1 with the captured pollution it produces), captured
-- pollution out. Chemical-plant's other two boxes are dropped; leaving them in
-- place would ship a building with dangling, functionless pipe connections.
--
-- Connection positions must sit strictly inside the collision box, not at
-- the outer tile edge -- confirmed the hard way via a real Factorio load
-- error ("position must be inside of entity bounding box") against a first
-- attempt at chemical-plant's own unscaled {-1, 1}.
--
-- Searched every assembling-machine/furnace with fluid_boxes across all
-- ~90 currently-loaded mods (via `factorio --dump-data`, not just vanilla)
-- -- nothing smaller than a native 3x3 footprint exists anywhere to copy a
-- correctly-proportioned connector position from. So rather than picking
-- arbitrary centered points, these scale chemical-plant's own connection
-- positions -- genuinely off-center, not {0, +/-1} -- by the same
-- FOOTPRINT_SCALE already applied to the sprite's own scale/shift/smoke
-- anchors, keeping the (invisible) connectors geometrically consistent with
-- wherever chemical-plant's (visible, hand-painted) pipe stubs now render
-- in the scaled-down art. Still placeholder, still approximate -- exact
-- pixel alignment on borrowed 3x3 art isn't something static analysis can
-- fully guarantee -- but no longer an arbitrary guess.
--
-- Water input and pollution output sit at diagonally opposite corners --
-- water in at the north-west, pollution out at the south-east -- so the two
-- pipe runs stay as far apart as a 2x2 footprint allows and don't crowd each
-- other in a spread-out intake field.
intake.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = data.raw["assembling-machine"]["chemical-plant"].fluid_boxes[1].pipe_covers,
    volume = 1000,
    filter = "water",
    pipe_connections = {
      {
        flow_direction = "input",
        direction = defines.direction.north,
        position = { -1 * FOOTPRINT_SCALE, -1 * FOOTPRINT_SCALE },
      },
    },
  },
  {
    production_type = "output",
    pipe_covers = data.raw["assembling-machine"]["chemical-plant"].fluid_boxes[3].pipe_covers,
    volume = 100,
    filter = "pr_captured-pollution",
    pipe_connections = {
      {
        flow_direction = "output",
        direction = defines.direction.south,
        position = { 1 * FOOTPRINT_SCALE, 1 * FOOTPRINT_SCALE },
      },
    },
  },
}

-- Fully replaced, not merged: chemical-plant's own +4 pollution/min baseline
-- would otherwise silently stack underneath this building's absorption rate.
--
-- Scoped to pollution only, deliberately no spores handling — per the
-- pollution economy design doc, this capture/vent/process loop is
-- Nauvis-specific and does not extend to Gleba's spore mechanic.
--
-- -15/min matches the design doc's stated tier-1 target. First-pass
-- constant; expect this to move once the loop gets playtested.
intake.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  emissions_per_minute = { pollution = -15 },
}
intake.energy_usage = "75kW"

adjust_graphics(intake.graphics_set, { r = 0.55, g = 0.75, b = 0.25, a = 1 }, FOOTPRINT_SCALE)

data:extend({ intake })
