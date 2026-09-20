-- The pollution sensor's window.
--
-- The sensor is a constant combinator underneath, purely because that is the
-- only entity type that can put a script-set value on a circuit wire. That
-- prototype's stock window is all logistic sections and slots, which has
-- nothing to do with a gauge, so opening a sensor opens this instead.
--
-- This reproduces the shape of a vanilla entity window -- status line, entity
-- preview, and a circuit panel beside it holding the one setting the sensor
-- has -- rather than inventing a layout. It has to be a reproduction: the
-- engine builds an entity's real circuit panel from that prototype's own
-- control behaviour, and a mod cannot add a control to it. `player.gui.relative`
-- can only anchor a separate frame to one of the 79 stock GUI types, on one of
-- four sides; there is no anchor inside the circuit panel itself. So the panel
-- here is ours, built from the same vanilla styles the engine uses.
--
-- This file is deliberately NOT under src/control/, which is reserved for
-- pure, dependency-injected logic that the plain-Lua tests can load. GUI code
-- cannot be pure -- it needs players, elements and storage -- so it lives
-- here, and the gate logic it drives stays testable on its own.
local pollution_condenser = require("__pollution-reclamation__/control/pollution-condenser")

local M = {}

local FRAME_NAME = "pr_sensor_frame"
local SIGNAL_CHOOSER_NAME = "pr_sensor_signal"
local CLOSE_BUTTON_NAME = "pr_sensor_close"
local CIRCUIT_TOGGLE_NAME = "pr_sensor_circuit_toggle"

local WIRES = {
  { id = defines.wire_connector_id.circuit_red, label = "pr-sensor.red-network" },
  { id = defines.wire_connector_id.circuit_green, label = "pr-sensor.green-network" },
}

local function open_frames()
  storage.pr_sensor_frames = storage.pr_sensor_frames or {}
  return storage.pr_sensor_frames
end

