-- Placeholder art, like the rest of the mod, but the sensor's own: a squat
-- steel housing on a bolted base plate, blue band, green readout, top intake
-- grille. Rendered outside the repo; the source render is kept in
-- docs/icon-candidates/.
--
-- The prototype is still a deep copy of vanilla small-lamp, for its behaviour
-- rather than its looks: a lamp is 1x1, takes power, shows an entity status
-- line, and can be always-on. Only the sprites and power are overridden.
--
-- The sensor absorbs nothing. It is tracked alongside condensers purely so it
-- reports the same chunk pollution the gate tests, through the same code --
-- see src/control/pollution-condenser.lua.
local sensor = util.table.deepcopy(data.raw["lamp"]["small-lamp"])

sensor.name = "pr_pollution-sensor"
sensor.minable.result = "pr_pollution-sensor"
sensor.fast_replaceable_group = nil
sensor.next_upgrade = nil
sensor.icon = "__pollution-reclamation__/graphics/icons/entities/pollution-sensor.png"
sensor.icon_size = 64

-- 64 image pixels at scale 0.5 is 32 screen pixels, one tile wide. The shift
-- drops the base plate onto the tile instead of centring the whole sprite,
-- which would leave the device floating half a tile high.
local picture = {
  filename = "__pollution-reclamation__/graphics/entities/pollution-sensor.png",
  priority = "high",
  width = 96,
  height = 96,
  scale = 0.5,
  shift = util.by_pixel(0, -6),
}

sensor.picture_off = picture
sensor.picture_on = util.table.deepcopy(picture)

-- No lamp behaviour beyond the prototype base: the sensor is not a light. The
-- readout already glows in the art, so every one of vanilla lamp's lighting
-- fields is cleared, and picture_on is the same sprite as picture_off. The
-- device therefore looks identical powered or not, day or night, instead of
-- washing green the way a coloured lamp would.
sensor.always_on = true
sensor.light = nil
sensor.light_when_colored = nil
sensor.glow_size = 0
sensor.glow_color_intensity = 0
sensor.glow_render_mode = nil
sensor.signal_to_color_mapping = nil
sensor.darkness_for_all_lamps_on = nil
sensor.darkness_for_all_lamps_off = nil
sensor.energy_usage_per_tick = "500W"

-- Trivial but non-zero draw: the reading should go dark when the power does,
-- so an unpowered sensor is honestly blank rather than quietly stale.
sensor.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
}

data:extend({ sensor })
