data:extend({
    {
        type = "int-setting",
        name = "pr_air-filtering-efficiency",
        setting_type = "startup",
        default_value = 75,
        allowed_values = {50, 75, 100}
    }
})

-- Spores are a Gleba mechanic, so this setting only means anything under Space
-- Age. prototypes/entities/air-purifier-building.lua reads it behind the same
-- condition; registering it unconditionally left base-game players with a
-- startup setting referring to a planet they do not have, wired to nothing.
if mods["space-age"] then
    data:extend({
        {
            type = "int-setting",
            name = "pr_air-filtering-efficiency-spore",
            setting_type = "startup",
            default_value = 50,
            allowed_values = {30, 50, 75, 100}
        }
    })
end
