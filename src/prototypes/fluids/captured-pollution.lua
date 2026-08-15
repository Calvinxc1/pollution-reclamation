-- Placeholder icon: reuses vanilla sulfuric-acid's sprite (murky yellow-green,
-- thematically close to "bottled industrial pollutant") until this mod has a
-- custom-art pipeline. Swap `icon` for a real sprite later without touching
-- any other field here.
data:extend({
  {
    type = "fluid",
    name = "pr_captured-pollution",
    subgroup = "fluid",
    default_temperature = 25,
    base_color = { 0.55, 0.6, 0.12 },
    flow_color = { 0.75, 0.85, 0.15 },
    icon = "__base__/graphics/icons/fluid/sulfuric-acid.png",
    -- Prevent the base mod's data-updates stage from auto-generating a
    -- barrel item/recipe pair for this fluid; captured pollution is meant to
    -- travel by pipe, not by crate.
    auto_barrel = false,
    order = "z[pollution-reclamation]-a[captured-pollution]",
  },
})
