-- Metro Timetable System
-- Made with Claude Code

-- ==========================
-- Utility Functions
-- ==========================

local utils = {}

-- Find ender modem on any side
function utils.findEnderModem()
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "modem" and peripheral.call(side, "isWireless") then
            return side
        end
    end
    return nil
end

-- Find monitor on any side
function utils.findMonitor()
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "monitor" then
            return side
        end
    end
    return nil
end

-- Find all sides with redstone input
function utils.findRedstoneSides()
    local sides = {}
    for _, side in ipairs(redstone.getSides()) do
        table.insert(sides, side)
    end
    return sides
end

-- Check if any redstone input is active
function utils.checkRedstoneInput(sides)
    for _, side in ipairs(sides) do
        if redstone.getInput(side) then
            return true
        end
    end
    return false
end

-- Format time difference in human-readable format
function utils.formatTimeDiff(seconds)
    if seconds < 0 then
        return "arriving now"
    elseif seconds < 60 then
        return string.format("in %ds", math.floor(seconds))
    else
        local minutes = math.floor(seconds / 60)
        return string.format("in %dm", minutes)
    end
end

-- Format "ago" time
function utils.formatAgo(seconds)
    if seconds < 60 then
        return string.format("%ds ago", math.floor(seconds))
    else
        local minutes = math.floor(seconds / 60)
        return string.format("%dm ago", minutes)
    end
end

-- ==========================
-- Station Mode
-- ==========================

local StationMode = {}
StationMode.__index = StationMode

function StationMode.new(config)
    local self = setmetatable({}, StationMode)
    self.modemSide = utils.findEnderModem()
    self.stationName = config.stationName
    self.branch = config.branch
    self.redstoneSides = utils.findRedstoneSides()
    self.lastState = false
    self.protocol = config.protocol or "metro_timetable"

    if not self.modemSide then
        error("No ender modem found!")
    end

    if not self.stationName then
        error("Station name not configured!")
    end

    rednet.open(self.modemSide)
    print("Station mode initialized")
    print("Station: " .. self.stationName)
    print("Branch: " .. (self.branch or "unknown"))
    print("Modem on: " .. self.modemSide)
    print("Monitoring redstone on all sides")

    return self
end

function StationMode:run()
    print("Running station mode... Press Ctrl+T to stop")

    while true do
        local currentState = utils.checkRedstoneInput(self.redstoneSides)

        -- Detect rising edge (train arrival)
        if currentState and not self.lastState then
            print("Train detected! Sending to master...")
            local message = {
                type = "arrival",
                station = self.stationName,
                branch = self.branch,
                timestamp = os.epoch("utc") / 1000
            }
            rednet.broadcast(message, self.protocol)
            print("Sent arrival notification")
        end

        self.lastState = currentState
        sleep(0.1)
    end
end

-- ==========================
-- Master Mode
-- ==========================

local MasterMode = {}
MasterMode.__index = MasterMode

function MasterMode.new(config)
    local self = setmetatable({}, MasterMode)
    self.modemSide = utils.findEnderModem()
    self.protocol = config.protocol or "metro_timetable"
    self.branches = config.branches or {}
    self.lastArrival = {} -- [branch][station] = timestamp
    self.travelTimes = {} -- [branch][from_station] = {to_station = seconds}
    self.stationHistory = {} -- [branch] = {last_station, timestamp}

    if not self.modemSide then
        error("No ender modem found!")
    end

    rednet.open(self.modemSide)

    -- Initialize structures
    for branchName, branchData in pairs(self.branches) do
        self.lastArrival[branchName] = {}
        self.travelTimes[branchName] = {}
        self.stationHistory[branchName] = {station = nil, timestamp = 0}
    end

    print("Master mode initialized")
    print("Modem on: " .. self.modemSide)
    print("Configured branches: " .. self:countBranches())

    return self
end

function MasterMode:countBranches()
    local count = 0
    for _ in pairs(self.branches) do
        count = count + 1
    end
    return count
end

