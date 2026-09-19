data:extend({
  {
    type = "item",
    name = "pr_pollution-sensor",
    icon = "__pollution-reclamation__/graphics/icons/entities/pollution-sensor.png",
    icon_size = 64,
    -- Beside the condenser and vaporizer in the production tab: the three are
    -- built and placed together, whatever the sensor is made of.
    subgroup = "production-machine",
    order = "z[pollution-sensor]",
    place_result = "pr_pollution-sensor",
    stack_size = 50,
    weight = 2*kg,
  },
})
