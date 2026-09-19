-- Placeholder icon: reuses vanilla light-oil's sprite until this mod has a
-- custom-art pipeline. Unlike polluted water, solvent is an ordinary
-- chemical, so the base mod's automatic barrel recipes are left on.
data:extend({
  {
    type = "fluid",
    name = "pr_solvent",
    subgroup = "fluid",
    default_temperature = 25,
    base_color = { 0.45, 0.3, 0.55 },
    flow_color = { 0.7, 0.55, 0.8 },
    icon = "__base__/graphics/icons/fluid/light-oil.png",
    order = "z[pollution-reclamation]-b[solvent]",
  },
})
