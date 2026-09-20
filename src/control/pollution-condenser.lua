-- Pure per-chunk pollution logic, shared by both buildings that care about it:
-- a rolling `next()` cursor over one tracked-entities table, visiting a small
-- slice per tick. What a visit does depends on the entity's role --
--
--   * condenser: toggled offline when its chunk doesn't have enough ambient
--     pollution to back a real craft;
--   * sensor: never gated, but its status line and circuit output updated
--     with the very number the gate tests, plus the signal the player chose
--     for it.
--
-- One table and one set of helpers on purpose. The sensor's whole job is to
-- report the rule, so it must not be able to disagree with it; a second copy
-- of the arithmetic is exactly how that happens, and did once (see
-- `is_pollution`).
--
-- The file is still named for the condenser because the storage key and the
-- module path are the ones a shipped save already refers to. The name is
-- historical; the contents are not condenser-only.
--
-- Deliberately dependency-injected: nothing in this file touches `game`,
-- `storage`, or `script`. `state`, `threshold` and `slice_count` are always
-- passed in explicitly, and the engine's `defines` constants are handed in by
-- control.lua rather than read here. Pollution is read through each entity's
-- own `.surface`, which a fake entity in the tests supplies as readily as a
-- real one does. That's what lets this exact file load two different ways
-- with no contradiction between them: from real Factorio via
-- `require("__pollution-reclamation__/control/pollution-condenser")`, and
-- from the plain-Lua test runner via `dofile(...)`.
--
-- Trust boundary: this module does not check entity validity. The adapter
-- (control.lua) is responsible for keeping `state.entities` free of invalid
-- entities via Factorio's build/mine/died events before calling into this
-- module -- that's the one piece of behavior these unit tests structurally
-- can't exercise (a plain Lua table has no such thing as "invalid"), so it's
-- kept out of here on purpose rather than half-tested.

local M = {}

-- defines.entity_status_diode values, injected by control.lua so this file
-- stays loadable outside Factorio. The defaults are the engine's own
-- numbering, confirmed in a headless run, and are what the plain-Lua tests
-- see.
M.DIODE = { green = 0, red = 1, yellow = 2 }

function M.set_diodes(diodes)
  M.DIODE = diodes
end

-- defines.wire_connector_id values for the two circuit wires, injected the
-- same way. The defaults are the engine's own numbering.
M.CIRCUIT_WIRES = { 0, 1 }

function M.set_circuit_wires(wire_ids)
  M.CIRCUIT_WIRES = wire_ids
end

-- The only pollutant this mod's economy is built on. Everything that reads a
-- surface -- the gate and the sensor alike -- measures against this one name.
M.POLLUTANT = "pollution"

function M.new_state()
  return {
    -- Every tracked building, by key, for lookups that start from an entity
    -- (the sensor window asking for its own signal, say).
    entities = {},
    -- The chunk index, and the thing the walk actually iterates. Pollution is
    -- stored per chunk and the gate's verdict is per chunk and all-or-nothing,
    -- so both ends of the calculation are chunk-scoped; walking buildings
    -- meant reading the same chunk's pollution once per building and writing
    -- the same answer to each of them. Each record is
    --   { condensers = {key->true}, sensors = {key->true},
    --     condenser_count = n, applied = nil|boolean }
    -- and only chunks that actually hold a tracked building appear here --
    -- never the map's chunks at large, which on a big save outnumber these by
    -- orders of magnitude.
    chunks = {},
    -- Where the chunk walk is up to.
    cursor = nil,
    -- Which chunk each key belongs to. Buildings never move, so this is
    -- recorded once, at add time.
    entity_chunk = {},
    -- "condenser" for the buildings the gate switches on and off, "sensor"
    -- for pollution sensors. Sensors share the tracking so they report the
    -- very number the gate tests, but they absorb nothing, so they must not
    -- count toward a chunk's condenser population.
    roles = {},
    -- The signal each sensor outputs on, keyed the same way as entities and
    -- chosen by the player in the sensor's window. Absent means the default.
    signals = {},
  }
