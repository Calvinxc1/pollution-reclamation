-- Thin entrypoint only, per governance: substantive logic lives in
-- src/control/pollution-condenser.lua, this file just wires Factorio's event
-- system into it.

local pollution_condenser = require("__pollution-reclamation__/control/pollution-condenser")
local sensor_gui = require("__pollution-reclamation__/runtime/sensor-gui")

local CONDENSER_ENTITY_NAME = "pr_pollution-condenser"
local SENSOR_ENTITY_NAME = "pr_pollution-sensor"

-- Both entity kinds share one tracked table: the sensor's whole job is to
-- report the number the gate tests, so it reads it through the same code.
local ROLE = {
  [CONDENSER_ENTITY_NAME] = "condenser",
  [SENSOR_ENTITY_NAME] = "sensor",
}

-- First-pass constants -- genuinely need playtesting to land right, per the
-- design doc's own balance notes. THRESHOLD is a minimum chunk pollution
-- stock (as returned by LuaSurface.get_pollution) required to keep an
-- condenser building running; ENTITIES_PER_TICK bounds how many tracked
-- buildings get re-checked per tick, keeping the cost flat regardless of
-- how many are built.
local POLLUTION_THRESHOLD = 10
local ENTITIES_PER_TICK = 4

local entity_filter = {
  { filter = "name", name = CONDENSER_ENTITY_NAME },
  { filter = "name", name = SENSOR_ENTITY_NAME, mode = "or" },
}

local function rescan_all_surfaces(state)
  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered({
      name = { CONDENSER_ENTITY_NAME, SENSOR_ENTITY_NAME },
    })
    for _, entity in pairs(found) do
      pollution_condenser.add_entity(state, entity.unit_number, entity, ROLE[entity.name])
    end
  end
end

local function init_storage()
  pollution_condenser.set_diodes(defines.entity_status_diode)
  pollution_condenser.set_circuit_wires({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green })
  -- Rebuilt from scratch rather than reused, so a save made before sensors
  -- existed, or before a state field was added, picks up both entity kinds
  -- and the current state shape.
  storage.pr_pollution_condenser = pollution_condenser.new_state()
  rescan_all_surfaces(storage.pr_pollution_condenser)
end

local function on_tracked_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  pollution_condenser.add_entity(storage.pr_pollution_condenser, entity.unit_number, entity, ROLE[entity.name])
end

local function on_tracked_removed(event)
  local entity = event.entity
  if not entity then
    return
  end
  pollution_condenser.remove_entity(storage.pr_pollution_condenser, entity.unit_number)
end

-- The 9 build/mine/died events below are meant to be the exhaustive set of
-- ways a condenser entity can enter or leave existence, so state.entities
-- should never actually contain an invalid reference by the time step()
-- runs. pcall here is cheap insurance against that assumption being wrong
-- in some edge case rather than a substitute for the event coverage --
-- logged instead of allowed to crash the tick and take scripting down with it.
local function on_tick()
  pollution_condenser.set_diodes(defines.entity_status_diode)
  pollution_condenser.set_circuit_wires({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green })
  local ok, err = pcall(pollution_condenser.step, storage.pr_pollution_condenser, POLLUTION_THRESHOLD, ENTITIES_PER_TICK)
  if not ok then
    log("pr_pollution-condenser gating step failed: " .. tostring(err))
  end
end

-- The sensor's own window, in place of the constant combinator's. Opening a
-- sensor hands the player this frame instead, and the signal they pick is
-- recorded against that sensor in the tracked state.
local function on_gui_opened(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == SENSOR_ENTITY_NAME) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  sensor_gui.open(player, entity, pollution_condenser.signal_of(storage.pr_pollution_condenser, entity.unit_number))
end

local function on_gui_closed(event)
  local element = event.element
  if element and element.valid and sensor_gui.is_sensor_frame(element) then
    local player = game.get_player(event.player_index)
    if player then
      sensor_gui.close(player)
    end
  end
end

local function on_gui_click(event)
  local element = event.element
  if element and element.valid and sensor_gui.is_close_button(element) then
    local player = game.get_player(event.player_index)
    if player then
      player.opened = nil
      sensor_gui.close(player)
    end
  end
end

local function on_gui_elem_changed(event)
  local element = event.element
  if not (element and element.valid and sensor_gui.is_signal_chooser(element)) then
    return
  end
  local unit_number = sensor_gui.opened_unit_number(event.player_index)
  if not unit_number then
    return
  end
  local state = storage.pr_pollution_condenser
  local signal = pollution_condenser.set_signal(state, unit_number, element.elem_value)
  -- Put the default back in the button when the player clears it, so the
  -- window always shows the signal the sensor actually outputs on.
  element.elem_value = signal
  local entity = state.entities[unit_number]
  if entity and entity.valid then
    pollution_condenser.report(entity, signal)
  end
end

script.on_init(init_storage)
script.on_configuration_changed(init_storage)

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)

-- Twice a second is plenty for a number a player is reading off a panel.
script.on_nth_tick(30, sensor_gui.refresh_all)

script.on_event(defines.events.on_tick, on_tick)

-- Additions: every way a condenser building can come into existence.
script.on_event(defines.events.on_built_entity, on_tracked_built, entity_filter)
script.on_event(defines.events.on_robot_built_entity, on_tracked_built, entity_filter)
script.on_event(defines.events.on_space_platform_built_entity, on_tracked_built, entity_filter)
script.on_event(defines.events.script_raised_built, on_tracked_built, entity_filter)

-- Removals: every way one can stop existing. on_entity_died covers biter
-- destruction specifically -- easy to forget since it isn't "mining", but
-- missing it lets the tracked table silently drift from reality, which for
-- this feature means a real condenser building that's never cleaned up and
-- never gets re-gated.
script.on_event(defines.events.on_player_mined_entity, on_tracked_removed, entity_filter)
script.on_event(defines.events.on_robot_mined_entity, on_tracked_removed, entity_filter)
script.on_event(defines.events.on_space_platform_mined_entity, on_tracked_removed, entity_filter)
script.on_event(defines.events.script_raised_destroy, on_tracked_removed, entity_filter)
script.on_event(defines.events.on_entity_died, on_tracked_removed, entity_filter)
