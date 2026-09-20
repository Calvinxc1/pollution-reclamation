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

-- One tick of control.lua: the condenser gate walks chunks, sensors walk
-- themselves. Tests drive both together so they exercise the same pairing the
-- runtime does.
local function tick(state, threshold, slice)
  module.step(state, threshold, slice)
  module.step_sensors(state, slice)
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
  local behavior = { enabled = true }
  local wired = { connection_count = 1 }
  return {
    -- Sensors only output while something is wired to them; the tests flip
    -- this to stand in for connecting and disconnecting a wire.
    wired = wired,
    behavior = behavior,
    get_wire_connector = function(_, _) return wired end,
    position = position or { x = 0, y = 0 },
    disabled_by_script = nil,
    -- A stand-in for the constant combinator underneath a sensor: one
    -- section whose first slot the mod owns. Condensers never touch this.
    -- Factorio's API is called with a dot, not a colon, so these take no
    -- self and close over the slots table instead.
    section = { slots = slots },
    get_or_create_control_behavior = function()
      behavior.get_section = function()
        return {
          get_slot = function(i) return slots[i] end,
          set_slot = function(i, filter) slots[i] = filter end,
        }
      end
      behavior.add_section = function() return nil end
      return behavior
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
  -- Its own chunk: two buildings in one chunk necessarily read the same
  -- pollution, so "one hot, one cold" only means anything a chunk apart.
  local cold = make_entity(2, "pollution", { x = 100, y = 100 }) -- below threshold
  module.add_entity(state, "hot", hot)
  module.add_entity(state, "cold", cold)
  tick(state, 10, 2)
  check("entity above threshold stays enabled", hot.disabled_by_script == false)
  check("entity below threshold gets disabled", cold.disabled_by_script == true)
end

-- Test: only surfaces whose pollutant is `pollution` can run a condenser.
-- Gleba reports spores through get_pollution, which the condenser can't absorb.
do
  local state = module.new_state()
  local nauvis = make_entity(50)
  local gleba = make_entity(50, "spores", { x = 100, y = 0 })
  local vulcanus = make_entity(50, false, { x = 200, y = 0 })
  module.add_entity(state, "nauvis", nauvis)
  module.add_entity(state, "gleba", gleba)
  module.add_entity(state, "vulcanus", vulcanus)
  tick(state, 10, 3)
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
  tick(state, 10, 6)
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
  tick(state, 10, 5)
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
  tick(state, 10, 5)
  check("five sharing a chunk with 20 pollution are disabled", crowd[1].disabled_by_script == true)
  for i = 3, 5 do
    module.remove_entity(state, "crowd" .. i)
  end
  tick(state, 10, 2)
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
  tick(state, 10, 2)
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
  tick(state, 10, 1)
  local slot = sensor.section.slots[1]
  check("the sensor writes its reading to the circuit output", slot ~= nil and slot.min == 80)
  check("a fresh sensor defaults to signal-P",
    slot.value.name == "signal-P" and slot.value.type == "virtual")
end

-- Test: the player's chosen signal is what gets written.
do
  local state = module.new_state()
  local sensor = make_entity(42)
  module.add_entity(state, "sensor", sensor, "sensor")
  module.set_signal(state, "sensor", { type = "item", name = "iron-plate", quality = "normal" })
  tick(state, 10, 1)
  local slot = sensor.section.slots[1]
  check("the chosen signal is used", slot.value.name == "iron-plate")
  check("the reading is written to it", slot.min == 42)
  module.set_signal(state, "sensor", nil)
  check("clearing the choice restores the default",
    module.signal_of(state, "sensor").name == "signal-P")
end

-- Test: an unwired sensor outputs nothing, but keeps the player's signal.
do
  local state = module.new_state()
  local sensor = make_entity(75)
  module.add_entity(state, "sensor", sensor, "sensor")
  module.set_signal(state, "sensor", { type = "item", name = "copper-plate", quality = "normal" })
  tick(state, 10, 1)
  check("a wired sensor's output is enabled", sensor.behavior.enabled == true)
  sensor.wired.connection_count = 0
  tick(state, 10, 1)
  check("an unwired sensor's output is switched off", sensor.behavior.enabled == false)
  check("its signal survives being unwired",
    module.signal_of(state, "sensor").name == "copper-plate")
  sensor.wired.connection_count = 1
  tick(state, 10, 1)
  check("rewiring switches the output back on", sensor.behavior.enabled == true)
  check("and the reading comes back on the kept signal",
    sensor.section.slots[1].value.name == "copper-plate" and sensor.section.slots[1].min == 75)
end

-- Test: a sensor with no pollutant outputs zero rather than a stale number.
do
  local state = module.new_state()
  local sensor = make_entity(500, false)
  module.add_entity(state, "sensor", sensor, "sensor")
  tick(state, 10, 1)
  check("a sensor without a pollutant outputs zero", sensor.section.slots[1].min == 0)
end

-- Test: a sensor on a surface with no pollutant says so rather than reading 0.
do
  local state = module.new_state()
  local sensor = make_entity(50, false)
  module.add_entity(state, "sensor", sensor, "sensor")
  tick(state, 10, 1)
  check("a sensor without a pollutant says so",
    sensor.custom_status.label[1] == "pr-sensor.no-pollutant")
end

-- Test: a sensor on Gleba reports no pollution rather than a spore count.
-- get_pollution answers for whatever pollutant the surface uses, so without
-- this the sensor would label a spore reading "Chunk pollution" and put it on
-- the wire -- on the one surface where the gate has already refused to run a
-- condenser. The number a player reads and the number the gate tests have to
-- be the same number.
do
  local state = module.new_state()
  local sensor = make_entity(240, "spores")
  module.add_entity(state, "sensor", sensor, "sensor")
  tick(state, 10, 1)
  check("a sensor on a spore surface says there is no pollution",
    sensor.custom_status.label[1] == "pr-sensor.no-pollutant")
  check("a sensor on a spore surface outputs zero, not the spore count",
    sensor.section.slots[1].min == 0)
  check("and its status diode is not green", sensor.custom_status.diode == module.DIODE.yellow)
end

-- Test: the gate and the sensor agree on what counts as pollution, because
-- they ask the same question.
do
  check("spores are not pollution", module.is_pollution({ pollutant = "spores", pollution = 240 }) == false)
  check("nothing is not pollution", module.is_pollution({ pollutant = nil, pollution = 0 }) == false)
  check("pollution is pollution", module.is_pollution({ pollutant = "pollution", pollution = 5 }) == true)
  local label = module.status_label({ pollutant = "pollution", pollution = 504.8 })
  check("a reading is rounded for display", label[2] == "505")
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
    tick(state, 10, 1)
  end
  local all_visited = true
  for _, e in ipairs(entities) do
    if e.disabled_by_script == nil then
      all_visited = false
    end
  end
  check("every entity visited within one lap", all_visited)
end

-- Test: a chunk is read once per visit, however many buildings stand in it.
-- This is the point of walking chunks instead of buildings: pollution is
-- stored per chunk, so reading it once per building was the same number
-- fetched over and over.
do
  local state = module.new_state()
  local reads = 0
  local function counting_entity()
    return {
      position = { x = 0, y = 0 },
      disabled_by_script = nil,
      surface = {
        index = 1,
        pollutant_type = { name = "pollution" },
        get_pollution = function()
          reads = reads + 1
          return 500
        end,
      },
    }
  end
  local crowd = {}
  for i = 1, 20 do
    crowd[i] = counting_entity()
    module.add_entity(state, "c" .. i, crowd[i])
  end
  tick(state, 10, 1)
  check("twenty condensers in one chunk cost one pollution read", reads == 1)
  local all_enabled = true
  for _, e in ipairs(crowd) do
    if e.disabled_by_script ~= false then all_enabled = false end
  end
  check("and all twenty still got the verdict", all_enabled)
end

-- Test: a chunk whose verdict hasn't changed writes to no entity at all.
-- This is the saving that doesn't depend on how densely anyone builds, and
-- at rest -- which is nearly always -- it is most of the walk.
do
  local state = module.new_state()
  local writes = 0
  local entities = {}
  for i = 1, 5 do
    local e = make_entity(500)
    -- Count assignments to disabled_by_script rather than reads of it.
    local backing = nil
    setmetatable(e, {
      __index = function(_, k) if k == "disabled_by_script" then return backing end end,
      __newindex = function(t, k, v)
        if k == "disabled_by_script" then
          writes = writes + 1
          backing = v
        else
          rawset(t, k, v)
        end
      end,
    })
    rawset(e, "disabled_by_script", nil)
    entities[i] = e
    module.add_entity(state, "e" .. i, e)
  end
  tick(state, 10, 1)
  local first_pass = writes
  check("the first visit writes the verdict to every condenser", first_pass == 5)
  tick(state, 10, 1)
  tick(state, 10, 1)
  tick(state, 10, 1)
  check("later visits with the same verdict write nothing", writes == first_pass)
end

-- Test: a membership change invalidates the cached verdict, because it moves
-- the bar for everyone already in the chunk.
do
  local state = module.new_state()
  local a = make_entity(15)
  module.add_entity(state, "a", a)
  tick(state, 10, 1)
  check("one condenser in a chunk holding 15 runs", a.disabled_by_script == false)
  local b = make_entity(15)
  module.add_entity(state, "b", b)
  tick(state, 10, 1)
  check("adding a second re-decides and stops both", a.disabled_by_script == true)
  check("including the new one", b.disabled_by_script == true)
  module.remove_entity(state, "b")
  tick(state, 10, 1)
  check("removing it re-decides and the survivor runs again", a.disabled_by_script == false)
end

-- Test: the walk only ever holds chunks that contain something, so an empty
-- chunk is dropped rather than left to be visited forever.
do
  local state = module.new_state()
  local e = make_entity(50)
  module.add_entity(state, "e", e)
  local occupied = 0
  for _ in pairs(state.chunks) do occupied = occupied + 1 end
  check("one building means one chunk on the walk", occupied == 1)
  module.remove_entity(state, "e")
  occupied = 0
  for _ in pairs(state.chunks) do occupied = occupied + 1 end
  check("removing the last building drops its chunk", occupied == 0)
end

-- Test: a sensor does not put its chunk on the condenser walk. Sensors gate
-- nothing, so a chunk that holds only sensors has no verdict to reach and no
-- business slowing down the chunks that do.
do
  local state = module.new_state()
  module.add_entity(state, "s", make_entity(500, "pollution", { x = 500, y = 500 }), "sensor")
  local occupied = 0
  for _ in pairs(state.chunks) do occupied = occupied + 1 end
  check("a sensor alone leaves the chunk walk empty", occupied == 0)

  module.add_entity(state, "c", make_entity(500), "condenser")
  occupied = 0
  for _ in pairs(state.chunks) do occupied = occupied + 1 end
  check("a condenser is what puts a chunk on the walk", occupied == 1)
end

-- Test: sensors refresh on their own walk, at their own pace, whatever the
-- condenser gate is doing.
do
  local state = module.new_state()
  local sensor = make_entity(500, "pollution", { x = 500, y = 500 })
  module.add_entity(state, "s", sensor, "sensor")
  module.step(state, 10, 8)
  check("the chunk walk alone never touches a sensor", sensor.custom_status == nil)
  module.step_sensors(state, 1)
  check("the sensor walk reports it", sensor.custom_status.label[2] == "500")
  check("and puts the reading on its output", sensor.section.slots[1].min == 500)
end

-- Test: a sensor and the gate still agree, now that they read separately.
-- The guarantee lives in the shared helpers, not in a shared loop.
do
  local state = module.new_state()
  local sensor = make_entity(37.4)
  local condenser = make_entity(37.4)
  module.add_entity(state, "s", sensor, "sensor")
  module.add_entity(state, "c", condenser, "condenser")
  tick(state, 10, 4)
  check("the sensor rounds the way the gate's helpers do",
    sensor.custom_status.label[2] == "37")
  check("and the condenser beside it ran on the same reading",
    condenser.disabled_by_script == false)
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
      -- A chunk each, so each one is its own stop on the walk.
      position = { x = i * 100, y = 0 },
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
  -- Three full laps' worth of single-chunk steps.
  for _ = 1, 15 do
    tick(state, 10, 1)
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
  tick(state, 10, 1)

  local removed_ok = pcall(function()
    module.remove_entity(state, "e1")
  end)
  check("removing the entity under the cursor doesn't error", removed_ok)

  -- Comfortably more than one lap over the two survivors, regardless of
  -- where the cursor happened to land.
  for _ = 1, 6 do
    tick(state, 10, 1)
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
    tick(state, 10, 4)
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