end

local function chunk_record(state, chunk)
  local record = state.chunks[chunk]
  if record == nil then
    record = { condensers = {}, sensors = {}, condenser_count = 0, applied = nil }
    state.chunks[chunk] = record
  end
  return record
end

-- Chunks are 32x32 tiles, and pollution is stored per chunk, so every
-- condenser in the same chunk of the same surface draws on one shared pool.
local CHUNK_SIZE = 32

function M.chunk_key(entity)
  local position = entity.position
  local surface_index = entity.surface.index or 1
  return ("%s:%d:%d"):format(
    surface_index,
    math.floor(position.x / CHUNK_SIZE),
    math.floor(position.y / CHUNK_SIZE)
  )
end

function M.add_entity(state, key, entity, role)
  role = role or "condenser"
  if state.entities[key] == nil then
    local chunk = M.chunk_key(entity)
    local record = chunk_record(state, chunk)
    state.entity_chunk[key] = chunk
    state.roles[key] = role
    if role == "sensor" then
      record.sensors[key] = true
    else
      record.condensers[key] = true
      record.condenser_count = record.condenser_count + 1
      -- One more condenser raises the bar for every condenser in the chunk,
      -- so whatever was decided last time no longer applies to any of them.
      record.applied = nil
    end
  end
  state.entities[key] = entity
end

-- How many tracked condensers sit in this entity's chunk. For a condenser
-- that includes itself; for a sensor it's the condensers it is reporting on,
-- which may be none.
function M.chunk_population(state, key)
  local chunk = state.entity_chunk[key]
  local record = chunk and state.chunks[chunk]
  return (record and record.condenser_count) or 0
end

-- Safe against the classic next()-after-delete pitfall: if the cursor is
-- currently sitting on the key being removed, advance it *before* the key
-- disappears from the table, while `next` can still find it. Calling
-- `next(t, k)` after `k` has already been removed from `t` is not something
-- Lua promises will work.
function M.remove_entity(state, key)
  local chunk = state.entity_chunk[key]
  if state.entities[key] ~= nil and chunk then
    local record = state.chunks[chunk]
    if record then
      if state.roles[key] == "sensor" then
        record.sensors[key] = nil
      else
        record.condensers[key] = nil
        record.condenser_count = record.condenser_count - 1
        -- One fewer condenser lowers the bar for the rest, so the cached
        -- verdict has to be recomputed rather than reused.
        record.applied = nil
      end
      if next(record.condensers) == nil and next(record.sensors) == nil then
        -- Last building in this chunk: drop the chunk from the walk. Advance
        -- the cursor first, while `next` can still find this key -- calling
        -- next(t, k) after k has been removed from t is not something Lua
        -- promises will work.
        if state.cursor == chunk then
          state.cursor = next(state.chunks, chunk)
        end
        state.chunks[chunk] = nil
      end
    end
    state.entity_chunk[key] = nil
  end
  state.roles[key] = nil
  state.signals[key] = nil
  state.entities[key] = nil
end

