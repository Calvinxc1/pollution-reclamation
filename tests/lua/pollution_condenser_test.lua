-- Unit tests for src/control/pollution-condenser.lua's pure gating logic.
-- Run with: lua tests/lua/pollution_condenser_test.lua (from the repo root;
-- also works with lua5.1/lua5.4, see scripts/validate.sh).
--
-- Deliberately tests order-independent invariants only -- never a specific
-- traversal sequence. Factorio's own pairs()/next() is a deterministic but
-- insertion-order-based reimplementation that no stock Lua interpreter
-- reproduces, so pinning an exact sequence here would just encode this
-- interpreter's incidental hash order as if it were spec. See the comments
-- in pollution-condenser.lua for the full reasoning.

local script_dir = (arg and arg[0] and arg[0]:match("(.*/)")) or "./"
local module = dofile(script_dir .. "../../src/control/pollution-condenser.lua")

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
-- Entities default to chunk 0,0 of surface 1; pass a position to place one in
-- another chunk (chunks are 32x32 tiles).
local function make_entity(pollution_level, pollutant_name, position)
  if pollutant_name == nil then
    pollutant_name = "pollution"
  end
  local slots = {}
  return {
    position = position or { x = 0, y = 0 },
    disabled_by_script = nil,
    -- A stand-in for the constant combinator underneath a sensor: one
    -- section whose first slot the mod owns. Condensers never touch this.
    -- Factorio's API is called with a dot, not a colon, so these take no
    -- self and close over the slots table instead.
    section = { slots = slots },
    get_or_create_control_behavior = function()
      return {
        get_section = function()
          return {
            get_slot = function(i) return slots[i] end,
            set_slot = function(i, filter) slots[i] = filter end,
          }
        end,
        add_section = function() return nil end,
      }
    end,
    surface = {
      -- false stands for a surface with no pollutant at all (pollutant_type nil).
      index = 1,
      pollutant_type = pollutant_name and { name = pollutant_name } or nil,
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

-- Test: only surfaces whose pollutant is `pollution` can run a condenser.
-- Gleba reports spores through get_pollution, which the condenser can't absorb.
do
  local state = module.new_state()
  local nauvis = make_entity(50)
  local gleba = make_entity(50, "spores")
  local vulcanus = make_entity(50, false)
  module.add_entity(state, "nauvis", nauvis)
  module.add_entity(state, "gleba", gleba)
  module.add_entity(state, "vulcanus", vulcanus)
  module.step(state, 10, 3)
  check("pollution surface above threshold stays enabled", nauvis.disabled_by_script == false)
  check("spore surface is disabled even above threshold", gleba.disabled_by_script == true)
  check("surface with no pollutant is disabled", vulcanus.disabled_by_script == true)
end

-- Test: the threshold applies per condenser sharing a chunk, all or nothing.
-- A lone condenser needs `threshold`; five in one chunk need five times that,
-- because they all draw on the same per-chunk pollution pool between checks.
do
  local state = module.new_state()
  local crowd = {}
  for i = 1, 5 do
    crowd[i] = make_entity(40) -- chunk 0,0; 40 clears 10 each but not 5 x 10
    module.add_entity(state, "crowd" .. i, crowd[i])
  end
  local lone = make_entity(40, "pollution", { x = 100, y = 100 }) -- its own chunk
  module.add_entity(state, "lone", lone)
  module.step(state, 10, 6)
  local crowd_disabled = true
  for _, e in ipairs(crowd) do
    if e.disabled_by_script ~= true then crowd_disabled = false end
  end
  check("five condensers sharing a chunk are all disabled below 5x threshold", crowd_disabled)
  check("a condenser alone in its chunk still runs at the same pollution", lone.disabled_by_script == false)
end

-- Test: the same crowd runs once the chunk holds enough for all of them.
do
  local state = module.new_state()
  local crowd = {}
  for i = 1, 5 do
    crowd[i] = make_entity(50) -- exactly 5 x 10
    module.add_entity(state, "crowd" .. i, crowd[i])
  end
  module.step(state, 10, 5)
  local all_enabled = true
  for _, e in ipairs(crowd) do
    if e.disabled_by_script ~= false then all_enabled = false end
  end
  check("a chunk holding threshold x population runs all of them", all_enabled)
end

-- Test: removing condensers frees the chunk's budget for the survivors.
do
  local state = module.new_state()
  local crowd = {}
  for i = 1, 5 do
    crowd[i] = make_entity(20)
    module.add_entity(state, "crowd" .. i, crowd[i])
  end
  module.step(state, 10, 5)
  check("five sharing a chunk with 20 pollution are disabled", crowd[1].disabled_by_script == true)
  for i = 3, 5 do
    module.remove_entity(state, "crowd" .. i)
  end
  module.step(state, 10, 2)
  check("after three are removed the remaining two run", crowd[1].disabled_by_script == false and crowd[2].disabled_by_script == false)
  check("chunk population tracks removals", module.chunk_population(state, "crowd1") == 2)
end

-- Test: adding the same key twice doesn't double-count the chunk.
do
  local state = module.new_state()
  local e = make_entity(20)
  module.add_entity(state, "e", e)
  module.add_entity(state, "e", e)
  check("re-adding a tracked key leaves the population at one", module.chunk_population(state, "e") == 1)
end

-- Test: a sensor reports the chunk's pollution and nothing else, and is not
-- counted as a condenser drawing on that chunk.
do
  local state = module.new_state()
  local sensor = make_entity(37.4)
  local condenser = make_entity(37.4)
  module.add_entity(state, "sensor", sensor, "sensor")
  module.add_entity(state, "condenser", condenser)
  check("a sensor doesn't count toward its chunk's condenser population",
    module.chunk_population(state, "sensor") == 1)
  module.step(state, 10, 2)
  check("the lone condenser still runs beside a sensor", condenser.disabled_by_script == false)
  check("the sensor is never gated", sensor.disabled_by_script == nil)
  check("the sensor reports the chunk's rounded pollution",
    sensor.custom_status ~= nil and sensor.custom_status.label[2] == "37")
  check("the sensor reports nothing else", #sensor.custom_status.label == 2)
end

-- Test: the sensor puts its reading on its circuit output, on the default
-- signal to begin with.
do
  local state = module.new_state()
  local sensor = make_entity(80)
  module.add_entity(state, "sensor", sensor, "sensor")
  module.step(state, 10, 1)
  local slot = sensor.section.slots[1]
  check("the sensor writes its reading to the circuit output", slot ~= nil and slot.min == 80)
  check("a fresh sensor defaults to signal-P",
    slot.value.name == "signal-P" and slot.value.type == "virtual")
end

-- Test: the player's chosen signal survives the update; only the value moves.
do
  local state = module.new_state()
  local sensor = make_entity(42)
  module.add_entity(state, "sensor", sensor, "sensor")
  sensor.section.slots[1] = { value = { type = "item", name = "iron-plate", quality = "normal" }, min = 0 }
  module.step(state, 10, 1)
  local slot = sensor.section.slots[1]
  check("the chosen signal is kept", slot.value.name == "iron-plate")
  check("the value is updated under it", slot.min == 42)
end

-- Test: a sensor with no pollutant outputs zero rather than a stale number.
do
  local state = module.new_state()
  local sensor = make_entity(500, false)
  module.add_entity(state, "sensor", sensor, "sensor")
  module.step(state, 10, 1)
  check("a sensor without a pollutant outputs zero", sensor.section.slots[1].min == 0)
end

-- Test: a sensor on a surface with no pollutant says so rather than reading 0.
do
  local state = module.new_state()
  local sensor = make_entity(50, false)
  module.add_entity(state, "sensor", sensor, "sensor")
  module.step(state, 10, 1)
  check("a sensor without a pollutant says so",
    sensor.custom_status.label[1] == "pr-sensor.no-pollutant")
end

-- Test: removing a sensor leaves its chunk's condenser count alone.
do
  local state = module.new_state()
  local condensers = {}
  for i = 1, 3 do
    condensers[i] = make_entity(30)
    module.add_entity(state, "c" .. i, condensers[i])
  end
  module.add_entity(state, "sensor", make_entity(30), "sensor")
  module.remove_entity(state, "sensor")
  check("removing a sensor leaves the condenser population at three",
    module.chunk_population(state, "c1") == 3)
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
      position = { x = 0, y = 0 },
      disabled_by_script = nil,
      surface = {
        index = 1,
        pollutant_type = { name = "pollution" },
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
