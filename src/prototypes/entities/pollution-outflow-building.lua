-- Placeholder entity: deep-copied and re-tinted from vanilla chemical-plant
-- until this mod has a custom-art pipeline. Only the fields below are
-- deliberately overridden; everything else (sounds, circuit connector,
-- corpse, etc.) is inherited as-is from the copy.

-- See pollution-intake-building.lua for why this shrinks chemical-plant's
-- native 3x3 footprint down to 2x2, and rescales/repositions the inherited
-- sprite and fluid connection to match.
local FOOTPRINT_SCALE = 2 / 3

-- See pollution-intake-building.lua for why this strips chemical-plant's
-- per-recipe dynamic tint in favor of a flat static one, and rescales every
-- sprite layer at the same time -- including the smoke plume's per-direction
-- anchor points and each layer's `shift`, not just `scale`, or the smoke
-- stays anchored to the original 3x3 geometry while the body shrinks.
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

local outflow = util.table.deepcopy(data.raw["assembling-machine"]["chemical-plant"])

outflow.name = "pr_pollution-outflow"
outflow.icon = "__base__/graphics/icons/chemical-plant.png"
outflow.minable.result = "pr_pollution-outflow"
outflow.fast_replaceable_group = nil
outflow.fixed_recipe = "pr_pollution-venting"
outflow.crafting_categories = { "pr_pollution-outflow-category" }

-- 2x2 footprint, same shape as intake, replacing chemical-plant's native
-- 3x3 collision/selection box.
outflow.collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } }
outflow.selection_box = { { -0.85, -0.85 }, { 0.85, 0.85 } }

-- Outflow only ever consumes fluid, so it keeps only chemical-plant's first
-- input fluid box and drops the other three entirely. See
-- pollution-intake-building.lua for why the connection position is
-- chemical-plant's own {-1, -1} scaled by FOOTPRINT_SCALE, not an arbitrary
-- centered point or its unscaled tile-edge value.
outflow.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = data.raw["assembling-machine"]["chemical-plant"].fluid_boxes[1].pipe_covers,
    volume = 1000,
    pipe_connections = {
      {
        flow_direction = "input",
        direction = defines.direction.north,
        position = { -1 * FOOTPRINT_SCALE, -1 * FOOTPRINT_SCALE },
      },
    },
  },
}

-- Fully replaced, not merged, for the same reason as intake. Tier-1 outflow
-- is deliberately "omnidirectional, no control at all" per the design doc —
-- plain positive emissions while crafting is the whole mechanism, no
-- pollute()-based scripting needed until a later, directional tier.
--
-- Base rate matches intake's nominal 15/min; the process recipe's own
-- emissions_multiplier (see pr_pollution-venting in recipes.lua) pushes the
-- effective vent rate above that, making the round trip deliberately lossy
-- per the design doc's biter-aggro risk mitigation. First-pass constant.
outflow.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  emissions_per_minute = { pollution = 15 },
}
outflow.energy_usage = "75kW"

adjust_graphics(outflow.graphics_set, { r = 0.85, g = 0.4, b = 0.2, a = 1 }, FOOTPRINT_SCALE)

data:extend({ outflow })
