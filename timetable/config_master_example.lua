-- Master Mode Configuration Example
-- Made with Claude Code
--
-- Copy this file to timetable_config.lua and customize for your metro system

return {
    mode = "master",

    -- Protocol name for rednet communication (must match across all computers)
    protocol = "metro_timetable",

    -- Define all branches and their stations
    branches = {
        -- Example circular line
        ["ST-EF"] = {
            stations = {
                "SpawnTown",
                "Novozavodsk",
                "EndFortress"
            },
            circular = true  -- Train returns to first station
        },

        -- Example straight line
        ["Main-Line"] = {
            stations = {
                "Central",
                "North",
                "Northwest",
                "West"
            },
            circular = false  -- Train terminates at last station
        },

        -- Add more branches as needed
        -- ["Branch-Name"] = {
        --     stations = {"Station1", "Station2", "Station3"},
        --     circular = true/false
        -- }
    }
}
