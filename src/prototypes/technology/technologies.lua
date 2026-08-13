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
    }
  })
end