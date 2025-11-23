local httplike = require("httplike.httplike")
local log = require("logging.logging")

local function help()
    print("Usage: timetable [command] [options]")
    print("Commands:")
    print("  master  - start the timetable master server")
    print("  station <branch> <station> - start a station client")
    print("  monitor <branch> [scale]   - start a monitor client")
end

local config = {
    mode = nil, -- "master", "station", or "monitor"
    masterId = nil,
    branch = nil,
    station = nil,
    scale = 1,
}

local function parseArgs(args)
    log.Printf("[DEBUG] parsing args: %s", table.concat(args, " "))
    if #args == 0 then
        help()
        return false
    end

    local command = args[1]

    if command == "master" then
        config.mode = "master"
    elseif command == "station" then
        if not args[2] or not args[3] then
            print("Error: branch, and station required")
            return false
        end
        config.mode = "station"
        config.branch = args[2]
        config.station = args[3]
    elseif command == "monitor" then
        if not args[2] then
            print("Error: branch is required")
            return false
        end
        config.mode = "monitor"
        config.branch = args[2]
        config.scale = tonumber(args[3]) or config.scale
    else
        print("Error: unknown command '" .. command .. "'")
        help()
        return false
    end

    return true
end

local function onCallQuit(fn)
    return function()
        while true do
            ---@diagnostic disable-next-line: undefined-field
            local _, key, _ = os.pullEvent("char")
            if key == "q" then
                fn()
                break
            end
        end
    end
end

local function main(args)
    if not parseArgs(args) then
        return
    end

    local lgr = log.Logger.new()
    lgr:setDateFormat("%H:%M:%S")
    lgr:setLevel("DEBUG")
    log.SetLogger(lgr)

    if config.mode == "master" then
        log.Printf("[INFO] starting timetable master on branch '%s'", config.branch)
        local master = require("timetable.master").new()
        ---@diagnostic disable-next-line: undefined-global
        parallel.waitForAll(function() master:run() end, onCallQuit(function() master:stop() end))
    elseif config.mode == "station" then
        log.Printf("[INFO] starting timetable station '%s' on branch '%s'",
            config.station, config.branch)
        local station = require("timetable.station").new(config.station, config.branch)
        ---@diagnostic disable-next-line: undefined-global
        parallel.waitForAll(function() station:run() end, onCallQuit(function() station:stop() end))
    elseif config.mode == "monitor" then
        log.Printf("[INFO] starting timetable monitor on branch '%s' with scale %d",
            config.branch, config.scale)
        error("monitor mode not implemented yet")
    end
end

local args = { ... }
main(args)
