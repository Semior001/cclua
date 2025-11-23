---@diagnostic disable: different-requires

package.path = package.path .. ";../?.lua"
local httplike = require("httplike.httplike")
local log = require("logging.logging")
local middleware = require("httplike.middleware")

-- ==========================
-- Branch
-- ==========================

local Branch = {
    -- edges = {
        -- [{ from = "A", to = "B" }] = { 
        --     travels = {120, 130, 125, ...}, -- last N travel times in ms
        -- }
    -- },
    -- stations = {
        -- "A", "B"
    -- },
    -- lastArrival = {
        -- station = "A",
        -- at = 1763581614,
    -- }
}
Branch.__index = Branch

local MAX_TRAVELS = 10 -- maximum number of travel times to store per edge

-- records the arrival of the train to the specified station
-- registers station and edge if not exist
-- @param station string - station name
-- @param ts      number - unix timestamp of arrival, defaults to os.epoch("utc")
function Branch:recordArrival(station, ts)
    if ts == nil then
        ts = os.epoch("utc")
    end

    (function()
        if not self.stations[station] then
            log.Printf("[DEBUG] registered new station %s", station)
            self.stations[station] = true
        end

        if not self.lastArrival then
            log.Printf("[DEBUG] first arrival at branch, not recording an edge %s", station)
            return
        end

        if self.lastArrival.station == station then
            error("cannot record arrival to the same station twice in a row: " .. station)
        end

        local key = { from = self.lastArrival.station, to = station }
        if not self.edges[key] then
            self.edges[key] = { travels = {} }
        end

        local travelTime = ts - self.lastArrival.timestamp
        table.insert(self.edges[key].travels, travelTime)

        if #self.edges[key].travels > MAX_TRAVELS then
            table.remove(self.edges[key].travels, 1)
        end

        log.Printf("[DEBUG] recorded travel time from %s to %s: %dms",
            self.lastArrival.station, station, travelTime)
    end)()

    self.lastArrival = { station = station, timestamp = ts }
end

-- builds a list of branches in their order of appearence, starting from the one
-- that the train has departed from, or nil and false, if the edges list is
-- incomplete
-- requires lastArrival to be set
-- @return table<string> - ordered list of station names or nil if incomplete
function Branch:chain()
    if not self.lastArrival then
        log.Printf("[DEBUG] can't build chain, lastArrival not set")
        return nil
    end

    local findNext = function(station)
        for key, _ in pairs(self.edges) do
            if key.from == station then
                return key.to
            end
        end
        return nil
    end

    local currentStation = self.lastArrival.station
    
    log.Printf("[DEBUG] adding station to chain: %s", currentStation)
    local chain = { currentStation }
    currentStation = findNext(currentStation)
    
    while currentStation do
        if currentStation == self.lastArrival.station then
            -- we made a loop
            break
        end
        
        log.Printf("[DEBUG] adding station to chain: %s", currentStation)
        if not chain[currentStation] then
            table.insert(chain, currentStation) 
        end
        currentStation = findNext(currentStation)
    end

    if #chain ~= #self.stations then
        -- didn't reach all stations, incomplete chain
        log.Printf("[DEBUG] incomplete chain, visited %v, expected %v",
            chain, self.stations)
        return nil
    end

    return chain
end

-- calculates the average travel time in ms between two stations
-- @param from string - starting station name
-- @param to   string - destination station name
-- @return number - average travel time in ms, or 0 if no data
function Branch:averageTravelTime(from, to)
    local key = { from = from, to = to }
    local edge = self.edges[key]
    if not edge then
        return 0
    end

    local total = 0
    for _, t in ipairs(edge.travels) do
        total = total + t
    end

    return total / #edge.travels
end

-- calculates the estimated time of arrival in ms from one station to another
-- @param ts   number - current unix timestamp
-- @param from string - starting station name
-- @param to   string - destination station name
-- @return number - eta in ms, or nil if data not available
function Branch:eta(ts, from, to)
    local chain = self:chain()
    if not chain then
        return nil
    end

    local eta = 0
    local recording = false
    for i = 1, #chain do
        local station = chain[i]

        if station == from then
            recording = true
            goto continue
        end

        if station == to then
            break
        end

        if not recording then
            goto continue
        end

        local prevStation = chain[i - 1]
        local travelTime = self:averageTravelTime(prevStation, station)

        if travelTime == 0 then
            return nil
        end
        eta = eta + travelTime

        ::continue::
    end

    local passed = ts - self.lastArrival.timestamp
    eta = eta - passed
    if eta < 0 then
        log.Printf("[WARN] train already passed station %s", to)
        eta = 0
    end

    return math.floor(eta + 0.5) -- round to nearest second
end

-- returns etas to all stations from the last arrival station
-- @return table<string, number> - map of station name to eta in ms or nil if data not available
function Branch:etas()
    local etas = {}
    local chain = self:chain()
    if not chain then
        return nil
    end

    for _, station in ipairs(chain) do
        if station == self.lastArrival.station then
            etas[station] = 0
            goto continue
        end

        local eta = self:eta(os.epoch("utc"), self.lastArrival.station, station)
        if not eta then
            return nil
        end
        etas[station] = eta

        ::continue::
    end

    return etas
