-- Thin entrypoint only, per governance: substantive logic lives in
-- src/control/pollution-intake.lua, this file just wires Factorio's event
-- system into it.

local pollution_intake = require("__pollution-reclamation__/control/pollution-intake")

local INTAKE_ENTITY_NAME = "pr_pollution-intake"

-- First-pass constants -- genuinely need playtesting to land right, per the
-- design doc's own balance notes. THRESHOLD is a minimum chunk pollution
-- stock (as returned by LuaSurface.get_pollution) required to keep an
-- intake building running; ENTITIES_PER_TICK bounds how many tracked
-- buildings get re-checked per tick, keeping the cost flat regardless of
-- how many are built.
local POLLUTION_THRESHOLD = 10
local ENTITIES_PER_TICK = 4

local entity_filter = { { filter = "name", name = INTAKE_ENTITY_NAME } }

local function rescan_all_surfaces(state)
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ name = INTAKE_ENTITY_NAME })) do
      pollution_intake.add_entity(state, entity.unit_number, entity)
    end
  end
end

local function init_storage()
  storage.pr_pollution_intake = storage.pr_pollution_intake or pollution_intake.new_state()
  rescan_all_surfaces(storage.pr_pollution_intake)
end

local function on_intake_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  pollution_intake.add_entity(storage.pr_pollution_intake, entity.unit_number, entity)
end

local function on_intake_removed(event)
  local entity = event.entity
  if not entity then
    return
  end
  pollution_intake.remove_entity(storage.pr_pollution_intake, entity.unit_number)
end

-- The 9 build/mine/died events below are meant to be the exhaustive set of
-- ways an intake entity can enter or leave existence, so state.entities
-- should never actually contain an invalid reference by the time step()
-- runs. pcall here is cheap insurance against that assumption being wrong
-- in some edge case rather than a substitute for the event coverage --
-- logged instead of allowed to crash the tick and take scripting down with it.
local function on_tick()
  local ok, err = pcall(pollution_intake.step, storage.pr_pollution_intake, POLLUTION_THRESHOLD, ENTITIES_PER_TICK)
  if not ok then
    log("pr_pollution-intake gating step failed: " .. tostring(err))
  end
end

script.on_init(init_storage)
script.on_configuration_changed(init_storage)

script.on_event(defines.events.on_tick, on_tick)

-- Additions: every way an intake building can come into existence.
script.on_event(defines.events.on_built_entity, on_intake_built, entity_filter)
script.on_event(defines.events.on_robot_built_entity, on_intake_built, entity_filter)
script.on_event(defines.events.on_space_platform_built_entity, on_intake_built, entity_filter)
script.on_event(defines.events.script_raised_built, on_intake_built, entity_filter)

-- Removals: every way one can stop existing. on_entity_died covers biter
-- destruction specifically -- easy to forget since it isn't "mining", but
-- missing it lets the tracked table silently drift from reality, which for
-- this feature means a real intake building that's never cleaned up and
-- never gets re-gated.
script.on_event(defines.events.on_player_mined_entity, on_intake_removed, entity_filter)
script.on_event(defines.events.on_robot_mined_entity, on_intake_removed, entity_filter)
script.on_event(defines.events.on_space_platform_mined_entity, on_intake_removed, entity_filter)
script.on_event(defines.events.script_raised_destroy, on_intake_removed, entity_filter)
script.on_event(defines.events.on_entity_died, on_intake_removed, entity_filter)
