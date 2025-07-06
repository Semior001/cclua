local monitor = {}

-- Run - start the monitor node
-- This node displays the timetable on connected monitors
-- @param branch - the branch name for this monitor
-- @param scale - text scale for monitors (default: 1)
function monitor.Run(branch, scale)
    local network = require("network")

    if not branch then
        error("Branch name is required")
    end
    
    scale = scale or 1

    network.Prepare("monitor", branch, "")

    print("Monitor node started for branch: " .. branch)

    -- Find all connected monitors
    local monitors = { peripheral.find("monitor") }
    if #monitors == 0 then
        error("No monitors found")
    end

    print("Found " .. #monitors .. " monitor(s)")

    -- Setup monitors
    for i, mon in ipairs(monitors) do
        mon.clear()
        mon.setTextScale(scale)
        print("Initialized monitor " .. i .. " with scale " .. scale)
    end

    -- Main loop - wait for timetable updates
    while true do
        print("Waiting for timetable update...")
        local timetable = network.AwaitTimetableUpdate()

        if timetable then
            print("Received timetable update, displaying...")
            monitor.displayTimetable(monitors, timetable, branch, scale)
        end
    end
end

-- Display timetable on monitors
function monitor.displayTimetable(monitors, timetable, branch, scale)
    local currentTime = os.epoch("local")

    for _, mon in ipairs(monitors) do
        mon.clear()
        mon.setTextScale(scale)
        local width, height = mon.getSize()

        -- Header
        mon.setCursorPos(1, 1)
        local headerText = string.upper(branch) .. " LINE"
        local headerPadding = math.floor((width - #headerText) / 2)
        mon.write(string.rep(" ", headerPadding) .. headerText)

        -- Table header
        mon.setCursorPos(1, 3)
        local timeHeader = "TIME"
        local stationHeader = "STATION"
        local timeColWidth = 8
        local stationColWidth = width - timeColWidth - 3

        mon.write(" " .. timeHeader .. string.rep(" ", timeColWidth - #timeHeader - 1) .. "| " .. stationHeader)

        -- Separator line
        mon.setCursorPos(1, 4)
        mon.write(string.rep("-", width))

        local row = 5

        -- Check if we have any timetable data
        if next(timetable) == nil then
            mon.setCursorPos(1, row)
            mon.write(" ~      | Waiting for trains...")
        else
            -- Sort stations by next arrival time
            local stations = {}
            for stationName, data in pairs(timetable) do
                table.insert(stations, { name = stationName, data = data })
            end

            table.sort(stations, function(a, b)
                return a.data.nextArrival < b.data.nextArrival
            end)

            -- Display each station
            for _, station in ipairs(stations) do
                if row >= height then
                    break
                end

                local stationName = station.name
                local data = station.data

                mon.setCursorPos(1, row)

                -- Calculate time until next train
                local timeUntilNext = data.nextArrival - currentTime
                local timeStr = "~"

                if timeUntilNext > 0 then
                    local minutesUntilNext = math.floor(timeUntilNext / 60000)
                    local secondsUntilNext = math.floor((timeUntilNext % 60000) / 1000)

                    if minutesUntilNext > 0 then
                        timeStr = minutesUntilNext .. "m " .. secondsUntilNext .. "s"
                    elseif secondsUntilNext > 0 then
                        timeStr = secondsUntilNext .. "s"
                    else
                        timeStr = "Now!"
                    end
                elseif timeUntilNext > -30000 then -- Within 30 seconds past
                    timeStr = "Now!"
                end

                -- Truncate station name if too long
                local displayName = stationName
                if #displayName > stationColWidth then
                    displayName = string.sub(displayName, 1, stationColWidth - 3) .. "..."
                end

                -- Format the row
                local formattedTime = " " .. timeStr .. string.rep(" ", timeColWidth - #timeStr - 1)
                mon.write(formattedTime .. "| " .. displayName)

                row = row + 1
            end
        end
    end
end

return monitor
