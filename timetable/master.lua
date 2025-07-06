local master = {
    stations = {},
    trainArrivals = {},
    branch = nil,
    updateInterval = 5,
    dbFile = nil,
    collectionComplete = false
}

-- Load database from JSON file
function master.loadDatabase()
    if not master.dbFile then
        return
    end

    if not fs.exists(master.dbFile) then
        return
    end

    local file = fs.open(master.dbFile, "r")
    if not file then
        return
    end

    local content = file.readAll()
    file.close()

    if content == "" then
        return
    end

    local data = textutils.unserializeJSON(content)
    if data then
        master.stations = data.stations or {}
        master.trainArrivals = data.trainArrivals or {}
        master.collectionComplete = data.collectionComplete or false
    end
end

-- Save database to JSON file
function master.saveDatabase()
    if not master.dbFile then
        return
    end

    local data = {
        stations = master.stations,
        trainArrivals = master.trainArrivals,
        collectionComplete = master.collectionComplete
    }

    local file = fs.open(master.dbFile, "w")
    if file then
        file.write(textutils.serializeJSON(data))
        file.close()
    end
end

-- Check if station already exists in database
function master.hasStation(stationName)
    for _, station in ipairs(master.stations) do
        if station.name == stationName then
            return true
        end
    end
    return false
end

-- Add station to database
function master.addStation(stationName)
    if not master.hasStation(stationName) then
        table.insert(master.stations, {
            name = stationName,
            firstSeen = os.epoch("local")
        })
        print("Added new station: " .. stationName)
    end
end

-- Record train arrival
function master.recordArrival(stationName)
    local currentTime = os.epoch("local")

    if not master.trainArrivals[stationName] then
        master.trainArrivals[stationName] = {}
    end

    table.insert(master.trainArrivals[stationName], currentTime)
    print("Recorded train arrival at " .. stationName .. " at " .. os.date("%X", currentTime / 1000))
end

-- Calculate timetable based on collected data
function master.calculateTimetable()
    local timetable = {}
    local currentTime = os.epoch("local")

    for stationName, arrivals in pairs(master.trainArrivals) do
        if #arrivals > 0 then
            -- Calculate average interval between trains
            local totalInterval = 0
            local intervalCount = 0

            for i = 2, #arrivals do
                totalInterval = totalInterval + (arrivals[i] - arrivals[i - 1])
                intervalCount = intervalCount + 1
            end

            local avgInterval = intervalCount > 0 and (totalInterval / intervalCount) or 300000 -- 5 minutes default

            -- Calculate next arrival time
            local lastArrival = arrivals[#arrivals]
            local nextArrival = lastArrival + avgInterval

            -- If next arrival is in the past, calculate the next one
            while nextArrival <= currentTime do
                nextArrival = nextArrival + avgInterval
            end

            timetable[stationName] = {
                lastArrival = lastArrival,
                nextArrival = nextArrival,
                avgInterval = avgInterval,
                totalArrivals = #arrivals
            }
        end
    end

    return timetable
end

-- Run - start the master node
-- Blocking call
-- @param branch - the branch name for this master node
-- @param updateInterval - how often to broadcast updates (in seconds)
function master.Run(branch, updateInterval)
    local network = require("network")

    master.branch = branch
    master.updateInterval = updateInterval or 5
    master.dbFile = "timetable_" .. branch .. ".json"

    -- Load existing database
    master.loadDatabase()

    network.Prepare("master", branch, "")

    print("Master node started for branch: " .. branch)
    print("Update interval: " .. master.updateInterval .. " seconds")
    print("Database file: " .. master.dbFile)

    if master.collectionComplete then
        print("Database collection already complete, starting broadcast mode")
    else
        print("Collecting station data...")
    end

    -- Start collection phase or broadcast phase
    if not master.collectionComplete then
        -- Collection phase - gather station data
        repeat
            local msgType, stationName = network.AwaitMasterUpdate()

            if msgType == "train_arrived" then
                local wasKnown = master.hasStation(stationName)
                master.addStation(stationName)
                master.recordArrival(stationName)

                if wasKnown then
                    print("Station " .. stationName .. " already known - collection complete!")
                    master.collectionComplete = true
                end

                master.saveDatabase()
            end
        until master.collectionComplete
    end

    -- Broadcast phase - continuously update monitors
    print("Starting broadcast mode...")

    local function broadcastUpdate()
        local timetable = master.calculateTimetable()
        network.Broadcast(timetable)
        print("Broadcasted timetable update at " .. os.date("%X"))
    end

    -- Initial broadcast
    broadcastUpdate()

    -- Main loop for periodic updates and handling new arrivals
    local lastUpdate = os.epoch("local")
    local updateIntervalMs = master.updateInterval * 1000

    while true do
        -- Check for new messages with short timeout
        local _, message, _ = rednet.receive("timetable", 1)

        if message and message.type == "train_arrived" and message.branch == master.branch then
            master.recordArrival(message.station)
            master.saveDatabase()
            -- Immediate update when train arrives
            broadcastUpdate()
            lastUpdate = os.epoch("local")
        end

        -- Periodic update
        local currentTime = os.epoch("local")
        if currentTime - lastUpdate >= updateIntervalMs then
            broadcastUpdate()
            lastUpdate = currentTime
        end
    end
end
