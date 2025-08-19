local PROTOCOL = "timetable"
local CONFIG_FILE = "config.lua"


local function findModem()
    local sides = { "top", "bottom", "left", "right", "front", "back" }

    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            if peripheral.call(side, "isWireless") then
                return side
            end
        end
    end

    return nil
end

-- ========= master =========

local master = {
    branch = "",
    lastStation = "", 
    stations = {}, -- []station
    arrivals = {}, -- map[from][to][]time 
    broadcastInterval = 5, -- seconds
}

local lastEvents = {} -- list of last log events, to print at the bottom of the screen

function lastEvents.add(event)
    table.insert(lastEvents, event)
    if #lastEvents > 3 then
        table.remove(lastEvents, 1) -- keep only the last 3 events
    end
end

function master.save()
    local file = fs.open(CONFIG_FILE, "w")
    file.write(textutils.serialize(master))
    file.close()
end

function master.load()
    if not fs.exists(CONFIG_FILE) then    
        error("Configuration file does not exist")
    end
    local file = fs.open(CONFIG_FILE, "r")
    master = textutils.unserialize(file.readAll())
    file.close()

    if not master.branch or master.branch == "" then
        error("Branch is not set in the configuration file")
    end

    if not master.stations or #master.stations == 0 then
        error("No stations defined in the configuration file")
    end

    if not master.arrivals then
        master.arrivals = {}
    end

    if not master.lastStation then
        master.lastStation = ""
    end

    if not master.broadcastInterval or master.broadcastInterval <= 0 then
        master.broadcastInterval = 5 -- default to 5 seconds
    end

    for _, station in ipairs(master.stations) do
        if not master.arrivals[station] then
            master.arrivals[station] = {}
        end
        for _, otherStation in ipairs(master.stations) do
            if station ~= otherStation and not master.arrivals[station][otherStation] then
                master.arrivals[station][otherStation] = {}
            end
        end
    end
end

function master.recordArrival(station)
    if master.lastStation == "" then
        master.lastStation = station
        return
    end

    table.insert(master.arrivals[master.lastStation][station], os.epoch("utc"))
    if #master.arrivals[master.lastStation][station] > 10 then
        table.remove(master.arrivals[master.lastStation][station], 1) -- keep only the last 10 arrivals
    end
    master.lastStation = station
    lastEvents.add(string.format("%s: recorded arrival at %s from %s", 
        os.date("%H:%M:%S", os.epoch("utc")), station, master.lastStation))
end

function master.averageTravelTime(from, to)
    local times = master.arrivals[from][to]
    if #times == 0 then
        return -1
    end

    local total = 0
    for _, time in ipairs(times) do
        total = total + time
    end

    return total / #times
end

function master.timetable(now)
    local timetable = {} -- [{ station, estimatedTime }, ...]

    for _, station in ipairs(master.stations) do
        local averageTime = master.averageTravelTime(master.lastStation, station)
        if averageTime ~= -1 then
            table.insert(timetable, { station = station, estimatedTime = now + averageTime })
        end
    end
    table.sort(timetable, function(a, b)
        return a.estimatedTime < b.estimatedTime
    end)
    return timetable
end

function master.broadcastTimetable()
    local now = os.epoch("utc")
    local timetable = master.timetable(now)
    local message = {
        type = "timetable_update",
        branch = master.branch,
        stations = master.stations,
        timetable = timetable,
        now = now,
    }
    rednet.broadcast(message, PROTOCOL)
end

