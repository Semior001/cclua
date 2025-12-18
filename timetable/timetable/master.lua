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
    -- ["A->B"] = {
    --     travels = {120, 130, 125, ...}, -- last N travel times in ms
    -- }
    -- },
    -- stations = {
    -- "A", "B"
    -- },
    -- lastArrival = {
    --   -- contains up to MAX_ARRIVALS last arrivals,
    --   -- for evaluating the direction of movement
    --   { station = "A", timestamp = 1763581614000 }, -- last arrival
    --   { station = "B", timestamp = 1763581714000 }, -- the arrival before last
    -- },
}
Branch.__index = Branch

local MAX_TRAVELS = 10 -- maximum number of travel times to store per edge
local MAX_ARRIVALS = 2 -- maximum number of last arrivals to store

-- makes a unique key for an edge from 'from' to 'to'
-- @param from string - starting station name
-- @param to   string - destination station name
-- @return string - edge key
function Branch:edgeKey(from, to)
    return string.format("%s->%s", from, to)
end

-- parses an edge key into its from and to stations
-- @param key string - edge key
-- @return table - { from = string, to = string }
function Branch:parseEdgeKey(key)
    local from, to = string.match(key, "^(.-)->(.-)$")
    return { from = from, to = to }
end

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

        if not self.lastArrival[1] then
            log.Printf("[DEBUG] first arrival at branch, not recording an edge %s", station)
            return
        end

        if self.lastArrival[1].station == station then
            error("cannot record arrival to the same station twice in a row: " .. station)
        end

        local key = self:edgeKey(self.lastArrival[1].station, station)
        if not self.edges[key] then
            log.Printf("[DEBUG] registered new edge %s->%s", self.lastArrival[1].station, station)
            self.edges[key] = { travels = {} }
        end

        local travelTime = ts - self.lastArrival[1].timestamp
        table.insert(self.edges[key].travels, travelTime)

        if #self.edges[key].travels > MAX_TRAVELS then
            table.remove(self.edges[key].travels, 1)
        end

        log.Printf("[DEBUG] recorded travel time from %s to %s: %d ms",
            self.lastArrival[1].station, station, travelTime)
    end)()

    self.lastArrival[2] = self.lastArrival[1]
    self.lastArrival[1] = { station = station, timestamp = ts }
end

-- calculates the average travel time in ms **directly** between two stations
-- @param from string - starting station name
-- @param to   string - destination station name
-- @return number - average travel time in ms, or 0 if no data
function Branch:averageTravelTime(from, to)
    local key = self:edgeKey(from, to)
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

-- returns the total number of stations in the branch
-- @return number - total number of stations
function Branch:total()
    local count = 0
    for _, _ in pairs(self.stations) do
        count = count + 1
    end
    return count
end

-- returns the list of stations reachable from the given station
-- @param station string - station name
-- @return table - array of station names that can be reached from this station
function Branch:directions(station)
    local destinations = {}
    for key, _ in pairs(self.edges) do
        local edge = self:parseEdgeKey(key)
        if edge.from == station then
            table.insert(destinations, edge.to)
        end
    end
    return destinations
end

-- returns etas to all stations from the last arrival station
-- @return table<string, number> - map of station name to eta in ms or nil if data not available
function Branch:etas()
    -- first, we need to determine the direction of travel
    if not self.lastArrival[1] or not self.lastArrival[2] then
        error("can't determine direction of travel, insufficient arrival data")
    end

    local route = {}

    local curr = self.lastArrival[1].station
    local prev = self.lastArrival[2].station
    local visited = {}
    local nodes = 0

    local total = self:total()
    local edges = 0

    local MAX_EDGES = total * 2 -- safety
    while edges < MAX_EDGES do
        edges = edges + 1
        local next = nil

        -- find an unvisited non-prev
        local candidates = self:directions(curr)
        for _, candidate in ipairs(candidates) do
            if not visited[candidate] and candidate ~= prev then
                next = candidate
                break
            end
        end

        -- if not found - try any visited non-prev
        if not next then
            for _, candidate in ipairs(candidates) do
                if candidate ~= prev then
                    next = candidate
                    break
                end
            end
        end

        -- if dead end - go back to prev
        if not next and prev then
            next = prev
        end

        -- if still no next - we're done
        if not next then
            break
        end

        table.insert(route, { from = curr, to = next })

        if not visited[next] then
            nodes = nodes + 1
            visited[next] = nodes
        end

        prev, curr = curr, next
        if curr == self.lastArrival[1].station and nodes == total then
            break
        end
    end

    local etas = {}
    local cumulativeTime = 0

    for _, edge in ipairs(route) do
        local travelTime = self:averageTravelTime(edge.from, edge.to)
        if travelTime > 0 then
            cumulativeTime = cumulativeTime + travelTime
            if not etas[edge.to] then
                etas[edge.to] = cumulativeTime
            end
        end
    end

    return etas
