-- Unit tests for src/control/pollution-intake.lua's pure gating logic.
-- Run with: lua tests/lua/pollution_intake_test.lua (from the repo root;
-- also works with lua5.1/lua5.4, see scripts/validate.sh).
--
-- Deliberately tests order-independent invariants only -- never a specific
-- traversal sequence. Factorio's own pairs()/next() is a deterministic but
-- insertion-order-based reimplementation that no stock Lua interpreter
-- reproduces, so pinning an exact sequence here would just encode this
-- interpreter's incidental hash order as if it were spec. See the comments
-- in pollution-intake.lua for the full reasoning.

local script_dir = (arg and arg[0] and arg[0]:match("(.*/)")) or "./"
local module = dofile(script_dir .. "../../src/control/pollution-intake.lua")

local failures = 0
local function check(name, condition)
  if condition then
    print("PASS  " .. name)
  else
    failures = failures + 1
    print("FAIL  " .. name)
  end
end

-- disabled_by_script starts nil (not false) so tests can tell "visited and
-- computed false" apart from "never visited, still at its initial value".
local function make_entity(pollution_level)
  return {
    position = {},
    disabled_by_script = nil,
    surface = {
      get_pollution = function(_)
        return pollution_level
      end,
    },
  }
end

-- Test: threshold correctness.
do
  local state = module.new_state()
  local hot = make_entity(50) -- above threshold
  local cold = make_entity(2) -- below threshold
  module.add_entity(state, "hot", hot)
  module.add_entity(state, "cold", cold)
  module.step(state, 10, 2)
  check("entity above threshold stays enabled", hot.disabled_by_script == false)
  check("entity below threshold gets disabled", cold.disabled_by_script == true)
end

-- Test: every tracked entity gets visited within one lap.
do
  local state = module.new_state()
  local entities = {}
  for i = 1, 7 do
    local e = make_entity(20)
    entities[i] = e
    module.add_entity(state, "e" .. i, e)
  end
  -- One entity per step; 7 steps is exactly one lap over 7 entities.
  for _ = 1, 7 do
    module.step(state, 10, 1)
  end
  local all_visited = true
  for _, e in ipairs(entities) do
    if e.disabled_by_script == nil then
      all_visited = false
    end
  end
  check("every entity visited within one lap", all_visited)
end

-- Test: the cursor wraps around and keeps cycling rather than getting
-- stuck after the first lap.
do
  local state = module.new_state()
  local visit_counts = {}
  for i = 1, 5 do
    local key = "e" .. i
    visit_counts[key] = 0
    local e = {
      position = {},
      disabled_by_script = nil,
      surface = {
        get_pollution = function()
          visit_counts[key] = visit_counts[key] + 1
          return 20
        end,
      },
    }
    module.add_entity(state, key, e)
  end
  -- Three full laps' worth of single-entity steps.
  for _ = 1, 15 do
    module.step(state, 10, 1)
  end
  local min_visits = math.huge
  for _, count in pairs(visit_counts) do
    min_visits = math.min(min_visits, count)
  end
  check("cursor completes multiple laps without sticking", min_visits >= 2)
end

-- Test: removing the entity currently under the cursor doesn't crash or
-- cause its neighbors to be skipped.
do
  local state = module.new_state()
  local e1 = make_entity(20)
  local e2 = make_entity(20)
  local e3 = make_entity(20)
  module.add_entity(state, "e1", e1)
  module.add_entity(state, "e2", e2)
  module.add_entity(state, "e3", e3)

  -- Advance the cursor onto whichever entity comes first.
  module.step(state, 10, 1)

  local removed_ok = pcall(function()
    module.remove_entity(state, "e1")
  end)
  check("removing the entity under the cursor doesn't error", removed_ok)

  -- Comfortably more than one lap over the two survivors, regardless of
  -- where the cursor happened to land.
  for _ = 1, 6 do
    module.step(state, 10, 1)
  end
  check(
    "surviving neighbors still get visited after a removal",
    e2.disabled_by_script == false and e3.disabled_by_script == false
  )
end

-- Test: stepping an empty tracked table is a no-op, not an error.
do
  local state = module.new_state()
  local ok = pcall(function()
    module.step(state, 10, 4)
  end)
  check("stepping an empty tracked table doesn't error", ok)
end

print()
if failures == 0 then
  print("All tests passed.")
  os.exit(0)
else
  print(failures .. " test(s) failed.")
  os.exit(1)
end
