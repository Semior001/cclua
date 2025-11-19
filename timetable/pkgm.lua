-- Metro Timetable System Package
-- Made with Claude Code

return {
    name = "timetable",
    version = "1.0.0",
    description = "Real-time train schedule tracking and display system for ComputerCraft metro networks",
    author = "Made with Claude Code",
    main = "timetable.lua",
    files = {
        ["timetable.lua"] = "timetable/timetable.lua",
        ["README.md"] = "timetable/README.md",
        ["config_station_example.lua"] = "timetable/config_station_example.lua",
        ["config_master_example.lua"] = "timetable/config_master_example.lua",
        ["config_monitor_example.lua"] = "timetable/config_monitor_example.lua"
    }
}
