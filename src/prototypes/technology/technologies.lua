---------------------------------------------------------------------------
-- -- -- DATA EXTENSION ITSELF
---------------------------------------------------------------------------
-- The same tree with or without Space Age: every prerequisite below is a
-- base-game technology.
data:extend({
    -- Filters and the pipe-fed purifier recipe, mid-to-late green science.
    -- Keeps its 0.1.x internal name so saves that already researched it keep
    -- it. Requires plastics so the filter, which needs plastic bar, can be
    -- crafted the moment it unlocks; pr_pollution-economy supplies the
    -- polluted water the purifier consumes.
    --
    -- Restoring used filters is deliberately NOT here. Until
    -- pr_filter-restoration, filters are single-use and the player has to put
    -- the used ones somewhere.
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
          recipe = "pr_pollution-filter",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_air-cleaning",
        },
      },
      prerequisites = { "pr_pollution-economy", "plastics" },
      unit = {
        count = 300,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1}
        },
        time = 30,
      },
    },
    -- Solvent and filter restoration, early blue science. Gated on
    -- advanced-oil-processing because solvent needs light oil, which basic
    -- oil processing does not produce; that also brings chemical science.
    {
      type = "technology",
      name = "pr_filter-restoration",
      mod = "pollution-reclamation",
      icon = "__pollution-reclamation__/graphics/technologies/filter-restoration.png",
      icon_size = 256,
      icon_mipmaps = 4,
      effects = {
        {
          type = "unlock-recipe",
          recipe = "pr_solvent",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_restore-used-pollution-filter",
        },
      },
      prerequisites = { "pr_air-purification", "advanced-oil-processing" },
      unit = {
        count = 300,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1}
        },
        time = 30,
      },
    },
    -- Single root technology unlocking both tier-1 pollution-economy
    -- buildings together, per the design doc's explicit "Decided" call: a
    -- player should get a complete, playable capture/vent loop the moment
    -- this is researched, not half of one. Nauvis-scoped.
    --
    -- Gated on fluid-handling specifically, not just steel-processing/engine
    -- (which fluid-handling already requires transitively): fluid-handling
    -- is what actually unlocks storage-tank and pump. Without it, a player
    -- could build the condenser and vaporizer and connect them with plain pipes (those
    -- need no research) but couldn't build a tank farm -- one of the three
    -- core sinks in the design doc -- or use pumps for longer runs.
    {
      type = "technology",
      name = "pr_pollution-control",
      mod = "pollution-reclamation",
      icon = "__pollution-reclamation__/graphics/technologies/air-purifier.png",
      icon_size = 256,
      icon_mipmaps = 4,
      effects = {
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-condenser",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-vaporizer",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-condensing",
        },
        {
          type = "unlock-recipe",
          recipe = "pr_pollution-vaporizing",
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