function master.statusText()
    local text = ""
    text = text .. strings.format("Branch: %s, Broadcast interval: %ds\n", master.branch, master.broadcastInterval)
    text = text .. strings.format("Last Station: %s\n", master.lastStation)
    text = text .. strings.format("Stations: %s\n", table.concat(master.stations, ", "))
    text = text .. "Arrivals:\n"
    for from, destinations in pairs(master.arrivals) do
        for to, times in pairs(destinations) do
            local avg = master.averageTravelTime(from, to)
            text = text .. strings.format("  %s -> %s: %d arrivals, avg: %d\n", from, to, #times, avg)
        end
    end
    text = text .. "Press 'q' to quit, 'r' to reset data\n"
    return text
end

function master.printStatus()
    term.clear()
    term.setCursorPos(1, 1)
    print(master.statusText())
    
    -- if there are last events, print them
    if #lastEvents > 0 then
        -- set cursor at the third to the bottom row, clear it
        for i = 1, 3 do
            term.setCursorPos(1, term.getSize() - i)
            term.clearLine()
        end
        term.setCursorPos(1, term.getSize() - 2)
        local start = math.max(1, #lastEvents - 2)
        for i = start, #lastEvents do
            term.write(lastEvents[i] .. "\n")
        end
    end

    local display = peripheral.find("monitor")
    if not display then
        return
    end

    display.clear()
    display.setCursorPos(1, 1)
    display.write(master.statusText())
end

function master.run()
    master.load()
    local modemSide = findModem()
    if not modemSide then
        error("No wireless modem found")
    end

    rednet.open(modemSide)
    rednet.host(PROTOCOL, master.branch)

    local broadcast_timer = os.startTimer(master.broadcastInterval)
    while true do
        local event, senderID, message = os.pullEvent()
        if event == "rednet_message" then
            if     not message 
                or not message.type   or message.type   ~= "arrival"
                or not message.branch or message.branch ~= master.branch
                or not message.station then
                goto continue
            end
            master.recordArrival(message.station)
        elseif event == "timer" and param1 == broadcast_timer then
            master.broadcastTimetable()
            broadcast_timer = os.startTimer(master.config.broadcast_interval)
        elseif event == "char" then
            if param1 == "q" then
                break
            elseif param1 == "r" then
                master.arrivals = {}
                master.lastStation = ""
                master.save()
            end
        end

        master.printStatus()
        ::continue::
    end

    rednet.close(modemSide)
    master.save()
    print("master has stopped")
end

--- ======== monitor =========

local monitor = {
    branch = "",
    scale = 1
}

function monitor.drawTimetable(timetable)
    -- {
    --   type: "timetable_update",
    --   branch: "branch_name",
    --   stations: ["station1", "station2", ...],
    --   timetable: [{ station: "station1", estimatedTime: 1234567890 }, ...],
    --   now: current_time_in_utc
    -- }

    local display = peripheral.find("monitor")
    if not display then
        return
    end

    display.clear()
    display.setCursorPos(1, 1)
    display.setTextScale(monitor.scale)

    monitor.printCenter(display, "=== Branch: %s ===", monitor.branch)
    monitor.print(display, "Time: %s", os.date("%H:%M:%S", timetable.now))
    
    for _, entry in ipairs(timetable.timetable) do
        local station = entry.station
        local estimatedTime = os.date("%H:%M:%S", entry.estimatedTime)

        local text = station
        if estimatedTime < 0 then
            text = text .. " $RED$OVERDUE$WHITE$"
        elseif estimatedTime < 5 then
            text = text .. " $YELLOW$SOON$WHITE$"
        else
            text = text .. " " .. estimatedTime
        end
        monitor.print(display, text)
    end
end

local colors = {
    ["RED"] = colors.red,
    ["YELLOW"] = colors.yellow,
    ["WHITE"] = colors.white,
    ["GREEN"] = colors.green,
    ["BLUE"] = colors.blue,
    ["MAGENTA"] = colors.magenta,
    ["CYAN"] = colors.cyan,
    ["GRAY"] = colors.gray
}

function monitor.print(display, format, ...)
    local text = string.format(format, ...)
    local x, y = display.getCursorPos()
    display.setCursorPos(x, y + 1)
    monitor.write(display, text)
end

function monitor.write(display, text)
    -- iterate over each character in the text, if there is a substring with $color$ then set the color
    for i = 1, #text do
        local c = text:sub(i,i)
        if c == "$" then
            local color = text:match("^(%w+)$", i + 1)
            if color then
                display.setTextColor(colors[color:upper()] or colors.white)
                i = i + #color + 1
            else
                display.write(c)
                i = i + 1
            end
        else
            display.write(c)
        end
    end
end

function monitor.printCenter(display, format, ...)
    local text = string.format(format, ...)
    local width, _ = display.getSize()
    local textWidth = string.len(text)
    local x = math.floor((width - textWidth) / 2) + 1
    display.setCursorPos(x, 1)
    monitor.write(display, text)
end

function monitor.run()
    local modemSide = findModem()
    if not modemSide then
        error("No wireless modem found")
    end

    rednet.open(modemSide)
    print("Using modem on " .. modemSide .. " side")
    print("Monitor node starting for branch: " .. monitor.branch)
    print("Scale: " .. monitor.scale)
    print("Press 'q' to quit")

    monitor.drawTimetable()
    while true do
        local event, senderID, message = os.pullEvent()
        if event == "rednet_message" then
            if not message
                or not message.type   or message.type   ~= "timetable_update"
                or not message.branch or message.branch ~= monitor.branch then
                goto continue
            end
            monitor.drawTimetable(message)
        elseif event == "char" then
            if param1 == "q" then
                break
            end
        end
        ::continue::
    end

    rednet.close(modemSide)
    print("monitor has stopped")
end

-- ========= station =========
local station = {
    branch = "",
    name = "",
}

function station.sendArrival()
    local message = {
        type = "arrival",
        branch = station.branch,
        station = station.name,
    }
    rednet.send(rednet.lookup(PROTOCOL, station.branch), message)
    print(string.format("%s: sent arrival from %s", os.date("%H:%M:%S", os.epoch("utc")), station.name))
end

function station.hasRedstoneSignal()
    local sides = { "top", "bottom", "left", "right", "front", "back" }
    for _, side in ipairs(sides) do
        if redstone.getInput(side) then
            return true
        end
    end
    return false
end

function station.run()
    local modemSide = findModem()
    if not modemSide then
        error("No wireless modem found")
    end
    
    rednet.open(modemSide)
    print("Using modem on " .. modemSide .. " side"
    print("Station node starting for branch: " .. station.branch)
    print("Station name: " .. station.name)
    print("Press 'a' to send arrival, 'q' to quit")
    
    while true do
        local event = os.pullEvent()
        if event == "char" then
            if param1 == "a" then
                station.sendArrival()
            elseif param1 == "q" then
                break
            end
        elseif event == "redstone" and station.hasRedstoneSignal() then
            station.sendArrival()
        end
    end
end

local function main(args)
    if #args < 2 then
        print("Usage: timetable <mode> <branch>")
        return
    end

    local mode = args[1]
    local branch = args[2]

    if mode ~= "master" and mode ~= "monitor" and mode ~= "station" then
        print("Invalid mode. Use 'master', 'monitor', or 'station'.")
        return
    end

    if not branch or branch == "" then
        print("Branch name is required.")
        return
    end

    if mode == "master" then
        master.branch = branch
        master.run()
    elseif mode == "monitor" then
        monitor.branch = branch
        if #args > 2 then
            monitor.scale = tonumber(args[3])
        end
        monitor.run()
    elseif mode == "station" then
        station.branch = branch
        if #args < 3 then
            print("Usage: timetable station <branch> <name>")
            return
        end
        station.name = args[3]
        station.run()
    else

end

local args = { ... }
main(args)
