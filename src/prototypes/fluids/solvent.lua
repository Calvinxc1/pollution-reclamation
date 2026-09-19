-- Solvent: sulfuric acid cut with light oil, used to restore pollution
-- filters. The icon is a violet droplet with a faint oily sheen, matching
-- the wash in the restoration recipe icon; the colours are sampled from it.
-- Unlike polluted water, solvent is an ordinary chemical, so the base mod's
-- automatic barrel recipes are left on.
data:extend({
  {
    type = "fluid",
    name = "pr_solvent",
    subgroup = "fluid",
    default_temperature = 25,
    base_color = { 0.39, 0.25, 0.37 },
    flow_color = { 0.68, 0.52, 0.7 },
    icon = "__pollution-reclamation__/graphics/icons/fluids/solvent.png",
    order = "z[pollution-reclamation]-b[solvent]",
  },
})
