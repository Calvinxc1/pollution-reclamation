-- Shown in game as "Polluted water": ambient pollution scrubbed out of the air
-- into water. The internal name stays pr_captured-pollution. The icon is a
-- grimy take on vanilla water's droplet, in the same 64px, four-mipmap layout;
-- the colours are sampled from it.
data:extend({
  {
    type = "fluid",
    name = "pr_captured-pollution",
    subgroup = "fluid",
    default_temperature = 25,
    base_color = { 0.3, 0.3, 0.24 },
    flow_color = { 0.6, 0.6, 0.5 },
    icon = "__pollution-reclamation__/graphics/icons/fluids/captured-pollution.png",
    -- Prevent the base mod's data-updates stage from auto-generating a
    -- barrel item/recipe pair for this fluid; captured pollution is meant to
    -- travel by pipe, not by crate.
    auto_barrel = false,
    order = "z[pollution-reclamation]-a[captured-pollution]",
  },
})
