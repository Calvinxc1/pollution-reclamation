---------------------------------------------------------------------------
-- -- -- CONDITIONAL UPDATES FOR SPACE AGE USERS
---------------------------------------------------------------------------
local airPurificationPrerequisites = {}
local improvedAirPurificationPrerequisites = {}
local improvedAirPurificationCosts = {}

if not mods["space-age"] then
  airPurificationPrerequisites = { "steel-processing", "engine" }
  improvedAirPurificationPrerequisites = { "pr_air-purification", "plastics" }
  improvedAirPurificationCosts = {
    count = 300,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1}
    },
    time = 45,
  }
else
  airPurificationPrerequisites = { "plastics", "steel-processing", "engine" }
  improvedAirPurificationPrerequisites = { "pr_air-purification", "planet-discovery-gleba", "carbon-fiber" }
  improvedAirPurificationCosts = {
    count = 150,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"space-science-pack", 1},
      {"agricultural-science-pack", 1}
    },
    time = 45,
  }
end

---------------------------------------------------------------------------
-- -- -- DATA EXTENSION ITSELF
---------------------------------------------------------------------------
if airPurificationPrerequisites ~= nil then
  data:extend({
    {
      type = "technology",
      name = "pr_air-purification",
      mod = "pollution-reclamation",
      icon = "__pollution-reclamation__/graphics/technologies/air-purifier.png",
      icon_size = 256,
      icon_mipmaps = 4,
      effects = {
        {
          type = "unlock-recipe",
          recipe = "pr_air-purifier",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-filter",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_air-cleaning",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_restore-used-pollution-filter",
        },
      },
      prerequisites = airPurificationPrerequisites,
      unit = {
        count = 250,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1}
        },
        time = 30,
      },
    },
    {
      type = "technology",
      name = "pr_improved-pollution-filter",
      mod = "pollution-reclamation",
      icon = "__pollution-reclamation__/graphics/technologies/improved-pollution-filter.png",
      icon_size = 256,
      icon_mipmaps = 4,
      effects = {
        {
          type = "unlock-recipe",
          recipe = "pr_improved-pollution-filter",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_air-cleaning-2",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_restore-used-improved-pollution-filter",
        },
      },
      prerequisites = improvedAirPurificationPrerequisites,
      unit = improvedAirPurificationCosts,
    },
    -- Single root technology unlocking both tier-1 pollution-economy
    -- buildings together, per the design doc's explicit "Decided" call: a
    -- player should get a complete, playable capture/vent loop the moment
    -- this is researched, not half of one. Nauvis-scoped, so unconditional
    -- (no mods["space-age"] branching, unlike the two technologies above).
    --
    -- Gated on fluid-handling specifically, not just steel-processing/engine
    -- (which fluid-handling already requires transitively): fluid-handling
    -- is what actually unlocks storage-tank and pump. Without it, a player
    -- could build intake/outflow and connect them with plain pipes (those
    -- need no research) but couldn't build a tank farm -- one of the three
    -- core sinks in the design doc -- or use pumps for longer runs.
    {
      type = "technology",
      name = "pr_pollution-economy",
      mod = "pollution-reclamation",
      icon = "__pollution-reclamation__/graphics/technologies/air-purifier.png",
      icon_size = 256,
      icon_mipmaps = 4,
      effects = {
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-intake",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-outflow",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-capture",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-venting",
        },
      },
      prerequisites = { "fluid-handling" },
      unit = {
        count = 250,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1}
        },
        time = 30,
      },
    }
  })
end