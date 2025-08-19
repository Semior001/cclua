-- Timetable System
-- Made with Claude Code

local args = {...}

local PROTOCOL = "timetable"
local DATA_FILE = "timetable_data.lua"
local CONFIG_FILE = "master_config.lua"

local function findModem()
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            if peripheral.call(side, "isWireless") then
                return side
            end
        end
    end
    
    return nil
end

local function parseArgs()
    local mode = nil
    local options = {}
    
    for i, arg in ipairs(args) do
        if arg:match("^--mode=") then
            mode = arg:match("^--mode=(.+)")
        elseif arg:match("^--branch=") then
            options.branch = arg:match("^--branch=(.+)")
        elseif arg == "help" or arg == "--help" then
            mode = "help"
        elseif arg == "reset" then
            options.reset = true
        elseif arg == "reconfig" then
            options.reconfig = true
        elseif arg == "test" then
            options.test = true
        elseif arg:match("^--scale=") then
            options.scale = tonumber(arg:match("^--scale=(.+)")) or 1
        elseif arg:match("^--station=") then
            options.station = arg:match("^--station=(.+)")
        elseif not mode and (arg == "master" or arg == "monitor" or arg == "station") then
            mode = arg
        elseif not options.branch and mode and not options.station then
            options.branch = arg
        elseif not options.station and mode == "station" and options.branch then
            options.station = arg
        elseif not options.scale and mode == "monitor" and options.branch then
            options.scale = tonumber(arg) or 1
        end
    end
    
    return mode, options
end

local function showHelp()
    print("Timetable System")
    print("Usage: timetable <mode> <branch> [options]")
    print("")
    print("Modes:")
    print("  master <branch>            - Run as master node for branch")
    print("  monitor <branch> [scale]   - Run as monitor node for branch")
    print("  station <branch> <name>    - Run as station node for branch")
    print("")
    print("Alternative syntax:")
    print("  timetable --mode=master --branch=<branch> [options]")
    print("  timetable --mode=monitor --branch=<branch> --scale=2")
    print("  timetable --mode=station --branch=<branch> --station=<name>")
    print("")
    print("Master options:")
    print("  reset                      - Reset all timetable data")
    print("  reconfig                   - Reconfigure stations")
    print("")
    print("Station options:")
    print("  test                       - Run in test mode")
    print("")
    print("Examples:")
    print("  timetable master Main_Line")
    print("  timetable monitor Main_Line 2")
    print("  timetable station Main_Line Central_Station")
    print("  timetable --mode=station --branch=North_Line --station=North_Station test")
end

-- MASTER MODE FUNCTIONS
local master = {}

master.config = {
    branch_name = "",
    stations = {},
    broadcast_interval = 5
}

master.timetable_data = {
    arrivals = {},
    statistics = {},
    travel_times = {}  -- Track inter-station travel times
}

function master.loadConfig(branch_name)
    local branch_config_file = "master_config_" .. branch_name .. ".lua"
    if fs.exists(branch_config_file) then
        local file = fs.open(branch_config_file, "r")
        local data = file.readAll()
        file.close()
        master.config = textutils.unserialize(data) or master.config
    else
        print("Creating new config for branch: " .. branch_name)
        master.config.branch_name = branch_name
        
        print("Enter stations (comma-separated, in order):")
        local stations_input = read()
        master.config.stations = {}
        for station in stations_input:gmatch("[^,]+") do
            table.insert(master.config.stations, station:match("^%s*(.-)%s*$"))
        end
        
        master.saveConfig(branch_name)
    end
end

function master.saveConfig(branch_name)
    local branch_config_file = "master_config_" .. branch_name .. ".lua"
    local file = fs.open(branch_config_file, "w")
    file.write(textutils.serialize(master.config))
    file.close()
end

function master.loadData(branch_name)
    local branch_data_file = "timetable_data_" .. branch_name .. ".lua"
    if fs.exists(branch_data_file) then
        local file = fs.open(branch_data_file, "r")
        local data = file.readAll()
        file.close()
        master.timetable_data = textutils.unserialize(data) or master.timetable_data
    end
