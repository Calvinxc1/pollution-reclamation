-- TEMPORARY DIAGNOSTIC OVERRIDES -- NOT PART OF THE REAL TIER-1 DESIGN.
--
-- Loaded last (see data.lua) so it can freely mutate the pollution-economy
-- prototypes already defined above, without touching their real source
-- files. Makes the whole loop testable in an active save immediately: no
-- research required, both buildings cost a single iron plate, no power draw.
--
-- To go back to the real tier-1 balance (technology-gated, real build
-- costs, real power draw): delete this file and its require line in
-- data.lua. Nothing in this file is a balance decision -- don't let these
-- numbers leak into playtesting notes.

-- No tech gate: all four new recipes usable immediately, without
-- pr_pollution-economy being researched.
for _, recipe_name in pairs({
  "pr_pollution-intake",
  "pr_pollution-outflow",
  "pr_pollution-capture",
  "pr_pollution-venting",
}) do
  data.raw.recipe[recipe_name].enabled = true
end

-- Trivial build cost for both buildings: 1 iron plate, nothing else.
data.raw.recipe["pr_pollution-intake"].ingredients = {
  { type = "item", name = "iron-plate", amount = 1 },
}
data.raw.recipe["pr_pollution-outflow"].ingredients = {
  { type = "item", name = "iron-plate", amount = 1 },
}

-- No power draw: switch both buildings to a void energy source. Mutating
-- the existing energy_source table in place (rather than replacing it)
-- keeps emissions_per_minute -- the actual capture/vent mechanic -- intact;
-- this only removes the electricity requirement, nothing else.
for _, entity_name in pairs({ "pr_pollution-intake", "pr_pollution-outflow" }) do
  local entity = data.raw["assembling-machine"][entity_name]
  entity.energy_source.type = "void"
  entity.energy_source.usage_priority = nil
  entity.energy_usage = "1W"
end
