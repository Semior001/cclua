---@diagnostic disable: different-requires

package.path = package.path .. ";../?.lua"
local httplike = require("httplike.httplike")
local log = require("logging.logging")
local middleware = require("httplike.middleware")

-- ==========================
-- Branch
-- ==========================

local Branch = {
    edges = {
        -- [{ from = "A", to = "B" }] = {
        --     travels = {120, 130, 125, ...}, -- last N travel times in seconds
        -- }
    },
    stations = {
        -- "A", "B"
    },
    lastArrival = {
        -- station = "A",
        -- at = 1763581614,
    }
}
Branch.__index = Branch

-- records the arrival of the train to the specified station
-- registers station and edge if not exist
-- @param station string - station name
-- @param ts      number - unix timestamp of arrival, defaults to os.time()
function Branch:recordArrival(station, ts)
    if ts == nil then
        ts = os.time()
    end

    (function()
        if not self.stations[station] then
            log.Printf("[DEBUG] registered new station %s", station)
            table.insert(self.stations, station)
        end

        if not self.lastArrival then
            log.Printf("[DEBUG] first arrival at branch, not recording an edge %s", station)
            return
        end

        local key = { from = self.lastArrival.station, to = station }
        if not self.edges[key] then
            self.edges[key] = { travels = {} }
        end

        local travelTime = ts - self.lastArrival.timestamp
        table.insert(self.edges[key].travels, travelTime)
        log.Printf("[DEBUG] recorded travel time from %s to %s: %d seconds",
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

    local visited = {}

    local chain = {}
    local currentStation = self.lastArrival.station
    while currentStation do
        if visited[currentStation] then
            -- loop detected
            break
        end

        table.insert(chain, currentStation)
        visited[currentStation] = true
        currentStation = findNext(currentStation)
    end

    if #chain ~= #self.stations then
        -- didn't reach all stations, incomplete chain
        return nil
    end

    return chain
end

-- calculates the average travel time in seconds between two stations
-- @param from string - starting station name
-- @param to   string - destination station name
-- @return number - average travel time in seconds, or 0 if no data
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

-- calculates the estimated time of arrival in seconds from one station to another
-- @param ts   number - current unix timestamp
-- @param from string - starting station name
-- @param to   string - destination station name
-- @return number - eta in seconds, or nil if data not available
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
-- @return table<string, number> - map of station name to eta in seconds or nil if data not available
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

        local eta = self:eta(os.time(), self.lastArrival.station, station)
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
    branches = {
        -- ["A-B"] = Branch,
    },
    server = nil, -- httplike.Server
}
Master.__index = Master

-- Makes a new instance of Master.
function Master.new()
    local self = setmetatable({}, Master)

    local router = httplike.NewRouter()
    router:route("POST /([%w%-]+)/([%w%-]+)/arrival", self.arrivalHandler)
    router:route("GET /([%w%-]+)/schedule", self.scheduleHandler)

    self.server = httplike.NewServer({
        protocol = "timetable",
        hostname = "master",
        handler = middleware.Wrap(router:handler(),
            middleware.Logging("INFO")),
        timeout = 5, -- 5s
    })

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
        return httplike.response(400, "missing branch or station in URL")
    end

    local branchName = req.params[1]
    local station = req.params[2]
    local ts = req.query.ts or os.time()

    local branch = self.branches[branchName]
    if not self.branches[branchName] then
        branch = setmetatable({}, Branch)
        self.branches[branchName] = branch
    end

    branch:recordArrival(station, tonumber(ts))
    return httplike.response(200, { message = "arrival registered" })
end

-- GET /{branch}/schedule
-- Response: 200 OK
-- Body: { stations: = {
--   { name = "A", arrivesIn = 10 },
--   { name = "B", arrivesIn = 20 },
-- } }
function Master:scheduleHandler(req)
    if not req.params[1] then
        return httplike.response(400, "missing branch in URL")
    end

    local branchName = req.params[1]
    if not self.branches[branchName] then
        return httplike.response(404, "branch not found: " .. branchName)
    end

    local branch = self.branches[branchName]
    local etas = branch:etas()
    if not etas then
        return httplike.response(500, "insufficient data to calculate schedule")
    end

    local schedule = { stations = {} }
    for station, eta in pairs(etas) do
        table.insert(schedule.stations, {
            name = station,
            arrivesIn = eta,
        })
    end

    return httplike.response(200, schedule)
end

return Master