end

-- ==========================
-- Master
-- ==========================

-- @class Master
-- @field branches table<string, Branch> - map of branch name to Branch instance
-- @field server   httplike.Server      - the HTTP-like server instance
local Master = {
    fileName = "",
    branches = {
        -- ["A-B"] = Branch,
    },
    server = nil, -- httplike.Server
}
Master.__index = Master

-- Makes a new instance of Master.
function Master.new(fileName)
    local self = setmetatable({}, Master)

    local router = httplike.NewRouter()
    router:route("POST /([%w%-]+)/([%w%-]+)/arrival", function(req) 
        return self:arrivalHandler(req) 
    end)
    router:route("GET /([%w%-]+)/schedule", function(req) 
        return self:scheduleHandler(req) 
    end)
    router:route("GET /config", function(req)
        return self:configHandler(req)
    end)

    self.fileName = fileName or "data.luad"
    self.branches = {}
    self.server = httplike.NewServer({
        protocol = "timetable",
        hostname = "master",
        handler = middleware.Wrap(router:handler(),
            middleware.Logging("INFO")),
        timeout = 5, -- 5s
    })

    self:load()

    return self
end

-- Start the server polling loop (blocks until stop() is called)
-- Registers hostname globally if provided, unregisters on exit
-- Use parallel.waitForAny() to run this alongside other functions
function Master:run()
    log.Printf("[INFO] starting master server...")
    self.server:run()
    log.Printf("[INFO] master server stopped")
end

-- Stops the server
function Master:stop()
    log.Printf("[INFO] stopping master server...")
    self.server:stop()
end

-- POST /{branch}/{station}/arrived?ts=1763581614 - register arrival at unix timestamp
-- Response: 200 OK
function Master:arrivalHandler(req)
    if req.params[1] == "" or req.params[2] == "" then
        return httplike.Response(400, "missing branch or station in URL")
    end

    local branchName = req.params[1]
    local station = req.params[2]
    local ts = req.query.ts or os.epoch("utc")

    log.Printf("[DEBUG] received request to register arrival at branch %s, station %s, ts %s",
        branchName, station, tostring(ts))

    local branch = self.branches[branchName]
    if not self.branches[branchName] then
        branch = setmetatable({}, Branch)
        branch.edges = {}
        branch.stations = {}
        branch.lastArrival = nil
        self.branches[branchName] = branch
    end

    branch:recordArrival(station, tonumber(ts))
    self:save()

    return httplike.Response(200, { message = "arrival registered" })
end

-- GET /{branch}/schedule
-- Response: 200 OK
-- Body: { stations: = {
--   { name = "A", arrivesIn = 10 },
--   { name = "B", arrivesIn = 20 },
-- } }
function Master:scheduleHandler(req)
    if not req.params[1] then
        return httplike.Response(400, "missing branch in URL")
    end

    local branchName = req.params[1]
    if not self.branches[branchName] then
        return httplike.Response(404, "branch not found: " .. branchName)
    end

    local branch = self.branches[branchName]
    local etas = branch:etas()
    if not etas then
        return httplike.Response(500, "insufficient data to calculate schedule")
    end

    local schedule = { stations = {} }
    for station, eta in pairs(etas) do
        table.insert(schedule.stations, {
            name = station,
            arrivesIn = eta,
        })
    end

    return httplike.Response(200, schedule)
end

-- GET /config
-- Response: 200 OK
-- returns the current configuration of the master server
function Master:configHandler(req)
    return httplike.Response(200, {
        branches = self.branches,
    })
end

-- Saves the current state to file
function Master:save()
    local file = fs.open(self.fileName, "w")
    if not file then
        log.Printf("[ERROR] failed to open file for saving: %s", self.fileName)
        return false
    end

    local data = textutils.serialize(self.branches)
    file.write(data)
    file.close()
    log.Printf("[DEBUG] saved master state to file: %s", self.fileName)
    return true
end

-- Loads the state from file
function Master:load()
    if not fs.exists(self.fileName) then
        log.Printf("[WARN] data file does not exist, starting fresh: %s", self.fileName)
        return false
    end

    local file = fs.open(self.fileName, "r")
    if not file then
        log.Printf("[ERROR] failed to open file for loading: %s", self.fileName)
        return false
    end

    local data = file.readAll()
    file.close()

    local loadedBranches = textutils.unserialize(data)
    if not loadedBranches then
        log.Printf("[ERROR] failed to unserialize data from file: %s", self.fileName)
        return false
    end

    self.branches = loadedBranches
    for branchName, branch in pairs(self.branches) do
        setmetatable(branch, Branch)
    end
    log.Printf("[DEBUG] loaded master state from file: %s", self.fileName)
    return true
end

return Master
