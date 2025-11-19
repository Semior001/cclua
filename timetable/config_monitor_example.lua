-- Monitor Mode Configuration Example
-- Made with Claude Code
--
-- Copy this file to timetable_config.lua and customize for your monitor

return {
    mode = "monitor",

    -- Which branch to display on this monitor
    branch = "ST-EF",

    -- Protocol name for rednet communication (must match across all computers)
    protocol = "metro_timetable",

    -- Optional: Define the order stations should appear on the monitor
    -- If not specified, stations will be sorted alphabetically
    stationOrder = {
        "SpawnTown",
        "Novozavodsk",
        "EndFortress"
    }
}