-- The condenser only absorbs `pollution` (its emissions_per_minute names no
-- other pollutant), but get_pollution() reports whatever pollutant the
-- surface uses: spores on Gleba, nothing at all on Vulcanus, Fulgora, or
-- Aquilo. Without this check a condenser on Gleba would pass the threshold on
-- spores, absorb nothing, and make polluted water for free. The pollution
-- economy is Nauvis-only by design; Gleba gets its own mechanic later.
-- `population` is how many tracked condensers share this one's chunk. The
-- threshold is per condenser, so a chunk has to hold `threshold * population`
-- before any of them may run: all of them or none.
--
-- A single per-condenser floor is not enough, because the gate only re-checks
-- a slice of the tracked condensers each tick. Between one condenser's checks,
-- every condenser in its chunk keeps drawing on the same pool, and the engine
-- simply stops absorbing once the chunk reaches zero -- while the recipes keep
-- running and keep producing fluid that no removed pollution backs. Measured
-- 2026-09-19 with 225 condensers packed into one chunk holding 60 pollution:
-- 71.8 units' worth of fluid came out of 56 units actually removed, about 29%
-- of it unbacked.
--
-- All-or-nothing rather than running as many as the chunk can afford: every
-- condenser in a chunk reads the same number, so the decision needs no
-- arbitration between them and no rotation to keep it fair, and crowding a
-- chunk is the play the design wants to discourage anyway.
function M.can_capture(reading, threshold, population)
  if not M.is_pollution(reading) then
    return false
  end
  return reading.pollution >= threshold * (population or 1)
end

-- What a pollution sensor reports: the same chunk pollution the gate tests,
-- read through the same helpers, so the number a player sees cannot drift
-- from the number that decides whether condensers run.
--
-- Deliberately pollution and nothing else. The tracking knows how many
-- condensers share the chunk and what they need, and a later sensor tier may
-- well show that, but tier 1 is one number.
function M.reading(entity)
  local surface = entity.surface
  local pollutant = surface.pollutant_type
  return {
    pollutant = pollutant and pollutant.name or nil,
    pollution = (pollutant and surface.get_pollution(entity.position)) or 0,
  }
end

-- Gleba's spores come back through the same get_pollution call, and a surface
-- with no pollutant at all reports nothing. The gate already refuses to absorb
-- either, so a sensor must not report either as pollution -- otherwise the
-- number a player reads and the number that decides whether condensers run
-- part company on exactly the surface where it matters.
function M.is_pollution(reading)
  return reading.pollutant == M.POLLUTANT
end

function M.rounded(reading)
  return math.floor(reading.pollution + 0.5)
end

-- The one phrasing of a reading, shared by the status line a player sees
-- standing next to a sensor and by the sensor's window, so the two cannot
-- disagree.
function M.status_label(reading)
  if not M.is_pollution(reading) then
    return { "pr-sensor.no-pollutant" }
  end
  return { "pr-sensor.pollution", tostring(M.rounded(reading)) }
end

-- The signal a freshly placed sensor outputs on, until the player picks
-- another in the sensor's window.
M.DEFAULT_SIGNAL = { type = "virtual", name = "signal-P", quality = "normal" }

-- The signal a given sensor outputs on.
function M.signal_of(state, key)
  return state.signals[key] or M.DEFAULT_SIGNAL
end

-- Records the player's choice. Passing nil restores the default rather than
-- leaving the sensor with nothing to output on.
function M.set_signal(state, key, signal)
  if signal and signal.name then
    state.signals[key] = signal
  else
    state.signals[key] = nil
  end
  return M.signal_of(state, key)
end

