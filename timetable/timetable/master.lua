local httplike = require("../httplike/httplike")

local master = {
    branches = {
        -- ["branch-name"] = {
        --     stations = {
        --         ["station-name"] = {
        --             arrivals = { timestamp1, timestamp2, ... } -- up to last 5 arrivals
        --         },
        --         ...
        --     }
        -- },
    }
}

function master.start()
    ---@diagnostic disable-next-line: undefined-field
    print("starting timetable master, listening on PC " .. os.getComputerID())

    local router = httplike.Router()
    router:post("/([%w%-]+)/([%w%-]+)/arrival", master.arrival)
    router:get("/([%w%-]+)/schedule", master.schedule)

    httplike.serve({
        handler = httplike.loggingMiddleware(router:handler()),
        timeout = 5, -- 5s
    })
end

-- POST /{branch}/{station}/arrival?ts=1763581614 - register arrival at unix timestamp
-- Response: 200 OK
function master.arrival(req)
    if req.params[1] == "" or req.params[2] == "" then
        return httplike.badRequest("missing branch or station in URL")
    end

    local branch = req.params[1]
    local station = req.params[2]
    local timestamp = req.query.ts or os.time()

    if not master.branches[branch] then
        master.branches[branch] = { stations = {} }
    end

    if not master.branches[branch].stations[station] then
        master.branches[branch].stations[station] = { arrivals = {} }
    end

    table.insert(master.branches[branch].stations[station].arrivals, timestamp)
end

-- GET /{branch}/schedule
-- Response: 200 OK
-- Body: { stations: [
--   { name = "A", arrivesIn = 10 },
--   { name = "B", arrivesIn = 20 },
-- ] }
function master.schedule(req)
    if not req.params[1] then
        return httplike.badRequest("missing branch in URL")
    end

    local branch = req.params[1]

    if not master.branches[branch] then
        return httplike.notFound("branch not found: " .. branch)
    end

    master.sort(branch)

    local estimates = {}
    local currentTime = os.time()

    for name, data in pairs(master.branches[branch].stations) do
        local arrivals = data.arrivals
        if #arrivals == 0 then
            goto continue
        end

        local lastArrival = arrivals[#arrivals]

        ::continue::
    end
end

function master.sort(branch)
    -- sort by last timestamp occurences
    local stations = master.branches[branch].stations
    local stationList = {}
    for name, data in pairs(stations) do
        table.insert(stationList, {
            name = name,
            lastArrival = data.arrivals[#data.arrivals] or 0
        })
    end

    table.sort(stationList, function(a, b)
        return a.lastArrival < b.lastArrival
    end)

    local sortedStations = {}
    for _, station in ipairs(stationList) do
        sortedStations[station.name] = stations[station.name]
    end

    master.branches[branch].stations = sortedStations
end

return master
