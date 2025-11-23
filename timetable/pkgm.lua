-- Package definition for turtle control program
-- Made with Claude Code (https://claude.ai/code)

return {
    -- Basic package information
    name = "timetable",
    version = "2.0.0",
    description = "Timetable management system for Create trains",
    author = "semior",

    -- Main file to run when the program is executed
    main = "timetable.lua",

    -- Files to download
    files = {
        ["timetable.lua"] = "timetable.lua",
        ["timetable/master.lua"] = "timetable/master.lua",
        ["timetable/station.lua"] = "timetable/station.lua",
        ["timetable/monitor.lua"] = "timetable/monitor.lua",
        ["httplike/httplike.lua"] = "httplike/httplike.lua",
        ["httplike/middleware.lua"] = "httplike/middleware.lua",
        ["logging/logging.lua"] = "logging/logging.lua",
    }
}
