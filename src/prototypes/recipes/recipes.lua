---------------------------------------------------------------------------
-- -- -- DATA EXTENSION ITSELF
---------------------------------------------------------------------------
data:extend({
        -------------
        -- ITEMS
        -------------
        -- Same cost with or without Space Age. Plastic keeps filters behind
        -- oil processing, and the unlocking technology requires plastics so
        -- the filter is craftable the moment it unlocks.
        {
          type = "recipe",
          name = "pr_pollution-filter",
          energy_required = 10,
          enabled = false,
          allow_productivity = true,
          ingredients = {
            { type = "item", name = "coal", amount = 2 },
            { type = "item", name = "iron-plate", amount = 2 },
            { type = "item", name = "steel-plate", amount = 1 },
            { type = "item", name = "plastic-bar", amount = 2 },
          },
          results = { { type = "item", name = "pr_pollution-filter", amount = 1 } },
        },
        -------------
        -- AIR PURIFICATION
        -------------
        -- Pipe-fed: the filter traps pollution that intakes already pulled out
        -- of the air, and the water the intake used to capture it comes back
        -- out. It no longer touches the atmosphere directly; the only
        -- pollution involved is what the assembler itself emits while running.
        --
        -- crafting-with-fluid puts this in Assembler 2 and 3 only, since
        -- Assembler 1 has no fluid connections. Those have one fluid input and
        -- one fluid output, which is why water is an output here rather than
        -- a second input.
        --
        -- Base rate at crafting speed 1.0: 75 polluted water per 60s, a
        -- tenth of the old building's 75 atmospheric units per minute at the
        -- 1 atmospheric : 10 fluid exchange rate. One intake (150/min) feeds
        -- two of these.
        {
          type = "recipe",
          name = "pr_air-cleaning",
          categories = { "crafting-with-fluid" },
          icon = "__pollution-reclamation__/graphics/icons/recipes/filtering.png",
          icon_size = 64,
          energy_required = 60,
          enabled = false,
          hide_from_player_crafting = true,
          ingredients = {
            { type = "fluid", name = "pr_polluted-water", amount = 75 },
            { type = "item", name = "pr_pollution-filter", amount = 1 },
          },
          results = {
            { type = "item", name = "pr_used-pollution-filter", independent_probability = 0.80, amount = 1 },
            { type = "fluid", name = "water", amount = 75 },
          },
          subgroup = "raw-material",
          order = "zz[air-cleaning]",
        },
        -------------
        -- FILTER RESTORATION
        -------------
        -- Solvent is sulfuric acid cut with light oil: the oil dissolves the
        -- tar and soot fouling a used filter so the acid can reach the
        -- mineral residue underneath. Light oil only exists after advanced
        -- oil processing, which is what gates restoration to blue science.
        --
        -- 100 solvent/min per plant against 20/min per restoring plant: one
        -- solvent plant supplies exactly five restoring plants. Both run in
        -- chemical plants, so the ratio holds at any plant speed.
        {
          type = "recipe",
          name = "pr_solvent",
          categories = { "chemistry" },
          energy_required = 3,
          enabled = false,
          ingredients = {
            { type = "fluid", name = "sulfuric-acid", amount = 5 },
            { type = "fluid", name = "light-oil", amount = 2.5 },
          },
          results = {
            { type = "fluid", name = "pr_solvent", amount = 5 },
          },
          subgroup = "fluid-recipes",
          order = "z[pollution-reclamation]-a[solvent]",
        },
        -- No byproduct on purpose: recovering material from used filters is
        -- deferred to a later extraction branch of the tech tree.
        {
          type = "recipe",
          name = "pr_restore-used-pollution-filter",
          categories = { "chemistry" },
          icon = "__pollution-reclamation__/graphics/icons/recipes/restore-used-pollution-filter.png",
          icon_size = 128,
          energy_required = 60,
          enabled = false,
          ingredients = {
            { type = "item", name = "pr_used-pollution-filter", amount = 1 },
            { type = "fluid", name = "pr_solvent", amount = 20 },
          },
          results = {
            { type = "item", name = "pr_pollution-filter", amount = 1 },
          },
          subgroup = "intermediate-product",
          order = "w3-a[pr_restore-used-pollution-filter]",
        },
        -------------
        -- POLLUTION ECONOMY: BUILDINGS
        -------------
        {
          type = "recipe",
          name = "pr_pollution-condenser",
          energy_required = 5,
          enabled = false,
          ingredients = {
            { type = "item", name = "steel-plate", amount = 2 },
            { type = "item", name = "iron-gear-wheel", amount = 4 },
            { type = "item", name = "pipe", amount = 2 },
          },
          results = { { type = "item", name = "pr_pollution-condenser", amount = 1 } },
        },
        {
          type = "recipe",
          name = "pr_pollution-vaporizer",
          energy_required = 5,
          enabled = false,
          ingredients = {
            { type = "item", name = "steel-plate", amount = 2 },
            { type = "item", name = "iron-gear-wheel", amount = 2 },
            { type = "item", name = "pipe", amount = 4 },
            { type = "item", name = "copper-cable", amount = 2 },
          },
          results = { { type = "item", name = "pr_pollution-vaporizer", amount = 1 } },
        },
        -------------
        -- POLLUTION ECONOMY: PROCESS
        -------------
        -- Zero ingredients is a fully supported recipe shape (not a
        -- placeholder-needs-something case) -- condenser has nothing for a
        -- player to insert, gated purely by ambient pollution via
        -- control.lua rather than by a consumable.
        --
        -- Fluid/atmosphere exchange rate: 1 unit of atmospheric pollution
        -- (the -15/min removed by the entity's emissions_per_minute, see
        -- pollution-condenser-building.lua) is represented by 10 units of
        -- polluted water, so the fluid reads as genuinely bulky
        -- rather than a tidy 1:1 bottling. 10 fluid / 4s = 150/min at
        -- continuous uptime; actual throughput is lower whenever
        -- control.lua's threshold gate takes the building offline, which is
        -- the intended "early game capture is genuinely gated" feel.
        --
        -- Water is the scrubbing medium, consumed 1:1 with the captured
        -- pollution produced (10 water -> 10 polluted water). This is
        -- what gives condenser a real consumable cost -- before it, a built and
        -- powered condenser ran free forever. It also extends the water-as-
        -- cleaning-agent logic the filter-restore recipes above already use,
        -- and matches how real wet scrubbers actually capture particulates.
        {
          type = "recipe",
          name = "pr_pollution-condensing",
          categories = { "pr_pollution-condenser-category" },
          icon = "__pollution-reclamation__/graphics/icons/fluids/polluted-water.png",
          icon_size = 64,
          energy_required = 4,
          enabled = false,
          hidden = false,
          hide_from_player_crafting = true,
          ingredients = {
            { type = "fluid", name = "water", amount = 10 },
          },
          results = {
            { type = "fluid", name = "pr_polluted-water", amount = 10 },
          },
          subgroup = "raw-material",
          order = "zz[pollution-condensing]",
        },
        -- Same 10:1 fluid-to-atmosphere exchange rate as condensing (see
        -- above), so the two sides of the loop stay volume-matched at the
        -- new scale before emissions_multiplier makes venting lossy: this
        -- building only ever emits while it has real captured fluid to
        -- consume, never for free.
        --
        -- The pollution vaporizer is a straight outflow: the polluted
        -- water is evaporated into the air,
        -- pollution and water together, so nothing comes back out. Empty
        -- results is a fully supported "pure sink" recipe shape; with no
        -- product, icon and subgroup can't be inherited and are set
        -- explicitly below.
        {
          type = "recipe",
          name = "pr_pollution-vaporizing",
          categories = { "pr_pollution-vaporizer-category" },
          icon = "__pollution-reclamation__/graphics/icons/fluids/polluted-water.png",
          icon_size = 64,
          energy_required = 4,
          enabled = false,
          hidden = false,
          hide_from_player_crafting = true,
          ingredients = {
            { type = "fluid", name = "pr_polluted-water", amount = 10 },
          },
          results = {},
          -- Deliberately lossy round trip per the design doc's biter-aggro
          -- risk mitigation: venting releases more pollution than the fluid
          -- it consumed represents.
          --
          -- 10% tax: evaporating the water off to release the pollution is
          -- its own inefficient process, so venting emits
          -- more than was captured. Against condenser's -15/min this yields
          -- +16.5/min -- 150 vs 165 in fluid-equivalent terms, at the 1
          -- atmospheric : 10 fluid exchange rate used throughout.
          emissions_multiplier = 1.1,
          subgroup = "raw-material",
          order = "zz[pollution-vaporizing]",
        }
})
