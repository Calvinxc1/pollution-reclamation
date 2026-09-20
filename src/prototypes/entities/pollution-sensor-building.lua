-- The sensor is built on vanilla's constant-combinator prototype, and that is
-- a plumbing decision rather than a design one: the constant combinator is the
-- only entity type in Factorio that can put an arbitrary, script-set value on
-- a circuit wire. Everything else with a circuit connector either takes input
-- (lamps, inserters) or reports something fixed like charge or contents.
--
-- What the player sees is this mod's own sensor: our sprite, our name, one
-- output signal carrying the chunk's pollution. The only inherited behaviour
-- is "has a circuit output".
--
-- The trade is power: a constant combinator has no energy source, so the
-- sensor cannot require electricity. It reads wherever it is planted, which
-- suits a scouting instrument.
--
-- The art is placeholder, like the rest of the mod: a squat steel housing on
-- a bolted base plate, blue band, green readout, top intake grille. The
-- source render is kept in docs/icon-candidates/.
local sensor = util.table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])

sensor.name = "pr_pollution-sensor"
sensor.minable = { mining_time = 0.1, result = "pr_pollution-sensor" }
sensor.fast_replaceable_group = nil
sensor.next_upgrade = nil
sensor.icon = "__pollution-reclamation__/graphics/icons/entities/pollution-sensor.png"
sensor.icon_size = 64
-- The icon file is a 120x64 mipmap strip (64+32+16+8), like every other icon
-- in this mod. Without this the engine reads only the first square and the
-- icon renders unsmoothed everywhere it is drawn small.
sensor.icon_mipmaps = 4
sensor.icon_draw_specification = nil

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

-- One sprite for all four directions: the device is round and reads the same
-- from every side, so rotating it changes nothing.
sensor.sprites = {
  north = util.table.deepcopy(picture),
  east = util.table.deepcopy(picture),
  south = util.table.deepcopy(picture),
  west = util.table.deepcopy(picture),
}

-- No blinking activity light: that is combinator furniture, and this is a
-- gauge. The readout already glows in the art. The sprites are replaced with
-- empty ones rather than removed, because the prototype requires the LED's
-- light offsets to exist -- those are kept, pointing at nothing.
sensor.activity_led_sprites = {
  north = util.empty_sprite(),
  east = util.empty_sprite(),
  south = util.empty_sprite(),
  west = util.empty_sprite(),
}
sensor.activity_led_light = nil

data:extend({ sensor })
