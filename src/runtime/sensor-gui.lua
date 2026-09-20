-- The pollution sensor's own window.
--
-- The sensor is a constant combinator underneath, purely because that is the
-- only entity type that can put a script-set value on a circuit wire. That
-- prototype's stock window is all logistic sections and slots, which has
-- nothing to do with a gauge, so opening a sensor opens this instead: the
-- current reading, and one picker for the signal it outputs on.
--
-- This file is deliberately NOT under src/control/, which is reserved for
-- pure, dependency-injected logic that the plain-Lua tests can load. GUI code
-- cannot be pure -- it needs players, elements and storage -- so it lives
-- here, and the gate logic it drives stays testable on its own.
local M = {}

local FRAME_NAME = "pr_sensor_frame"
local SIGNAL_CHOOSER_NAME = "pr_sensor_signal"
local CLOSE_BUTTON_NAME = "pr_sensor_close"

local function open_frames()
  storage.pr_sensor_frames = storage.pr_sensor_frames or {}
  return storage.pr_sensor_frames
end

-- The reading, phrased the same way as the status line the sensor shows when
-- a player stands next to it, so the two never disagree.
local function reading_caption(entity)
  local surface = entity.surface
  local pollutant = surface.pollutant_type
  if not (pollutant and pollutant.name == "pollution") then
    return { "pr-sensor.no-pollutant" }
  end
  local pollution = math.floor(surface.get_pollution(entity.position) + 0.5)
  return { "pr-sensor.pollution", tostring(pollution) }
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

  local content = frame.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  local reading = content.add({ type = "label", caption = reading_caption(entity) })

  local chooser_row = content.add({ type = "flow", direction = "horizontal" })
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

  open_frames()[player.index] = {
    frame = frame,
    reading = reading,
    unit_number = entity.unit_number,
    entity = entity,
  }
  player.opened = frame
end

-- Refreshes the reading in any open window. Cheap: at most one frame per
-- player, and only while a sensor is open.
function M.refresh_all()
  local frames = open_frames()
  for player_index, open in pairs(frames) do
    local player = game.get_player(player_index)
    local usable = player and open.frame and open.frame.valid
      and open.entity and open.entity.valid and open.reading and open.reading.valid
    if not usable then
      frames[player_index] = nil
    else
      open.reading.caption = reading_caption(open.entity)
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

function M.is_sensor_frame(element)
  return element.valid and element.name == FRAME_NAME
end

return M
