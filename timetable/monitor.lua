local monitor = {}

-- Run - start the monitor node
-- This node displays the timetable on connected monitors
-- @param branch - the branch name for this monitor
function monitor.Run(branch)
    local network = require("network")

    if not branch then
        error("Branch name is required")
    end

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
        mon.setTextScale(1)
        print("Initialized monitor " .. i)
    end

    -- Main loop - wait for timetable updates
    while true do
        print("Waiting for timetable update...")
        local timetable = network.AwaitTimetableUpdate()

        if timetable then
            print("Received timetable update, displaying...")
            monitor.displayTimetable(monitors, timetable, branch)
        end
    end
end

-- Display timetable on monitors
function monitor.displayTimetable(monitors, timetable, branch)
    local currentTime = os.epoch("local")

    for _, mon in ipairs(monitors) do
        mon.clear()
        mon.setCursorPos(1, 1)

        -- Header
        mon.write("=== " .. string.upper(branch) .. " LINE TIMETABLE ===")
        mon.setCursorPos(1, 2)
        mon.write("Updated: " .. os.date("%X", currentTime / 1000))
        mon.setCursorPos(1, 3)
        mon.write("----------------------------------------")

        local row = 4

        -- Check if we have any timetable data
        if next(timetable) == nil then
            mon.setCursorPos(1, row)
            mon.write("No timetable data available")
            mon.setCursorPos(1, row + 1)
            mon.write("Waiting for train arrivals...")
        else
            -- Display each station
            for stationName, data in pairs(timetable) do
                if row > 18 then -- Assuming standard monitor height
                    break
                end

                mon.setCursorPos(1, row)
                mon.write(stationName)

                -- Calculate time until next train
                local timeUntilNext = data.nextArrival - currentTime
                local minutesUntilNext = math.floor(timeUntilNext / 60000)
                local secondsUntilNext = math.floor((timeUntilNext % 60000) / 1000)

                mon.setCursorPos(1, row + 1)
                if minutesUntilNext > 0 then
                    mon.write("  Next: " .. minutesUntilNext .. "m " .. secondsUntilNext .. "s")
                elseif secondsUntilNext > 0 then
                    mon.write("  Next: " .. secondsUntilNext .. "s")
                else
                    mon.write("  Next: Now!")
                end

                -- Show average interval
                local avgMinutes = math.floor(data.avgInterval / 60000)
                mon.setCursorPos(1, row + 2)
                mon.write("  Freq: every " .. avgMinutes .. "m")

                -- Show total arrivals
                mon.setCursorPos(1, row + 3)
                mon.write("  Arrivals: " .. data.totalArrivals)

                row = row + 4
            end
        end

        -- Footer
        local width, height = mon.getSize()
        mon.setCursorPos(1, height)
        mon.write("ComputerCraft Timetable System")
    end
end

return monitor