-- Which networks the sensor is actually on, the way vanilla's panel reports it.
local function network_caption(entity)
  local parts = { "" }
  for _, wire in ipairs(WIRES) do
    local network = entity.get_circuit_network(wire.id)
    if network then
      if #parts > 1 then
        parts[#parts + 1] = "\n"
      end
      parts[#parts + 1] = { wire.label, tostring(network.network_id) }
    end
  end
  if #parts == 1 then
    return { "pr-sensor.not-connected" }
  end
  return parts
end

function M.close(player)
  local frames = open_frames()
  local open = frames[player.index]
  if open and open.frame and open.frame.valid then
    open.frame.destroy()
  end
  frames[player.index] = nil
end

-- Opens the sensor's window and hands it to the player as their open GUI, so
-- the combinator's own window never appears and Esc closes this one.
function M.open(player, entity, signal)
  M.close(player)

  local frame = player.gui.screen.add({
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical",
  })
  frame.auto_center = true

  local titlebar = frame.add({ type = "flow", direction = "horizontal" })
  titlebar.drag_target = frame
  titlebar.add({
    type = "label",
    caption = entity.localised_name,
    style = "frame_title",
    ignored_by_interaction = true,
  })
  local filler = titlebar.add({ type = "empty-widget", style = "draggable_space_header" })
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  filler.drag_target = frame
  titlebar.add({
    type = "sprite-button",
    name = CLOSE_BUTTON_NAME,
    style = "frame_action_button",
    sprite = "utility/close",
    hovered_sprite = "utility/close",
    clicked_sprite = "utility/close",
  })

  -- Entity window on the left, circuit panel on the right, as vanilla lays out
  -- anything with a circuit connection.
  local columns = frame.add({ type = "flow", direction = "horizontal" })
  columns.style.horizontal_spacing = 12

  local body = columns.add({ type = "frame", style = "entity_frame", direction = "vertical" })

  local status_row = body.add({ type = "flow", direction = "horizontal" })
  status_row.style.vertical_align = "center"
  local status = status_row.add({ type = "sprite", style = "status_image" })
  local reading = status_row.add({ type = "label" })
  reading.style.left_margin = 4

  local preview_frame = body.add({ type = "frame", style = "entity_button_frame" })
  local preview = preview_frame.add({ type = "entity-preview", style = "wide_entity_button" })
  preview.entity = entity

  -- Vanilla's own way in when nothing is wired yet: a circuit-network button
  -- that opens the panel by hand.
  local footer = body.add({ type = "flow", direction = "horizontal" })
  footer.style.top_margin = 8
  footer.add({
    type = "sprite-button",
    name = CIRCUIT_TOGGLE_NAME,
    style = "frame_action_button",
    sprite = "utility/circuit_network_panel",
    tooltip = { "pr-sensor.circuit-network" },
  })

  local circuit = columns.add({ type = "frame", style = "entity_frame", direction = "vertical" })
  circuit.add({ type = "label", style = "heading_2_label", caption = { "pr-sensor.circuit-network" } })
  local network = circuit.add({ type = "label" })
  network.style.top_margin = 4

  local chooser_row = circuit.add({ type = "flow", direction = "horizontal" })
  chooser_row.style.vertical_align = "center"
  chooser_row.style.top_margin = 8
  chooser_row.add({ type = "label", caption = { "pr-sensor.output-signal" } })
  local chooser = chooser_row.add({
    type = "choose-elem-button",
    name = SIGNAL_CHOOSER_NAME,
    elem_type = "signal",
    signal = signal,
  })
  chooser.style.left_margin = 8

  local open = {
    frame = frame,
    status = status,
    reading = reading,
    network = network,
    circuit = circuit,
    unit_number = entity.unit_number,
    entity = entity,
    -- Until the player touches the button, the panel follows the wiring the
    -- way vanilla's does: shown when connected, out of the way when not.
    pinned = false,
  }
  open_frames()[player.index] = open

  M.refresh(open)
  player.opened = frame
end

-- Toggles the circuit panel by hand, and stops the wiring driving it after
-- that: the player asked for it open, so it stays open.
function M.toggle_circuit(player)
  local open = open_frames()[player.index]
  if not (open and open.circuit and open.circuit.valid) then
    return
  end
  open.pinned = true
  open.circuit.visible = not open.circuit.visible
end

function M.refresh(open)
  local entity = open.entity
  -- Read and phrased through the gate's own helpers, never recomputed here:
  -- the window has to show the number the gate tests, and a second copy of
  -- that arithmetic is exactly how the two would drift apart.
  local reading = pollution_condenser.reading(entity)
  open.reading.caption = pollution_condenser.status_label(reading)
  open.status.sprite = pollution_condenser.is_pollution(reading)
    and "utility/status_working"
    or "utility/status_inactive"
  open.network.caption = network_caption(entity)
  if not open.pinned then
    open.circuit.visible = pollution_condenser.is_connected(entity)
  end
end

-- Refreshes any open window. Cheap: at most one frame per player, and only
-- while a sensor is open.
function M.refresh_all()
  local frames = open_frames()
  for player_index, open in pairs(frames) do
    local player = game.get_player(player_index)
    local usable = player and open.frame and open.frame.valid
      and open.entity and open.entity.valid
      and open.reading and open.reading.valid
      and open.status and open.status.valid
      and open.network and open.network.valid
      and open.circuit and open.circuit.valid
    if not usable then
      frames[player_index] = nil
    else
      M.refresh(open)
    end
  end
end

-- Which sensor a player has open, if any; used to route their signal choice
-- back to the right entity.
function M.opened_unit_number(player_index)
  local open = open_frames()[player_index]
  return open and open.unit_number or nil
end

function M.is_signal_chooser(element)
  return element.valid and element.name == SIGNAL_CHOOSER_NAME
end

function M.is_close_button(element)
  return element.valid and element.name == CLOSE_BUTTON_NAME
end

function M.is_circuit_toggle(element)
  return element.valid and element.name == CIRCUIT_TOGGLE_NAME
end

function M.is_sensor_frame(element)
  return element.valid and element.name == FRAME_NAME
end

return M