end

-- ==========================
-- Master
-- ==========================

-- @class Master
-- @field branches table<string, Branch> - map of branch name to Branch instance
-- @field server   httplike.Server       - the HTTP-like server instance
local Master = {
    fileName = "",
    branches = {
        -- ["A-B"] = Branch,
    },
    server = nil, -- httplike.Server
    soundFile = nil,
}
Master.__index = Master

-- Makes a new instance of Master.
function Master.new(fileName, soundFile)
    local self = setmetatable({}, Master)

    local router = httplike.NewRouter()
    router:route("POST /([%w%-]+)/([%w%-]+)/arrival", function(req)
        return self:handleArrival(req)
    end)
    router:route("GET /([%w%-]+)/schedule", function(req)
        return self:handleSchedule(req)
    end)
    router:route("GET /config", function(req)
        return self:handleConfig(req)
    end)
    router:route("GET /([%w%-]+)/([%w%-]+)/soundfile", function(req)
        return self:handleSoundFile(req)
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

-- GET /{branch}/{station}/soundfile - get the sound file for the specified station
-- Response: 200 OK
-- Body:
-- { file = "..." } - sound file content as string
function Master:handleSoundFile(req)
    if req.params[1] == "" or req.params[2] == "" then
        return httplike.Response(400, "missing branch or station in URL")
    end

    if not self.soundFile then
        return httplike.Response(404, "no sound file configured on master")
    end

    -- TODO: per-station sound files in future
    local file = fs.open(self.soundFile, "r")
    if not file then
        return httplike.Response(500, "failed to open sound file on master")
    end

    local content = file.readAll()
    file.close()

    return httplike.Response(200, { file = content })
end

-- POST /{branch}/{station}/arrived?ts=1763581614 - register arrival at unix timestamp
-- Response: 200 OK
function Master:handleArrival(req)
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
        branch.lastArrival = {}
        self.branches[branchName] = branch
    end

    branch:recordArrival(station, tonumber(ts))
    self:save()

    return httplike.Response(200, { message = "arrival registered" })
end

-- GET /{branch}/schedule
-- calculate the schedule for the specified branch
-- from - optional starting station, defaults to last arrival station
-- Response: 200 OK
-- Body:
-- {
--   branch   = "A-Z",
--   from     = "A",
--   stations = {
--     { name = "B", arrivesIn = 10 },
--     { name = "C", arrivesIn = 20 },
--     { name = "A", arrivesIn = 40 },
--   }
-- }
function Master:handleSchedule(req)
    local branchName = req.params[1]
    if not req.params[1] then
        return httplike.Response(400, "missing branch in URL")
    end

    if not self.branches[branchName] then
        return httplike.Response(404, "branch not found: " .. branchName)
    end

    local branch = self.branches[branchName]
    local etas = branch:etas()

    local schedule = {
        branch = branchName,
        from = fromStation,
        stations = {}
    }

    local spent = os.epoch("utc") - branch.lastArrival[1].timestamp
    for station, eta in pairs(etas) do
        table.insert(schedule.stations, {
            name = station,
            arrivesIn = eta - spent,
        })
    end

    -- sort by arrivesIn
    table.sort(schedule.stations, function(a, b)
        return a.arrivesIn < b.arrivesIn
    end)

    return httplike.Response(200, schedule)
end

-- GET /config
-- Response: 200 OK
-- returns the current configuration of the master server
function Master:handleConfig(req)
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
    -- cleanup last arrived, as it may be stale
    for _, branch in pairs(self.branches) do
        branch.lastArrival = {}
    end
    log.Printf("[DEBUG] loaded master state from file: %s", self.fileName)
    return true
end

return Master
