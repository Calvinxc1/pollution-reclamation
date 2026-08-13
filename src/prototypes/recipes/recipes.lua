---------------------------------------------------------------------------
-- -- -- CONDITIONAL UPDATES FOR SPACE AGE USERS
---------------------------------------------------------------------------
local polutionFilterIngredients = {}
local improvedPolutionFilterIngredients = {}

if not mods["space-age"] then
  polutionFilterIngredients = {
    { type = "item", name = "coal", amount = 2 },
    { type = "item", name = "iron-plate", amount = 2 },
    { type = "item", name = "steel-plate", amount = 1 }
  }
  improvedPolutionFilterIngredients = {
    { type = "item", name = "pr_pollution-filter", amount = 1 },
    { type = "item", name = "plastic-bar", amount = 3 }
  }
else
  polutionFilterIngredients = {
    { type = "item", name = "coal", amount = 2 },
    { type = "item", name = "iron-plate", amount = 2 },
    { type = "item", name = "steel-plate", amount = 1 },
    { type = "item", name = "plastic-bar", amount = 2 }
  }
  improvedPolutionFilterIngredients = {
    { type = "item", name = "pr_pollution-filter", amount = 1 },
    { type = "item", name = "carbon-fiber", amount = 2 }
  }
end

---------------------------------------------------------------------------
-- -- -- DATA EXTENSION ITSELF
---------------------------------------------------------------------------
if polutionFilterIngredients ~= nil then
  data:extend({
      -------------
      -- BUILDING
      -------------
      {
          type = "recipe",
          name = "pr_air-purifier",
          energy_required = 5,
          enabled = false,
          ingredients = {
            { type = "item", name = "steel-plate", amount = 2 },
            { type = "item", name = "advanced-circuit", amount = 4 },
            { type = "item", name = "plastic-bar", amount = 20 },
            { type = "item", name = "engine-unit", amount = 3 },
          },
          results = { { type = "item", name = "pr_air-purifier", amount = 1 } },
      },
      -------------
      -- PROCESS
      -------------
      {
          type = "recipe",
          name = "pr_air-cleaning",
          categories = { "pr_air-purification-category" },
          icon = "__pollution-reclamation__/graphics/icons/recipes/filtering.png",
          icon_size = 64,
          energy_required = 480,
          enabled = false,
          hidden = false,
          hide_from_player_crafting = true,
          ingredients = {
            { type = "item", name = "pr_pollution-filter", amount = 1 },
          },
          results = {
            { type = "item", name = "pr_used-pollution-filter", independent_probability = 0.80, amount = 1 },
          },
          subgroup = "raw-material",
          order = "zz[air-cleaning]",
        },
        {
          type = "recipe",
          name = "pr_air-cleaning-2",
          categories = { "pr_air-purification-category" },
          icon = "__pollution-reclamation__/graphics/icons/recipes/filtering.png",
          icon_size = 64,
          energy_required = 600,
          enabled = false,
          hidden = false,
          hide_from_player_crafting = true,
          ingredients = {
            { type = "item", name = "pr_improved-pollution-filter", amount = 1 },
          },
          results = {
            { type = "item", name = "pr_used-improved-pollution-filter", independent_probability = 0.90, amount = 1 },
          },
          emissions_multiplier = 3.0,
          subgroup = "raw-material",
          order = "zz[air-cleaning]",
        },
        -------------
        -- ITEMS
        -------------
        {
          type = "recipe",
          name = "pr_pollution-filter",
          energy_required = 10,
          enabled = false,
          allow_productivity = true,
          ingredients = polutionFilterIngredients,
          results = { { type = "item", name = "pr_pollution-filter", amount = 1 } },
        },
        {
          type = "recipe",
          name = "pr_restore-used-pollution-filter",
          categories = { "crafting-with-fluid" },
          icon = "__pollution-reclamation__/graphics/icons/recipes/restore-used-pollution-filter.png",
          icon_size = 128,
          energy_required = 10,
          enabled = false,
          ingredients = {
            { type = "item", name = "pr_used-pollution-filter", amount = 1 },
            { type = "fluid", name = "water", amount = 100 },
          },
          results = {
            { type = "item", name = "pr_pollution-filter", amount = 1 },
            { type = "item", name = "coal", amount = 1, independent_probability = 0.50 }
          },
          subgroup = "intermediate-product",
          order = "w3-a[pr_restore-used-pollution-filter]",
        },
        {
          type = "recipe",
          name = "pr_improved-pollution-filter",
          energy_required = 10,
          enabled = false,
          allow_productivity = true,
          ingredients = improvedPolutionFilterIngredients,
          results = { 
            { type = "item", name = "pr_improved-pollution-filter", amount = 1 } 
          }
        },
        {
          type = "recipe",
          name = "pr_restore-used-improved-pollution-filter",
          categories = { "crafting-with-fluid" },
          icon = "__pollution-reclamation__/graphics/icons/recipes/restore-used-improved-pollution-filter.png",
          icon_size = 128,
          energy_required = 10,
          enabled = false,
          ingredients = {
            { type = "item", name = "pr_used-improved-pollution-filter", amount = 1 },
            { type = "fluid", name = "water", amount = 100 },
          },
          results = {
            { type = "item", name = "pr_improved-pollution-filter", amount = 1 },
            { type = "item", name = "coal", amount = 1, independent_probability = 0.50 },
            { type = "item", name = "stone", amount = 1, independent_probability = 0.50 }
          },
          subgroup = "intermediate-product",
          order = "w3-b[pr_restore-used-pollution-filter]",
        }
  })
end