local httplike = require("httplike.httplike")

local function help()
    print("Usage: timetable [command] [options]")
    print("Commands:")
    print("  master  <branch> - start the timetable master server")
    print("  station <masterId> <branch> <station> - start a station client")
    print("  monitor <masterId> <branch> [scale]   - start a monitor client")
end

local config = {
    mode = nil, -- "master", "station", or "monitor"
    masterId = nil,
    branch = nil,
    station = nil,
    scale = 1,
}

local function parseArgs(args)
    if #args == 0 then
        help()
        return false
    end

    local command = args[1]

    if command == "master" then
        if not args[2] then
            print("Error: branch required")
            return false
        end
        config.mode = "master"
        config.branch = args[2]
    elseif command == "station" then
        if not args[2] or not args[3] or not args[4] then
            print("Error: masterId, branch, and station required")
            return false
        end
        config.mode = "station"
        config.masterId = tonumber(args[2])
        config.branch = args[3]
        config.station = args[4]
    elseif command == "monitor" then
        if not args[2] or not args[3] then
            print("Error: masterId and branch required")
            return false
        end
        config.mode = "monitor"
        config.masterId = tonumber(args[2])
        config.branch = args[3]
        config.scale = tonumber(args[4]) or config.scale
    else
        print("Error: unknown command '" .. command .. "'")
        help()
        return false
    end

    return true
end

local function main(args)
    if not parseArgs(args) then
        return
    end

    if config.mode == "master" then
        require("timetable.master").start(config.branch)
    elseif config.mode == "station" then
        require("timetable.station").start(config.masterId, config.branch, config.station)
    elseif config.mode == "monitor" then
        require("timetable.monitor").start(config.masterId, config.branch, config.scale)
    end
end

local args = { ... }
main(args)
