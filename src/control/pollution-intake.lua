-- Pure gating logic for pr_pollution-intake buildings: a rolling `next()`
-- cursor over a tracked-entities table, visiting a small slice per tick and
-- toggling each entity offline when its chunk doesn't have enough ambient
-- pollution to back a real craft.
--
-- Deliberately dependency-injected: nothing in this file touches `game`,
-- `storage`, or `script`. `state`, `surface`, `threshold`, and `slice_count`
-- are always passed in explicitly. That's what lets this exact file load
-- two different ways with no contradiction between them: from real
-- Factorio via `require("__pollution-reclamation__/control/pollution-intake")`,
-- and from the plain-Lua test runner via `dofile(...)`.
--
-- Trust boundary: this module does not check entity validity. The adapter
-- (control.lua) is responsible for keeping `state.entities` free of invalid
-- entities via Factorio's build/mine/died events before calling into this
-- module -- that's the one piece of behavior these unit tests structurally
-- can't exercise (a plain Lua table has no such thing as "invalid"), so it's
-- kept out of here on purpose rather than half-tested.

local M = {}

function M.new_state()
  return {
    entities = {},
    cursor = nil,
  }
end

function M.add_entity(state, key, entity)
  state.entities[key] = entity
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
      local pollution = entity.surface.get_pollution(entity.position)
      entity.disabled_by_script = pollution < threshold
    end
  end

  return state
end

return M
