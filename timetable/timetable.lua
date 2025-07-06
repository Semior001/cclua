-- Train Timetable Network System
-- Multi-role program for managing train schedules across subway branches
-- Made with Claude Code (https://claude.ai/code)

local args = {...}

-- Configuration
local NETWORK_CHANNEL = 1001
local MASTER_CHANNEL = 1002
local REFRESH_INTERVAL = 5 -- seconds
local DATA_FILE = "timetable_data.json"

-- Program modes
local MODES = {
    MASTER = "master",
    STATION = "station", 
    MONITOR = "monitor"
}

-- Global state
local config = {
    mode = nil,
    branch = nil,
    station_name = nil,
    master_id = nil,
    computer_id = os.getComputerID()
}

-- Utility functions
local function showUsage()
    print("Train Timetable Network System")
    print("Usage: timetable --mode <mode> --branch <branch> [options]")
    print("")
    print("Modes:")
    print("  master   - Central data storage and coordination")
    print("  station  - Monitor train station for schedule data")
    print("  monitor  - Display timetable on monitors")
    print("")
    print("Options:")
    print("  --branch <name>     Subway branch name (required)")
    print("  --station <name>    Station name (for station mode)")
    print("  --master <id>       Master computer ID (for station/monitor modes)")
    print("  --help              Show this help")
    print("")
    print("Examples:")
    print("  timetable --mode master --branch main")
    print("  timetable --mode station --branch main --station Central --master 1")
    print("  timetable --mode monitor --branch main --master 1")
end

local function parseArgs()
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if arg == "--help" then
            showUsage()
            return false
        elseif arg == "--mode" then
            config.mode = args[i + 1]
            i = i + 2
        elseif arg == "--branch" then
            config.branch = args[i + 1]
            i = i + 2
        elseif arg == "--station" then
            config.station_name = args[i + 1]
            i = i + 2
        elseif arg == "--master" then
            config.master_id = tonumber(args[i + 1])
            i = i + 2
        else
            print("Unknown argument: " .. arg)
            showUsage()
            return false
        end
    end
    
    -- Validate required arguments
    if not config.mode or not config.branch then
        print("Error: --mode and --branch are required")
        showUsage()
        return false
    end
    
    if not MODES[string.upper(config.mode)] then
        print("Error: Invalid mode. Must be master, station, or monitor")
        showUsage()
        return false
    end
    
    if config.mode == "station" and not config.station_name then
        print("Error: --station is required for station mode")
        return false
    end
    
    if (config.mode == "station" or config.mode == "monitor") and not config.master_id then
        print("Error: --master is required for station and monitor modes")
        return false
    end
    
    return true
end

local function loadData()
    if fs.exists(DATA_FILE) then
        local file = fs.open(DATA_FILE, "r")
        local content = file.readAll()
        file.close()
        return textutils.unserializeJSON(content) or {}
    end
    return {}
end

local function saveData(data)
    local file = fs.open(DATA_FILE, "w")
    file.write(textutils.serializeJSON(data))
    file.close()
end

local function setupRednet()
    local modem = peripheral.find("modem")
    if not modem then
        print("Error: No modem found")
        return false
    end
    
    rednet.open(peripheral.getName(modem))
    return true
end

local function findTrainStation()
    local stations = {}
    for _, name in pairs(peripheral.getNames()) do
        local type = peripheral.getType(name)
        if type == "Create_TrainStation" then
            stations[#stations + 1] = peripheral.wrap(name)
        end
    end
    return stations[1] -- Return first station found
end

local function findMonitors()
    local monitors = {}
    for _, name in pairs(peripheral.getNames()) do
        local type = peripheral.getType(name)
        if type == "monitor" then
            monitors[#monitors + 1] = peripheral.wrap(name)
        end
    end
    return monitors
end

local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function getCurrentTime()
    return os.epoch("utc") / 1000
end

-- Network communication
local function sendToMaster(message_type, data)
    if config.master_id then
        rednet.send(config.master_id, {
            type = message_type,
            from = config.computer_id,
            branch = config.branch,
            station = config.station_name,
            data = data,
            timestamp = getCurrentTime()
        })
    end
end

local function broadcastToNetwork(message_type, data)
    rednet.broadcast({
        type = message_type,
        from = config.computer_id,
        branch = config.branch,
        data = data,
        timestamp = getCurrentTime()
    })
end

-- Master node functions
local function runMaster()
    print("Starting master node for branch: " .. config.branch)
    
    local data = loadData()
    if not data.branches then
        data.branches = {}
    end
    if not data.branches[config.branch] then
        data.branches[config.branch] = {
            stations = {},
            schedules = {},
            travel_times = {},
            trains = {}
        }
    end
    
    local function handleMessage(sender_id, message)
        if message.type == "schedule_update" then
            print("Received schedule from station " .. (message.station or "unknown"))
            
            local branch_data = data.branches[config.branch]
            if not branch_data.stations[message.station] then
                branch_data.stations[message.station] = {}
            end
            
            branch_data.stations[message.station].last_schedule = message.data
            branch_data.stations[message.station].last_update = message.timestamp
            
            -- Process schedule for travel time calculation
            if message.data and message.data.schedule then
                local train_name = message.data.name or "Unknown"
                if not branch_data.trains[train_name] then
                    branch_data.trains[train_name] = {
                        route = {},
                        travel_times = {},
                        last_seen = {}
                    }
                end
                
                -- Update train's last seen location
                branch_data.trains[train_name].last_seen = {
                    station = message.station,
                    time = message.timestamp
                }
                
                -- Calculate travel times if we have previous data
                local train_data = branch_data.trains[train_name]
                if train_data.last_seen.station and train_data.last_seen.time then
                    local travel_time = message.timestamp - train_data.last_seen.time
                    local route_key = train_data.last_seen.station .. "->" .. message.station
                    
                    if not branch_data.travel_times[route_key] then
                        branch_data.travel_times[route_key] = {}
                    end
                    
                    table.insert(branch_data.travel_times[route_key], travel_time)
                    
                    -- Keep only last 10 measurements for averaging
                    if #branch_data.travel_times[route_key] > 10 then
                        table.remove(branch_data.travel_times[route_key], 1)
                    end
                    
                    print("Travel time " .. route_key .. ": " .. formatTime(travel_time))
                end
            end
            
            saveData(data)
            
            -- Broadcast update to monitors
            broadcastToNetwork("timetable_update", {
                branch = config.branch,
                stations = branch_data.stations,
                travel_times = branch_data.travel_times,
                trains = branch_data.trains
            })
            
        elseif message.type == "request_data" then
            print("Data request from computer " .. sender_id)
            rednet.send(sender_id, {
                type = "timetable_data",
                data = data.branches[config.branch]
            })
        end
    end
    
    -- Main loop
    while true do
        local sender_id, message = rednet.receive(1)
        if sender_id and message and message.branch == config.branch then
            handleMessage(sender_id, message)
        end
        
        -- Periodic cleanup and maintenance
        os.sleep(1)
    end
end

-- Station listener functions
local function runStation()
    print("Starting station listener for: " .. config.station_name)
    
    local station = findTrainStation()
    if not station then
        print("Error: No train station peripheral found")
        return
    end
    
    print("Found train station peripheral")
    
    local last_schedule = nil
    local last_train_name = nil
    
    -- Main loop
    while true do
        local success, schedule = pcall(function()
            return station.getSchedule()
        end)
        
        if success and schedule then
            local train_name = schedule.name or "Unknown"
            
            -- Check if schedule changed or train changed
            local schedule_changed = false
            if not last_schedule or 
               textutils.serialize(schedule) ~= textutils.serialize(last_schedule) or
               train_name ~= last_train_name then
                schedule_changed = true
            end
            
            if schedule_changed then
                print("Schedule update detected for train: " .. train_name)
                
                sendToMaster("schedule_update", {
                    name = train_name,
                    schedule = schedule,
                    station_data = station.getSignalStatus and station.getSignalStatus() or {}
                })
                
                last_schedule = schedule
                last_train_name = train_name
            end
        end
        
        os.sleep(REFRESH_INTERVAL)
    end
end

-- Monitor display functions
local function runMonitor()
    print("Starting monitor display for branch: " .. config.branch)
    
    local monitors = findMonitors()
    if #monitors == 0 then
        print("Error: No monitor peripherals found")
        return
    end
    
    print("Found " .. #monitors .. " monitor(s)")
    
    -- Request initial data from master
    sendToMaster("request_data", {})
    
    local timetable_data = {}
    
    local function drawTimetable()
        for _, monitor in pairs(monitors) do
            monitor.clear()
            monitor.setCursorPos(1, 1)
            monitor.setTextScale(0.5)
            
            -- Header
            monitor.write("=== TRAIN TIMETABLE ===")
            monitor.setCursorPos(1, 2)
            monitor.write("Branch: " .. config.branch)
            monitor.setCursorPos(1, 3)
            monitor.write("Updated: " .. os.date("%H:%M:%S"))
            monitor.setCursorPos(1, 4)
            monitor.write("-------------------------")
            
            local line = 5
            
            if timetable_data.trains then
                for train_name, train_data in pairs(timetable_data.trains) do
                    if train_data.last_seen and train_data.last_seen.station then
                        monitor.setCursorPos(1, line)
                        monitor.write("Train: " .. train_name)
                        line = line + 1
                        
                        monitor.setCursorPos(1, line)
                        monitor.write("Location: " .. train_data.last_seen.station)
                        line = line + 1
                        
                        local time_ago = getCurrentTime() - train_data.last_seen.time
                        monitor.setCursorPos(1, line)
                        monitor.write("Last seen: " .. formatTime(time_ago) .. " ago")
                        line = line + 2
                    end
                end
            end
            
            if timetable_data.travel_times then
                monitor.setCursorPos(1, line)
                monitor.write("--- TRAVEL TIMES ---")
                line = line + 1
                
                for route, times in pairs(timetable_data.travel_times) do
                    if #times > 0 then
                        local avg_time = 0
                        for _, time in pairs(times) do
                            avg_time = avg_time + time
                        end
                        avg_time = avg_time / #times
                        
                        monitor.setCursorPos(1, line)
                        monitor.write(route .. ": " .. formatTime(avg_time))
                        line = line + 1
                    end
                end
            end
        end
    end
    
    local function handleMessage(sender_id, message)
        if message.type == "timetable_update" and message.data.branch == config.branch then
            timetable_data = message.data
            drawTimetable()
        elseif message.type == "timetable_data" then
            timetable_data = message.data
            drawTimetable()
        end
    end
    
    -- Main loop
    while true do
        local sender_id, message = rednet.receive(1)
        if sender_id and message then
            handleMessage(sender_id, message)
        end
        
        -- Periodic refresh
        drawTimetable()
        os.sleep(10)
    end
end

-- Main program
local function main()
    if not parseArgs() then
        return
    end
    
    if not setupRednet() then
        return
    end
    
    print("Starting timetable system...")
    print("Mode: " .. config.mode)
    print("Branch: " .. config.branch)
    print("Computer ID: " .. config.computer_id)
    
    if config.mode == MODES.MASTER then
        runMaster()
    elseif config.mode == MODES.STATION then
        runStation()
    elseif config.mode == MODES.MONITOR then
        runMonitor()
    else
        print("Error: Invalid mode")
        return
    end
end

main()