end

function master.saveData(branch_name)
    local branch_data_file = "timetable_data_" .. branch_name .. ".lua"
    local file = fs.open(branch_data_file, "w")
    file.write(textutils.serialize(master.timetable_data))
    file.close()
end

function master.calculateStatistics()
    local stats = {}
    
    for station_id, arrivals in pairs(master.timetable_data.arrivals) do
        stats[station_id] = {
            total_arrivals = #arrivals,
            average_interval = 0,
            last_arrival = arrivals[#arrivals] or 0
        }
        
        if #arrivals > 1 then
            local total_time = 0
            for i = 2, #arrivals do
                total_time = total_time + (arrivals[i] - arrivals[i-1])
            end
            stats[station_id].average_interval = total_time / (#arrivals - 1)
        end
    end
    
    master.timetable_data.statistics = stats
    master.calculateTravelTimes()
end

function master.calculateTravelTimes()
    -- Calculate inter-station travel times from arrival sequences
    local travel_times = {}
    
    -- Create a timeline of all arrivals across all stations
    local timeline = {}
    for station, arrivals in pairs(master.timetable_data.arrivals) do
        for _, timestamp in ipairs(arrivals) do
            table.insert(timeline, {station = station, timestamp = timestamp})
        end
    end
    
    -- Sort by timestamp
    table.sort(timeline, function(a, b) return a.timestamp < b.timestamp end)
    
    -- Calculate travel times between consecutive arrivals
    for i = 1, #timeline - 1 do
        local from_station = timeline[i].station
        local to_station = timeline[i + 1].station
        local travel_time = timeline[i + 1].timestamp - timeline[i].timestamp
        
        -- Only record reasonable travel times (5-60 seconds)
        if travel_time >= 3 and travel_time <= 60 and from_station ~= to_station then
            local route_key = from_station .. "->" .. to_station
            
            if not travel_times[route_key] then
                travel_times[route_key] = {}
            end
            
            -- Keep only last 10 measurements per route
            local times = travel_times[route_key]
            if #times >= 10 then
                table.remove(times, 1)
            end
            table.insert(times, travel_time)
        end
    end
    
    master.timetable_data.travel_times = travel_times
end

function master.getAverageTravelTime(from_station, to_station)
    local route_key = from_station .. "->" .. to_station
    local times = master.timetable_data.travel_times[route_key]
    
    if times and #times > 0 then
        local sum = 0
        for _, time in ipairs(times) do
            sum = sum + time
        end
        return sum / #times
    end
    
    -- Fallback: try to estimate based on station sequence
    local from_idx, to_idx
    for i, station in ipairs(master.config.stations) do
        if station == from_station then from_idx = i end
        if station == to_station then to_idx = i end
    end
    
    if from_idx and to_idx then
        local distance = math.abs(to_idx - from_idx)
        return distance * 5.5  -- Estimate ~5.5 seconds per station hop
    end
    
    return 10  -- Default fallback
end

function master.predictNextArrivals()
    local predictions = {}
    local current_time = os.epoch("utc") / 1000
    
    -- Find the most recent arrival to determine train position
    local most_recent_station = nil
    local most_recent_time = 0
    
    for station, stats in pairs(master.timetable_data.statistics) do
        if stats.last_arrival > most_recent_time then
            most_recent_time = stats.last_arrival
            most_recent_station = station
        end
    end
    
    if not most_recent_station then
        -- No data yet, use old algorithm as fallback
        for i, station in ipairs(master.config.stations) do
            local stats = master.timetable_data.statistics[station]
            if stats and stats.average_interval > 0 then
                local next_arrival = stats.last_arrival + stats.average_interval
                while next_arrival < current_time do
                    next_arrival = next_arrival + stats.average_interval
                end
                predictions[station] = {
                    next_arrival = next_arrival,
                    confidence = math.min(stats.total_arrivals / 10, 1.0)
                }
            end
        end
        return predictions
    end
    
    -- We now use actual measured inter-station travel times
    
    -- Find current station index
    local current_station_idx = nil
    for i, station in ipairs(master.config.stations) do
        if station == most_recent_station then
            current_station_idx = i
            break
        end
    end
    
    if not current_station_idx then
        return predictions -- Station not found in config
    end
    
    -- Determine direction based on recent arrival pattern
    local is_forward = true -- Default to forward direction
    if #master.config.stations > 1 then
        -- Look at the two most recent arrivals to determine direction
        local second_most_recent_station = nil
        local second_most_recent_time = 0
        
        for station, stats in pairs(master.timetable_data.statistics) do
            if station ~= most_recent_station and stats.last_arrival > second_most_recent_time then
                second_most_recent_time = stats.last_arrival
                second_most_recent_station = station
            end
        end
        
        if second_most_recent_station then
            local second_idx = nil
            for i, station in ipairs(master.config.stations) do
                if station == second_most_recent_station then
                    second_idx = i
                    break
                end
            end
            
            if second_idx then
                -- If current index > previous index, moving forward
                -- If current index < previous index, moving backward
                -- Handle edge cases for turnaround points
                if current_station_idx == 1 then
                    is_forward = true -- At start, must be moving forward
                elseif current_station_idx == #master.config.stations then
                    is_forward = false -- At end, must be moving backward
                else
                    is_forward = current_station_idx > second_idx
                end
            end
        end
    end
    
    -- Calculate predictions for each station based on linear route
    for i, station in ipairs(master.config.stations) do
        local stats = master.timetable_data.statistics[station]
        if stats then
            local steps_away = 0
            
            if station == most_recent_station then
                -- Train just left this station, calculate full round trip
                if is_forward then
                    if current_station_idx == #master.config.stations then
                        -- At the end, return trip
                        steps_away = 2 * (#master.config.stations - current_station_idx)
                    else
                        -- Forward trip to end, then back to this station
                        steps_away = 2 * (#master.config.stations - current_station_idx) + 2 * (current_station_idx - 1)
                    end
                else
                    if current_station_idx == 1 then
                        -- At the start, return trip
                        steps_away = 2 * (current_station_idx - 1) + 2 * (#master.config.stations - 1)
                    else
                        -- Backward trip to start, then forward to this station
                        steps_away = 2 * (current_station_idx - 1) + 2 * (i - 1)
                    end
                end
            else
                if is_forward then
                    if i > current_station_idx then
                        -- Station ahead on forward journey
                        steps_away = i - current_station_idx
                    else
                        -- Station behind, need to go to end and return
                        steps_away = (#master.config.stations - current_station_idx) + (#master.config.stations - i)
                    end
                else
                    if i < current_station_idx then
                        -- Station ahead on backward journey
                        steps_away = current_station_idx - i
                    else
                        -- Station behind, need to go to start and return
                        steps_away = (current_station_idx - 1) + (i - 1)
                    end
                end
            end
            
            -- Calculate actual travel time based on route
            local total_travel_time = 0
            
            if station == most_recent_station then
                -- Round trip calculation - simplified for now
                total_travel_time = 360  -- Keep original logic for round trips
            else
                -- Direct route calculation
                if is_forward then
                    if i > current_station_idx then
                        -- Forward journey: calculate cumulative time
                        for step = current_station_idx, i - 1 do
                            if step < #master.config.stations then
                                local from = master.config.stations[step]
                                local to = master.config.stations[step + 1]
                                total_travel_time = total_travel_time + master.getAverageTravelTime(from, to)
                            end
                        end
                    else
                        -- Need to go to end and return
                        -- Forward to end
                        for step = current_station_idx, #master.config.stations - 1 do
                            local from = master.config.stations[step]
                            local to = master.config.stations[step + 1]
                            total_travel_time = total_travel_time + master.getAverageTravelTime(from, to)
                        end
                        -- Return journey
                        for step = #master.config.stations - 1, i, -1 do
                            local from = master.config.stations[step + 1]
                            local to = master.config.stations[step]
                            total_travel_time = total_travel_time + master.getAverageTravelTime(from, to)
                        end
                    end
                else
                    if i < current_station_idx then
                        -- Backward journey: calculate cumulative time
                        for step = current_station_idx - 1, i, -1 do
                            if step >= 1 then
                                local from = master.config.stations[step + 1]
                                local to = master.config.stations[step]
                                total_travel_time = total_travel_time + master.getAverageTravelTime(from, to)
                            end
                        end
                    else
                        -- Need to go to start and return
                        -- Backward to start
                        for step = current_station_idx - 1, 1, -1 do
                            local from = master.config.stations[step + 1]
                            local to = master.config.stations[step]
                            total_travel_time = total_travel_time + master.getAverageTravelTime(from, to)
                        end
                        -- Forward journey
                        for step = 1, i - 1 do
                            local from = master.config.stations[step]
                            local to = master.config.stations[step + 1]
                            total_travel_time = total_travel_time + master.getAverageTravelTime(from, to)
                        end
                    end
                end
            end
            
            local next_arrival = most_recent_time + total_travel_time
            local confidence = math.min(stats.total_arrivals / 10, 1.0) * 0.8 -- Slightly lower confidence for complex calculation
            
            predictions[station] = {
                next_arrival = next_arrival,
                confidence = confidence
            }
        end
    end
    
    return predictions
end

function master.broadcastTimetable()
    master.calculateStatistics()
    local predictions = master.predictNextArrivals()
    
    local message = {
        type = "timetable_update",
        branch = master.config.branch_name,
        stations = master.config.stations,
        statistics = master.timetable_data.statistics,
        predictions = predictions,
        timestamp = os.epoch("utc") / 1000
    }
    
    rednet.broadcast(message, PROTOCOL)
    print("Broadcasted timetable update")
end

function master.handleStationReport(message, sender_id, branch_name)
    if message.type == "train_arrival" and message.branch == branch_name then
        local station = message.station
        local timestamp = message.timestamp
        
        if not master.timetable_data.arrivals[station] then
            master.timetable_data.arrivals[station] = {}
        end
        
        local arrivals = master.timetable_data.arrivals[station]
        
        -- Always add new arrival, replacing oldest if at capacity
        if #arrivals >= 30 then
            -- Remove oldest arrival (first element)
            table.remove(arrivals, 1)
        end
        table.insert(arrivals, timestamp)
        
        print(string.format("Train arrival at %s (from computer %d)", station, sender_id))
        
        master.saveData(branch_name)
        master.broadcastTimetable()
    end
end

function master.printStatus()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("=== TIMETABLE MASTER ===")
    print("Branch: " .. master.config.branch_name)
    print("Stations: " .. table.concat(master.config.stations, ", "))
    print("")
    
    print("Statistics:")
    for station, stats in pairs(master.timetable_data.statistics) do
        print(string.format("  %s: %d arrivals, %.1fs avg interval", 
            station, stats.total_arrivals, stats.average_interval))
    end
    
    print("")
    print("Travel Times:")
    for route, times in pairs(master.timetable_data.travel_times or {}) do
        if #times > 0 then
            local sum = 0
            for _, time in ipairs(times) do
                sum = sum + time
            end
            local avg = sum / #times
            print(string.format("  %s: %.1fs avg (%d samples)", route, avg, #times))
        end
    end
    
    print("")
    print("Next predicted arrivals:")
    local predictions = master.predictNextArrivals()
    for station, pred in pairs(predictions) do
        local eta = pred.next_arrival - (os.epoch("utc") / 1000)
        if eta > 0 then
            print(string.format("  %s: %.1fs (%.0f%% confidence)", 
                station, eta, pred.confidence * 100))
        end
    end
    
    print("")
    print("Press 'q' to quit, 'r' to reset data, 'c' to reconfigure")
end

function master.run(options)
    local branch_name = options.branch
    if not branch_name then
        print("Error: Branch name required for master mode")
        print("Usage: timetable master <branch_name>")
        return
    end
    
    local branch_data_file = "timetable_data_" .. branch_name .. ".lua"
    local branch_config_file = "master_config_" .. branch_name .. ".lua"
    
    if options.reset then
        if fs.exists(branch_data_file) then
            fs.delete(branch_data_file)
            print("Timetable data reset for branch: " .. branch_name)
        end
        return
    end
    
    if options.reconfig then
        if fs.exists(branch_config_file) then
            fs.delete(branch_config_file)
            print("Configuration reset for branch: " .. branch_name)
        end
        return
    end
    
    local modem_side = findModem()
    if not modem_side then
        print("Error: No wireless modem found!")
        return
    end
    
    rednet.open(modem_side)
    print("Using modem on " .. modem_side .. " side")
    
    master.loadConfig(branch_name)
    master.loadData(branch_name)
    
    print("Master node starting for branch: " .. branch_name)
    
    local broadcast_timer = os.startTimer(master.config.broadcast_interval)
    
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "rednet_message" then
            master.handleStationReport(param2, param1, branch_name)
            
        elseif event == "timer" and param1 == broadcast_timer then
            master.broadcastTimetable()
            broadcast_timer = os.startTimer(master.config.broadcast_interval)
            
        elseif event == "char" then
            if param1 == "q" then
                break
            elseif param1 == "r" then
                master.timetable_data = {arrivals = {}, statistics = {}}
                master.saveData(branch_name)
                print("Data reset")
            elseif param1 == "c" then
                fs.delete(branch_config_file)
                master.loadConfig(branch_name)
                print("Reconfigured")
            end
        end
        
        master.printStatus()
    end
    
    rednet.close(modem_side)
    print("Master node stopped")
end

-- MONITOR MODE FUNCTIONS
local monitor_node = {}

monitor_node.timetable = {
    branch = "",
    stations = {},
    statistics = {},
    predictions = {},
    last_update = 0
}

function monitor_node.formatTime(seconds)
    if seconds < 60 then
        return string.format("%.0fs", seconds)
    elseif seconds < 3600 then
        return string.format("%.0fm %.0fs", math.floor(seconds / 60), seconds % 60)
    else
        return string.format("%.0fh %.0fm", math.floor(seconds / 3600), (seconds % 3600) / 60)
    end
end

function monitor_node.formatTimestamp(timestamp)
    local date = os.date("*t", timestamp)
    return string.format("%02d:%02d:%02d", date.hour, date.min, date.sec)
end

function monitor_node.drawTimetable(monitor, scale)
    monitor.setTextScale(scale)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
    
    local w, h = monitor.getSize()
    
    monitor.write("=== TIMETABLE ===")
    monitor.setCursorPos(1, 2)
    monitor.write("Branch: " .. monitor_node.timetable.branch)
    
    if monitor_node.timetable.last_update == 0 then
        monitor.setCursorPos(1, 4)
        monitor.setTextColor(colors.red)
        monitor.write("Waiting for data...")
        return
    end
    
    local current_time = os.epoch("utc") / 1000
    local age = current_time - monitor_node.timetable.last_update
    
    monitor.setCursorPos(1, 3)
    monitor.setTextColor(colors.gray)
    monitor.write("Updated: " .. monitor_node.formatTime(age) .. " ago")
    
    local line = 5
    
    monitor.setCursorPos(1, line)
    monitor.setTextColor(colors.yellow)
    monitor.write("NEXT ARRIVALS:")
    line = line + 2
    
    for _, station in ipairs(monitor_node.timetable.stations) do
        if line > h - 1 then break end
        
        monitor.setCursorPos(1, line)
        monitor.setTextColor(colors.white)
        monitor.write(station .. ":")
        
        local prediction = monitor_node.timetable.predictions[station]
        if prediction then
            local eta = prediction.next_arrival - current_time
            if eta > 0 then
                monitor.setTextColor(colors.green)
                monitor.write(" " .. monitor_node.formatTime(eta))
                
                if prediction.confidence < 0.5 then
                    monitor.setTextColor(colors.orange)
                    monitor.write(" (?)")
                elseif prediction.confidence < 0.8 then
                    monitor.setTextColor(colors.yellow)
                    monitor.write(" (~)")
                end
            else
                monitor.setTextColor(colors.red)
                monitor.write(" Overdue")
            end
        else
            monitor.setTextColor(colors.gray)
            monitor.write(" No data")
        end
        
        line = line + 1
    end
    
    if line < h - 5 then
        line = line + 1
        monitor.setCursorPos(1, line)
        monitor.setTextColor(colors.yellow)
        monitor.write("STATISTICS:")
        line = line + 2
        
        for _, station in ipairs(monitor_node.timetable.stations) do
            if line > h - 1 then break end
            
            local stats = monitor_node.timetable.statistics[station]
            if stats then
                monitor.setCursorPos(1, line)
                monitor.setTextColor(colors.white)
                monitor.write(station .. ":")
                monitor.setTextColor(colors.cyan)
                monitor.write(string.format(" %d trains, %s interval", 
                    stats.total_arrivals, monitor_node.formatTime(stats.average_interval)))
                line = line + 1
            end
        end
    end
    
    monitor.setCursorPos(1, h)
    monitor.setTextColor(colors.gray)
    monitor.write("Scale: " .. scale .. " | Press Ctrl+T to exit")
end

function monitor_node.handleTimetableUpdate(message, branch_name)
    if message.type == "timetable_update" and message.branch == branch_name then
        monitor_node.timetable.branch = message.branch or ""
        monitor_node.timetable.stations = message.stations or {}
        monitor_node.timetable.statistics = message.statistics or {}
        monitor_node.timetable.predictions = message.predictions or {}
        monitor_node.timetable.last_update = message.timestamp or 0
        
        print("Timetable updated from master")
        return true
    end
    return false
end

function monitor_node.run(options)
    local branch_name = options.branch
    if not branch_name then
        print("Error: Branch name required for monitor mode")
        print("Usage: timetable monitor <branch_name> [scale]")
        return
    end
    
    local scale = options.scale or 1
    
    local monitor = peripheral.find("monitor")
    if not monitor then
        print("Error: No monitor found!")
        return
    end
    
    local modem_side = findModem()
    if not modem_side then
        print("Error: No wireless modem found!")
        return
    end
    
    rednet.open(modem_side)
    print("Using modem on " .. modem_side .. " side")
    
    print("Monitor node starting for branch: " .. branch_name)
    print("Scale: " .. scale)
    print("Waiting for timetable data...")
    
    monitor_node.drawTimetable(monitor, scale)
    
    local update_timer = os.startTimer(1)
    
    while true do
        local event, param1, param2 = os.pullEvent()
        
        if event == "rednet_message" then
            if monitor_node.handleTimetableUpdate(param2, branch_name) then
                monitor_node.drawTimetable(monitor, scale)
            end
            
        elseif event == "timer" and param1 == update_timer then
            monitor_node.drawTimetable(monitor, scale)
            update_timer = os.startTimer(1)
            
        elseif event == "terminate" then
            break
        end
    end
    
    rednet.close(modem_side)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    print("Monitor node stopped")
end

-- STATION MODE FUNCTIONS
local station_node = {}

station_node.sides = {"top", "bottom", "left", "right", "front", "back"}
station_node.previous_signals = {}

function station_node.initializeSignals()
    for _, side in ipairs(station_node.sides) do
        station_node.previous_signals[side] = redstone.getInput(side)
    end
end

function station_node.checkRedstoneSignals(station_name, branch_name)
    for _, side in ipairs(station_node.sides) do
        local current_signal = redstone.getInput(side)
        local previous_signal = station_node.previous_signals[side]
        
        if current_signal and not previous_signal then
            local timestamp = os.epoch("utc") / 1000
            
            local message = {
                type = "train_arrival",
                branch = branch_name,
                station = station_name,
                timestamp = timestamp,
                side = side
            }
            
            rednet.broadcast(message, PROTOCOL)
            
            print(string.format("Train detected at %s/%s on %s side at %s", 
                branch_name, station_name, side, os.date("%H:%M:%S", timestamp)))
            
            sleep(0.5)
        end
        
        station_node.previous_signals[side] = current_signal
    end
end

function station_node.printStatus(station_name, branch_name)
    term.clear()
    term.setCursorPos(1, 1)
    
    print("=== STATION NODE ===")
    print("Branch: " .. branch_name)
    print("Station: " .. station_name)
    print("")
    print("Monitoring redstone signals on all sides")
    print("Current signal status:")
    
    for _, side in ipairs(station_node.sides) do
        local signal = redstone.getInput(side)
        local status = signal and "ON" or "OFF"
        local color = signal and colors.green or colors.red
        
        term.setTextColor(color)
        print("  " .. side .. ": " .. status)
        term.setTextColor(colors.white)
    end
    
    print("")
    print("Waiting for train arrivals...")
    print("Press 'q' to quit")
end

function station_node.testSignal(station_name, branch_name)
    print("Testing signal detection...")
    print("Please activate redstone on any side to test...")
    
    local test_start = os.epoch("utc") / 1000
    local timeout = 30
    
    while (os.epoch("utc") / 1000) - test_start < timeout do
        station_node.checkRedstoneSignals(station_name, branch_name)
        
        local event, char = os.pullEvent("char")
        if event == "char" and char == "q" then
            return
        end
        
        sleep(0.1)
    end
    
    print("Test timeout reached")
end

function station_node.run(options)
    local branch_name = options.branch
    local station_name = options.station
    
    if not branch_name then
        print("Error: Branch name required for station mode")
        print("Usage: timetable station <branch_name> <station_name>")
        return
    end
    
    if not station_name then
        print("Error: Station name required for station mode")
        print("Usage: timetable station <branch_name> <station_name>")
        return
    end
    
    local modem_side = findModem()
    if not modem_side then
        print("Error: No wireless modem found!")
        return
    end
    
    if options.test then
        rednet.open(modem_side)
        print("Using modem on " .. modem_side .. " side")
        station_node.initializeSignals()
        station_node.testSignal(station_name, branch_name)
        rednet.close(modem_side)
        return
    end
    
    rednet.open(modem_side)
    print("Using modem on " .. modem_side .. " side")
    station_node.initializeSignals()
    
    print("Station node starting for: " .. branch_name .. "/" .. station_name)
    print("Initialized redstone signals for station: " .. station_name)
    
    local status_timer = os.startTimer(1)
    
    while true do
        local event, param1 = os.pullEvent()
        
        if event == "redstone" then
            station_node.checkRedstoneSignals(station_name, branch_name)
            
        elseif event == "timer" and param1 == status_timer then
            station_node.printStatus(station_name, branch_name)
            status_timer = os.startTimer(1)
            
        elseif event == "char" and param1 == "q" then
            break
            
        elseif event == "terminate" then
            break
        end
        
        sleep(0.05)
    end
    
    rednet.close(modem_side)
    print("Station node stopped")
end

-- MAIN PROGRAM
local function main()
    local mode, options = parseArgs()
    
    if not mode or mode == "help" then
        showHelp()
        return
    end
    
    if not options.branch then
        print("Error: Branch name is required for all modes")
        print("Run 'timetable help' for usage information")
        return
    end
    
    if mode == "master" then
        master.run(options)
    elseif mode == "monitor" then
        monitor_node.run(options)
    elseif mode == "station" then
        station_node.run(options)
    else
        print("Error: Invalid mode '" .. mode .. "'")
        print("Run 'timetable help' for usage information")
    end
end

main()