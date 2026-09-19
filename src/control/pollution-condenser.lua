-- Pure gating logic for pr_pollution-condenser buildings: a rolling `next()`
-- cursor over a tracked-entities table, visiting a small slice per tick and
-- toggling each entity offline when its chunk doesn't have enough ambient
-- pollution to back a real craft.
--
-- Deliberately dependency-injected: nothing in this file touches `game`,
-- `storage`, or `script`. `state`, `surface`, `threshold`, and `slice_count`
-- are always passed in explicitly. That's what lets this exact file load
-- two different ways with no contradiction between them: from real
-- Factorio via `require("__pollution-reclamation__/control/pollution-condenser")`,
-- and from the plain-Lua test runner via `dofile(...)`.
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

function M.new_state()
  return {
    entities = {},
    cursor = nil,
    -- How many tracked condensers sit in each chunk, and which chunk each
    -- tracked key belongs to. Buildings never move, so a condenser's chunk is
    -- fixed for as long as it is tracked and is recorded once, at add time.
    chunk_counts = {},
    entity_chunk = {},
    -- "condenser" for the buildings the gate switches on and off, "sensor"
    -- for pollution sensors. Sensors share the tracking so they report the
    -- very number the gate tests, but they absorb nothing, so they must not
    -- count toward a chunk's condenser population.
    roles = {},
  }
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
    state.entity_chunk[key] = chunk
    state.roles[key] = role
    if role == "condenser" then
      state.chunk_counts[chunk] = (state.chunk_counts[chunk] or 0) + 1
    end
  end
  state.entities[key] = entity
end

-- How many tracked condensers sit in this entity's chunk. For a condenser
-- that includes itself; for a sensor it's the condensers it is reporting on,
-- which may be none.
function M.chunk_population(state, key)
  local chunk = state.entity_chunk[key]
  return (chunk and state.chunk_counts[chunk]) or 0
end

-- Safe against the classic next()-after-delete pitfall: if the cursor is
-- currently sitting on the key being removed, advance it *before* the key
-- disappears from the table, while `next` can still find it. Calling
-- `next(t, k)` after `k` has already been removed from `t` is not something
-- Lua promises will work.
function M.remove_entity(state, key)
  if state.cursor == key then
    state.cursor = next(state.entities, key)
  end
  if state.entities[key] ~= nil then
    local chunk = state.entity_chunk[key]
    if chunk then
      if state.roles[key] ~= "sensor" then
        local remaining = (state.chunk_counts[chunk] or 1) - 1
        state.chunk_counts[chunk] = remaining > 0 and remaining or nil
      end
      state.entity_chunk[key] = nil
    end
    state.roles[key] = nil
  end
  state.entities[key] = nil
end

-- Visits up to `slice_count` tracked entities, reading pollution at each
-- one's own position/surface and setting `entity.disabled_by_script`
-- against `threshold`. Wraps around automatically when the cursor runs off
-- the end of the table (`next` returns nil), so it never needs to know the
-- table's size up front.
--
-- Reads pollution via `entity.surface.get_pollution(entity.position)`
-- rather than taking a single surface parameter for the whole tracked
-- table -- tracked entities aren't guaranteed to share one surface (nothing
-- restricts this building to Nauvis at the prototype level), and each real
-- LuaEntity already carries its own `.surface`. In tests, fake entities
-- carry their own fake `.surface` stub the same way, so this stays just as
-- mockable as a separate parameter would have been.
--
-- Order across entities is deliberately NOT a contract of this function --
-- Factorio's own `next`/`pairs` is a deterministic-but-insertion-order
-- reimplementation that no stock Lua interpreter reproduces, so callers
-- (and tests) should only rely on "every entity gets visited eventually",
-- never on a specific sequence.
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
function M.can_capture(entity, threshold, population)
  local surface = entity.surface
  local pollutant = surface.pollutant_type
  if not (pollutant and pollutant.name == "pollution") then
    return false
  end
  return surface.get_pollution(entity.position) >= threshold * (population or 1)
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

-- Writes the reading onto the entity as a custom status line. An unpowered
-- sensor reports nothing and falls back to the engine's own "No power"
-- status, rather than leaving a stale number on screen.
function M.report(entity)
  if (entity.energy or 0) <= 0 then
    entity.custom_status = nil
    return nil
  end
  local reading = M.reading(entity)
  if reading.pollutant == nil then
    entity.custom_status = {
      diode = M.DIODE.yellow,
      label = { "pr-sensor.no-pollutant" },
    }
  else
    entity.custom_status = {
      diode = M.DIODE.green,
      label = { "pr-sensor.pollution", tostring(math.floor(reading.pollution + 0.5)) },
    }
  end
  return reading
end

function M.step(state, threshold, slice_count)
  for _ = 1, slice_count do
    local key = state.cursor
    if key == nil then
      key = next(state.entities, nil)
    end
    if key == nil then
      -- Tracked table is empty; nothing to do this tick.
      break
    end

    local entity = state.entities[key]
    state.cursor = next(state.entities, key)

    if entity then
      if state.roles[key] == "sensor" then
        M.report(entity)
      else
        local population = M.chunk_population(state, key)
        entity.disabled_by_script = not M.can_capture(entity, threshold, population)
      end
    end
  end

  return state
end

return M
