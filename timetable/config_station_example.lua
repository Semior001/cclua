-- Station Mode Configuration Example
-- Made with Claude Code
--
-- Copy this file to timetable_config.lua and customize for your station

return {
    mode = "station",

    -- Name of this station
    stationName = "SpawnTown",

    -- Branch this station belongs to
    branch = "ST-EF",

    -- Protocol name for rednet communication (must match across all computers)
    protocol = "metro_timetable"
}
