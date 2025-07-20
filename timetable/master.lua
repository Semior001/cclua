local master = {
    stations = {},
    trainArrivals = {},
    routeSequence = {},  -- Track the sequence of station visits
    routePatterns = {},  -- Detected route patterns for timetable calculation
    branch = nil,
    updateInterval = 5,
    dbFile = nil,
    collectionComplete = false,
    maxArrivals = 10  -- Keep only the last 10 arrivals per station
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
        master.routeSequence = data.routeSequence or {}
        master.routePatterns = data.routePatterns or {}
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
        routeSequence = master.routeSequence,
        routePatterns = master.routePatterns,
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

-- Record train arrival with route sequence tracking
function master.recordArrival(stationName)
    local currentTime = os.epoch("local")

    if not master.trainArrivals[stationName] then
        master.trainArrivals[stationName] = {}
    end

    table.insert(master.trainArrivals[stationName], currentTime)
    
    -- Keep only the last maxArrivals entries
    local arrivals = master.trainArrivals[stationName]
    if #arrivals > master.maxArrivals then
        table.remove(arrivals, 1)  -- Remove the oldest entry
    end
    
    -- Track route sequence
    master.trackRouteSequence(stationName, currentTime)
    
    print("Recorded train arrival at " .. stationName .. " at " .. os.date("%X", currentTime / 1000))
end

-- Track the sequence of station visits to detect route patterns
function master.trackRouteSequence(stationName, timestamp)
    -- Add to route sequence
    table.insert(master.routeSequence, {
        station = stationName,
        time = timestamp
    })
    
    -- Keep only the last 50 route entries to detect patterns
    if #master.routeSequence > 50 then
        table.remove(master.routeSequence, 1)
    end
    
    -- Try to detect route patterns
    master.detectRoutePatterns()
end

-- Detect repeating route patterns from the sequence
function master.detectRoutePatterns()
    if #master.routeSequence < 6 then  -- Need at least 6 entries to detect patterns
        return
    end
    
    -- Look for repeating sequences of 3-8 stations
    for patternLength = 3, math.min(8, math.floor(#master.routeSequence / 2)) do
        local pattern = {}
        local patternTimes = {}
        
        -- Extract potential pattern from recent sequence
        for i = #master.routeSequence - patternLength + 1, #master.routeSequence do
            table.insert(pattern, master.routeSequence[i].station)
            table.insert(patternTimes, master.routeSequence[i].time)
        end
        
        -- Check if this pattern repeats in earlier sequence
        if master.isPatternRepeating(pattern, patternLength) then
            local patternKey = table.concat(pattern, "->")
            
            if not master.routePatterns[patternKey] then
                master.routePatterns[patternKey] = {
                    pattern = pattern,
                    completions = {},
                    avgDuration = 0
                }
                print("Detected new route pattern: " .. patternKey)
            end
            
            -- Record pattern completion time
            local duration = patternTimes[#patternTimes] - patternTimes[1]
            table.insert(master.routePatterns[patternKey].completions, {
                startTime = patternTimes[1],
                endTime = patternTimes[#patternTimes],
                duration = duration
            })
            
            -- Keep only last 10 completions per pattern
            local completions = master.routePatterns[patternKey].completions
            if #completions > 10 then
                table.remove(completions, 1)
            end
            
            -- Update average duration
            local totalDuration = 0
            for _, completion in ipairs(completions) do
                totalDuration = totalDuration + completion.duration
            end
            master.routePatterns[patternKey].avgDuration = totalDuration / #completions
            
            break  -- Found a pattern, no need to check longer ones
        end
    end
end

-- Check if a pattern is repeating in the route sequence
function master.isPatternRepeating(pattern, patternLength)
    local seqLen = #master.routeSequence
    if seqLen < patternLength * 2 then
        return false
    end
    
    -- Check if the pattern appears earlier in the sequence
    for startPos = seqLen - patternLength * 2, 1, -1 do
        local matches = 0
        for i = 1, patternLength do
            if startPos + i - 1 <= seqLen and 
               master.routeSequence[startPos + i - 1].station == pattern[i] then
                matches = matches + 1
            end
        end
        if matches == patternLength then
            return true
        end
    end
    
    return false
end

-- Calculate timetable based on collected data and route patterns
function master.calculateTimetable()
    local timetable = {}
    local currentTime = os.epoch("local")

    -- First, try to use route patterns for more accurate predictions
    local routeBasedPredictions = master.calculateRouteBasedTimetable(currentTime)
    
    -- Then fall back to station-based calculations for any missing stations
    for stationName, arrivals in pairs(master.trainArrivals) do
        if #arrivals > 0 then
            -- Use route-based prediction if available, otherwise calculate interval-based
            if routeBasedPredictions[stationName] then
                timetable[stationName] = routeBasedPredictions[stationName]
            else
                -- Fallback to original interval-based calculation
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
                    totalArrivals = #arrivals,
                    predictionMethod = "interval"
                }
            end
        end
    end

    return timetable
end

-- Calculate timetable using detected route patterns
function master.calculateRouteBasedTimetable(currentTime)
    local timetable = {}
    
    -- Find the most recent route pattern that's currently active
    local activePattern = master.findActiveRoutePattern(currentTime)
    
    if activePattern then
        local pattern = activePattern.pattern
        local avgDuration = activePattern.avgDuration
        local progressTime = currentTime - activePattern.startTime
        local progressRatio = progressTime / avgDuration
        
        -- Calculate predicted arrivals for each station in the pattern
        for i, stationName in ipairs(pattern.pattern) do
            local stationProgressRatio = (i - 1) / (#pattern.pattern - 1)
            local nextStationProgressRatio = i / (#pattern.pattern - 1)
            
            local nextArrival
            if stationProgressRatio <= progressRatio and progressRatio < nextStationProgressRatio then
                -- Train is between this station and the next
                local timeToNextStation = (nextStationProgressRatio - progressRatio) * avgDuration
                nextArrival = currentTime + timeToNextStation
            elseif progressRatio >= nextStationProgressRatio then
                -- Train has passed this station, predict next cycle
                local timeToNextCycle = avgDuration - progressTime
                local timeToStation = timeToNextCycle + (stationProgressRatio * avgDuration)
                nextArrival = currentTime + timeToStation
            else
                -- Train hasn't reached this station yet in current cycle
                local timeToStation = (stationProgressRatio - progressRatio) * avgDuration
                nextArrival = currentTime + timeToStation
            end
            
            -- Get last actual arrival for this station
            local lastArrival = master.trainArrivals[stationName] and 
                               master.trainArrivals[stationName][#master.trainArrivals[stationName]] or 0
            
            timetable[stationName] = {
                lastArrival = lastArrival,
                nextArrival = nextArrival,
                avgInterval = avgDuration,
                totalArrivals = master.trainArrivals[stationName] and #master.trainArrivals[stationName] or 0,
                predictionMethod = "route-pattern",
                activePattern = table.concat(pattern.pattern, "->")
            }
        end
    end
    
    return timetable
end

-- Find the currently active route pattern based on recent arrivals
function master.findActiveRoutePattern(currentTime)
    if #master.routeSequence == 0 then
        return nil
    end
    
    -- Look for patterns that have recent completions
    local bestPattern = nil
    local bestScore = 0
    
    for patternKey, patternData in pairs(master.routePatterns) do
        if #patternData.completions > 0 then
            local lastCompletion = patternData.completions[#patternData.completions]
            local timeSinceCompletion = currentTime - lastCompletion.endTime
            
            -- Check if we might be in the middle of this pattern
            if timeSinceCompletion < patternData.avgDuration * 1.5 then
                local score = (#patternData.completions * 1000) - timeSinceCompletion
                if score > bestScore then
                    bestScore = score
                    bestPattern = {
                        pattern = patternData,
                        startTime = lastCompletion.endTime,  -- Start of current cycle
                        patternKey = patternKey
                    }
                end
            end
        end
    end
    
    return bestPattern
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

return master