function MasterMode:handleArrival(message)
    local station = message.station
    local branch = message.branch
    local timestamp = message.timestamp

    if not branch or not self.branches[branch] then
        print("Warning: Unknown branch: " .. tostring(branch))
        return
    end

    print(string.format("Arrival: %s at %s", station, branch))

    -- Update last arrival time for this station
    self.lastArrival[branch][station] = timestamp

    -- Calculate travel time if we have a previous station
    local history = self.stationHistory[branch]
    if history.station and history.timestamp > 0 then
        local travelTime = timestamp - history.timestamp

        -- Initialize travel times for previous station if needed
        if not self.travelTimes[branch][history.station] then
            self.travelTimes[branch][history.station] = {}
        end

        -- Store travel time (use moving average for smoothing)
        local oldTime = self.travelTimes[branch][history.station][station] or travelTime
        self.travelTimes[branch][history.station][station] = (oldTime * 0.7 + travelTime * 0.3)

        print(string.format("  Travel time from %s: %.1fs", history.station, travelTime))
    end

    -- Update history
    self.stationHistory[branch] = {station = station, timestamp = timestamp}

    -- Broadcast updated schedule
    self:broadcastSchedule()
end

function MasterMode:calculateSchedule(branchName)
    local branchData = self.branches[branchName]
    if not branchData then
        return nil
    end

    local stations = branchData.stations
    local circular = branchData.circular or false
    local history = self.stationHistory[branchName]

    if not history.station then
        return nil -- No data yet
    end

    -- Find current station index
    local currentIdx = nil
    for i, stationName in ipairs(stations) do
        if stationName == history.station then
            currentIdx = i
            break
        end
    end

    if not currentIdx then
        return nil
    end

    local now = os.epoch("utc") / 1000
    local timeSinceLastArrival = now - history.timestamp
    local schedule = {}

    -- Calculate ETAs for all stations
    local accumulatedTime = -timeSinceLastArrival -- Start from time since last arrival

    for i = 1, #stations do
        local idx = ((currentIdx - 1 + i - 1) % #stations) + 1
        local stationName = stations[idx]

        if i == 1 then
            -- Current/last station
            schedule[stationName] = math.max(0, accumulatedTime)
        else
            -- Calculate based on travel time from previous station
            local prevIdx = ((currentIdx - 1 + i - 2) % #stations) + 1
            local prevStation = stations[prevIdx]

            local travelTime = 0
            if self.travelTimes[branchName][prevStation] and
               self.travelTimes[branchName][prevStation][stationName] then
                travelTime = self.travelTimes[branchName][prevStation][stationName]
            else
                -- Default estimate if no data
                travelTime = 120 -- 2 minutes default
            end

            accumulatedTime = accumulatedTime + travelTime
            schedule[stationName] = accumulatedTime
        end

        -- For non-circular lines, only show stations ahead
        if not circular and i > #stations - currentIdx + 1 then
            break
        end
    end

    return schedule
end

function MasterMode:broadcastSchedule()
    for branchName, _ in pairs(self.branches) do
        local schedule = self:calculateSchedule(branchName)

        if schedule then
            local message = {
                type = "schedule",
                branch = branchName,
                schedule = schedule,
                timestamp = os.epoch("utc") / 1000
            }

            rednet.broadcast(message, self.protocol)
        end
    end
end

function MasterMode:run()
    print("Running master mode... Press Ctrl+T to stop")
    print("Waiting for station arrivals...")

    while true do
        local senderId, message, protocol = rednet.receive(self.protocol, 1)

        if message and type(message) == "table" then
            if message.type == "arrival" then
                self:handleArrival(message)
            end
        end

        -- Periodic schedule broadcast (every 5 seconds)
        self:broadcastSchedule()
        sleep(5)
    end
end

-- ==========================
-- Monitor Mode
-- ==========================

local MonitorMode = {}
MonitorMode.__index = MonitorMode

function MonitorMode.new(config)
    local self = setmetatable({}, MonitorMode)
    self.modemSide = utils.findEnderModem()
    self.monitorSide = utils.findMonitor()
    self.branch = config.branch
    self.protocol = config.protocol or "metro_timetable"
    self.schedule = {}
    self.lastUpdate = 0
    self.stationOrder = config.stationOrder or {}

    if not self.modemSide then
        error("No ender modem found!")
    end

    if not self.monitorSide then
        error("No monitor found!")
    end

    rednet.open(self.modemSide)
    self.monitor = peripheral.wrap(self.monitorSide)
    self.monitor.setTextScale(1)

    print("Monitor mode initialized")
    print("Branch: " .. self.branch)
    print("Modem on: " .. self.modemSide)
    print("Monitor on: " .. self.monitorSide)

    return self
end

function MonitorMode:drawSchedule()
    local mon = self.monitor
    mon.clear()
    mon.setCursorPos(1, 1)

    local width, height = mon.getSize()

    -- Draw header
    local header = "=== Branch: " .. self.branch .. " ==="
    local headerX = math.floor((width - #header) / 2) + 1
    mon.setCursorPos(headerX, 1)
    mon.write(header)

    -- Draw stations
    local line = 3
    local now = os.epoch("utc") / 1000

    -- Sort stations by configured order
    local orderedStations = {}
    if #self.stationOrder > 0 then
        for _, stationName in ipairs(self.stationOrder) do
            if self.schedule[stationName] then
                table.insert(orderedStations, stationName)
            end
        end
    else
        -- If no order specified, use schedule keys
        for stationName, _ in pairs(self.schedule) do
            table.insert(orderedStations, stationName)
        end
        table.sort(orderedStations)
    end

    for _, stationName in ipairs(orderedStations) do
        local eta = self.schedule[stationName]
        if line <= height - 2 then
            mon.setCursorPos(1, line)
            local timeStr = utils.formatTimeDiff(eta)
            local stationLine = stationName .. ": " .. timeStr
            mon.write(stationLine)
            line = line + 1
        end
    end

    -- Draw last update time
    local updateStr = "updated: "
    if self.lastUpdate > 0 then
        updateStr = updateStr .. utils.formatAgo(now - self.lastUpdate)
    else
        updateStr = updateStr .. "never"
    end

    local updateX = math.floor((width - #updateStr) / 2) + 1
    mon.setCursorPos(updateX, height)
    mon.write(updateStr)
end

function MonitorMode:handleScheduleUpdate(message)
    if message.branch ~= self.branch then
        return
    end

    self.schedule = message.schedule
    self.lastUpdate = message.timestamp
    print("Schedule updated at " .. os.date("%H:%M:%S"))
end

function MonitorMode:run()
    print("Running monitor mode... Press Ctrl+T to stop")
    print("Waiting for schedule updates...")

    -- Initial draw
    self:drawSchedule()

    while true do
        local senderId, message, protocol = rednet.receive(self.protocol, 0.5)

        if message and type(message) == "table" then
            if message.type == "schedule" then
                self:handleScheduleUpdate(message)
                self:drawSchedule()
            end
        else
            -- Redraw to update "ago" time
            self:drawSchedule()
        end
    end
end

-- ==========================
-- Configuration Loading
-- ==========================

local function loadConfig()
    local configPath = "timetable_config.lua"

    if not fs.exists(configPath) then
        print("Error: Configuration file not found: " .. configPath)
        print("Please create " .. configPath .. " with your settings")
        return nil
    end

    local config = dofile(configPath)
    return config
end

-- ==========================
-- Main Entry Point
-- ==========================

local function main()
    print("Metro Timetable System")
    print("Made with Claude Code")
    print("")

    local config = loadConfig()
    if not config then
        return
    end

    local mode = config.mode

    if mode == "station" then
        local station = StationMode.new(config)
        station:run()
    elseif mode == "master" then
        local master = MasterMode.new(config)
        master:run()
    elseif mode == "monitor" then
        local monitor = MonitorMode.new(config)
        monitor:run()
    else
        print("Error: Unknown mode: " .. tostring(mode))
        print("Valid modes: station, master, monitor")
    end
end

-- Run the program
main()
