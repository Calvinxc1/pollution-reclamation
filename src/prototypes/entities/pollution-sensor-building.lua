-- Placeholder entity: deep-copied from vanilla small-lamp until this mod has
-- a custom-art pipeline. A lamp is a good stand-in: 1x1, powered, and it
-- shows an entity status line, which is where the sensor writes its reading.
--
-- The sensor absorbs nothing. It is tracked alongside condensers purely so it
-- reports the same chunk pollution the gate tests, through the same code --
-- see src/control/pollution-condenser.lua.
local sensor = util.table.deepcopy(data.raw["lamp"]["small-lamp"])

sensor.name = "pr_pollution-sensor"
sensor.minable.result = "pr_pollution-sensor"
sensor.fast_replaceable_group = nil
sensor.next_upgrade = nil
sensor.icon = "__base__/graphics/icons/small-lamp.png"

-- Always lit, so a placed sensor reads as "on" at a glance, and tinted to
-- match the condenser's green rather than a plain white lamp.
sensor.always_on = true
sensor.light = { intensity = 0.5, size = 6, color = { r = 0.55, g = 0.85, b = 0.45 } }
sensor.glow_color_intensity = 0.5
sensor.energy_usage_per_tick = "500W"

-- Trivial but non-zero draw: the reading should go dark when the power does,
-- so an unpowered sensor is honestly blank rather than quietly stale.
sensor.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
}

data:extend({ sensor })
