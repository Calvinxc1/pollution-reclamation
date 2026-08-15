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
        },
        -------------
        -- POLLUTION ECONOMY: BUILDINGS
        -------------
        {
          type = "recipe",
          name = "pr_pollution-intake",
          energy_required = 5,
          enabled = false,
          ingredients = {
            { type = "item", name = "steel-plate", amount = 2 },
            { type = "item", name = "iron-gear-wheel", amount = 4 },
            { type = "item", name = "pipe", amount = 2 },
          },
          results = { { type = "item", name = "pr_pollution-intake", amount = 1 } },
        },
        {
          type = "recipe",
          name = "pr_pollution-outflow",
          energy_required = 5,
          enabled = false,
          ingredients = {
            { type = "item", name = "steel-plate", amount = 2 },
            { type = "item", name = "iron-gear-wheel", amount = 2 },
            { type = "item", name = "pipe", amount = 4 },
            { type = "item", name = "copper-cable", amount = 2 },
          },
          results = { { type = "item", name = "pr_pollution-outflow", amount = 1 } },
        },
        -------------
        -- POLLUTION ECONOMY: PROCESS
        -------------
        -- Zero ingredients is a fully supported recipe shape (not a
        -- placeholder-needs-something case) -- intake has nothing for a
        -- player to insert, gated purely by ambient pollution via
        -- control.lua rather than by a consumable.
        --
        -- Fluid/atmosphere exchange rate: 1 unit of atmospheric pollution
        -- (the -15/min removed by the entity's emissions_per_minute, see
        -- pollution-intake-building.lua) is represented by 10 units of
        -- captured-pollution fluid, so the fluid reads as genuinely bulky
        -- rather than a tidy 1:1 bottling. 10 fluid / 4s = 150/min at
        -- continuous uptime; actual throughput is lower whenever
        -- control.lua's threshold gate takes the building offline, which is
        -- the intended "early game capture is genuinely gated" feel.
        --
        -- Water is the scrubbing medium, consumed 1:1 with the captured
        -- pollution produced (10 water -> 10 captured pollution). This is
        -- what gives intake a real consumable cost -- before it, a built and
        -- powered intake ran free forever. It also extends the water-as-
        -- cleaning-agent logic the filter-restore recipes above already use,
        -- and matches how real wet scrubbers actually capture particulates.
        {
          type = "recipe",
          name = "pr_pollution-capture",
          categories = { "pr_pollution-intake-category" },
          icon = "__base__/graphics/icons/fluid/sulfuric-acid.png",
          icon_size = 64,
          energy_required = 4,
          enabled = false,
          hidden = false,
          hide_from_player_crafting = true,
          ingredients = {
            { type = "fluid", name = "water", amount = 10 },
          },
          results = {
            { type = "fluid", name = "pr_captured-pollution", amount = 10 },
          },
          subgroup = "raw-material",
          order = "zz[pollution-capture]",
        },
        -- Empty results is likewise a fully supported "pure sink" recipe
        -- shape. With no product, icon/subgroup can't be inherited and are
        -- non-optional here -- both set explicitly below.
        --
        -- Same 10:1 fluid-to-atmosphere exchange rate as capture (see
        -- above), so the two sides of the loop stay volume-matched at the
        -- new scale before emissions_multiplier makes venting lossy: this
        -- building only ever emits while it has real captured fluid to
        -- consume, never for free.
        {
          type = "recipe",
          name = "pr_pollution-venting",
          categories = { "pr_pollution-outflow-category" },
          icon = "__base__/graphics/icons/fluid/sulfuric-acid.png",
          icon_size = 64,
          energy_required = 4,
          enabled = false,
          hidden = false,
          hide_from_player_crafting = true,
          ingredients = {
            { type = "fluid", name = "pr_captured-pollution", amount = 10 },
          },
          results = {},
          -- Deliberately lossy round trip per the design doc's biter-aggro
          -- risk mitigation: venting releases more pollution than the fluid
          -- it consumed represents. Same lever already proven on
          -- pr_air-cleaning-2 above (there used to speed up scrubbing,
          -- here used to inflate emissions instead).
          --
          -- 10% tax: boiling the water back off to re-release the pollution
          -- is its own energy-hungry, inefficient process, so venting emits
          -- more than was captured. Against intake's -15/min this yields
          -- +16.5/min -- 150 vs 165 in fluid-equivalent terms, at the 1
          -- atmospheric : 10 fluid exchange rate used throughout.
          emissions_multiplier = 1.1,
          subgroup = "raw-material",
          order = "zz[pollution-venting]",
        }
  })
end