-- The sensor is a constant combinator underneath, so its output is one
-- logistic section, whose first slot this owns outright: the player never
-- edits it (they pick a signal in the sensor's own window instead), so it is
-- simply rewritten each update from the tracked signal and the reading.
-- Whether anything is actually wired to this sensor, on either circuit wire.
-- `or_create = false`, so asking does not itself create a connector.
function M.is_connected(entity)
  for _, wire_id in ipairs(M.CIRCUIT_WIRES) do
    local connector = entity.get_wire_connector(wire_id, false)
    if connector and (connector.connection_count or 0) > 0 then
      return true
    end
  end
  return false
end

-- Puts `value` on the sensor's circuit output, keeping the player's chosen
-- signal.
--
-- An unwired sensor outputs nothing: its control behavior is switched off
-- rather than its slot cleared, so the signal the player picked survives
-- being disconnected and comes back with the wire. The status line beside the
-- sensor keeps reading either way -- that is what it is for.
function M.write_signal(entity, value, signal)
  local behavior = entity.get_or_create_control_behavior()
  if not behavior then
    return
  end
  if not M.is_connected(entity) then
    behavior.enabled = false
    return
  end
  behavior.enabled = true
  local section = behavior.get_section(1) or behavior.add_section()
  if not section then
    return
  end
  section.set_slot(1, { value = signal or M.DEFAULT_SIGNAL, min = value })
end

-- Writes the reading onto the entity: a custom status line for a player
-- standing next to it, and the same number on its circuit output.
function M.report(entity, reading, signal)
  local pollution = M.is_pollution(reading)
  entity.custom_status = {
    diode = pollution and M.DIODE.green or M.DIODE.yellow,
    label = M.status_label(reading),
  }
  M.write_signal(entity, pollution and M.rounded(reading) or 0, signal)
  return reading
end

-- Everything one chunk needs, off one pollution read.
--
-- Sensors still get individual attention -- each has its own status line and
-- its own circuit output -- but they read from this sample rather than each
-- fetching the same number again, which is also what keeps a sensor and the
-- condensers beside it from ever reporting different pollution.
--
-- Condensers get the verdict applied only when it has actually changed.
-- `record.applied` is what was last written to this chunk's condensers, so a
-- chunk sitting comfortably above or below its bar costs one read and two
-- comparisons per visit and touches no entity at all. That is the whole point
-- of the chunk index: at rest, which is nearly always, the walk is almost
-- free no matter how many buildings are standing in it.
--
-- The trade is that another mod setting `disabled_by_script` on one of our
-- condensers would not be corrected until the chunk's verdict next flips.
-- Nothing else has business touching it, membership changes invalidate the
-- cache, and `control.lua` rebuilds the whole state on every mod change, so
-- any drift clears on the next update.
function M.visit_chunk(state, record, threshold)
  local sample = nil
  for key in pairs(record.condensers) do
    sample = state.entities[key]
    if sample then break end
  end
  if sample == nil then
    for key in pairs(record.sensors) do
      sample = state.entities[key]
      if sample then break end
    end
  end
  if sample == nil then
    return
  end

  local reading = M.reading(sample)

  for key in pairs(record.sensors) do
    local entity = state.entities[key]
    if entity then
      M.report(entity, reading, M.signal_of(state, key))
    end
  end

  if record.condenser_count == 0 then
    return
  end

  local allowed = M.can_capture(reading, threshold, record.condenser_count)
  if record.applied == allowed then
    return
  end
  local disabled = not allowed
  for key in pairs(record.condensers) do
    local entity = state.entities[key]
    if entity then
      entity.disabled_by_script = disabled
    end
  end
  record.applied = allowed
end

-- Visits up to `slice_count` chunks that hold tracked buildings, wrapping
-- around automatically when the cursor runs off the end of the table (`next`
-- returns nil), so it never needs to know how many there are up front.
--
-- The slice is chunks, not buildings. A chunk holding twenty condensers costs
-- the same visit as one holding a single sensor, because pollution is stored
-- per chunk and the verdict is per chunk: the work a visit does is one read
-- and one comparison, plus writes only where something actually changed.
--
-- Order across chunks is deliberately NOT a contract of this function --
-- Factorio's own `next`/`pairs` is a deterministic-but-insertion-order
-- reimplementation that no stock Lua interpreter reproduces, so callers (and
-- tests) should only rely on "every chunk gets visited eventually", never on
-- a specific sequence.
function M.step(state, threshold, slice_count)
  for _ = 1, slice_count do
    local chunk = state.cursor
    if chunk == nil then
      chunk = next(state.chunks, nil)
    end
    if chunk == nil then
      -- No chunk holds a tracked building; nothing to do this tick.
      break
    end

    local record = state.chunks[chunk]
    state.cursor = next(state.chunks, chunk)

    if record then
      M.visit_chunk(state, record, threshold)
    end
  end

  return state
end

return M
