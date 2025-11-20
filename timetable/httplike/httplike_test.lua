-- HTTP-like Library Test/Examples
-- Made with Claude Code

local httplike = require("httplike")

-- ==========================
-- Example 1: Simple Server
-- ==========================

local function simpleServer()
    print("Starting simple server...")
    print("Computer ID: " .. os.getComputerID())

    httplike.serve({
        handler = function(request)
            print(string.format("[%s] %s %s from #%d",
                os.date("%H:%M:%S"),
                request.method,
                request.path,
                request.senderId))

            return httplike.ok({
                message = "Hello from server!",
                timestamp = os.epoch("utc") / 1000
            })
        end
    })
end

-- ==========================
-- Example 2: Router Server
-- ==========================

local function routerServer()
    print("Starting router server...")
    print("Computer ID: " .. os.getComputerID())

    local router = httplike.Router()

    -- GET /
    router:get("/", function(request)
        return httplike.ok({
            message = "Welcome to the API",
            endpoints = { "/status", "/users", "/data" }
        })
    end)

    -- GET /status
    router:get("/status", function(request)
        return httplike.ok({
            status = "online",
            uptime = os.clock(),
            id = os.getComputerID()
        })
    end)

    -- GET /users/:id
    router:get("/users/(%d+)", function(request)
        local userId = request.params[1]

        return httplike.ok({
            id = tonumber(userId),
            name = "User " .. userId,
            query = request.query
        })
    end)

    -- POST /data
    router:post("/data", function(request)
        if not request.body then
            return httplike.badRequest("Body is required")
        end

        print("Received data: " .. textutils.serialize(request.body))

        return httplike.created({
            received = true,
            data = request.body
        })
    end)

    httplike.serve({
        handler = router:handler()
    })
end

-- ==========================
-- Example 3: Simple Client
-- ==========================

local function simpleClient(serverId)
    print("Making request to server #" .. serverId)

    local response, err = httplike.req(
        "GET",
        "rednet://" .. serverId .. "/status",
        {},
        nil,
        5
    )

    if not response then
        print("Error: " .. err)
        return
    end

    print("Status: " .. response.status)
    print("Body:")
    print(textutils.serialize(response.body, { compact = false }))
end

-- ==========================
-- Example 4: Client with Query Params
-- ==========================

local function clientWithQuery(serverId, userId)
    print("Fetching user #" .. userId .. " from server #" .. serverId)

    local response, err = httplike.req(
        "GET",
        "rednet://" .. serverId .. "/users/" .. userId .. "?format=json&detailed=true",
        {},
        nil,
        5
    )

    if not response then
        print("Error: " .. err)
        return
    end

    print("Status: " .. response.status)
    if response.status == 200 then
        print("User: " .. response.body.name)
        print("Query params received:")
        print(textutils.serialize(response.body.query, { compact = false }))
    else
        print("Error: " .. textutils.serialize(response.body))
    end
end

-- ==========================
-- Example 5: POST Request
-- ==========================

local function clientPost(serverId)
    print("Sending POST request to server #" .. serverId)

    local response, err = httplike.req(
        "POST",
        "rednet://" .. serverId .. "/data",
        { ["Content-Type"] = "application/json" },
        {
            station = "SpawnTown",
            branch = "ST-EF",
            timestamp = os.epoch("utc") / 1000
        },
        5
    )

    if not response then
        print("Error: " .. err)
        return
    end

    print("Status: " .. response.status)
    print("Response:")
    print(textutils.serialize(response.body, { compact = false }))
end

-- ==========================
-- Example 6: Timetable Master Server
-- ==========================

local function timetableMaster()
    print("Starting timetable master server...")
    print("Computer ID: " .. os.getComputerID())

    -- In-memory storage
    local branches = {
        ["ST-EF"] = {
            stations = { "SpawnTown", "Novozavodsk", "EndFortress" },
            schedule = {},
            lastArrival = nil
        }
    }

    local router = httplike.Router()

    -- GET /schedule/:branch
    router:get("/schedule/([%w%-]+)", function(request)
        local branch = request.params[1]

        if not branches[branch] then
            return httplike.notFound("Branch not found: " .. branch)
        end

        return httplike.ok({
            branch = branch,
            stations = branches[branch].stations,
            schedule = branches[branch].schedule,
            timestamp = os.epoch("utc") / 1000
        })
    end)

    -- POST /arrival
    router:post("/arrival", function(request)
        if not request.body or not request.body.station or not request.body.branch then
            return httplike.badRequest("Missing station or branch in body")
        end

        local station = request.body.station
        local branch = request.body.branch
        local timestamp = request.body.timestamp

        if not branches[branch] then
            return httplike.notFound("Branch not found: " .. branch)
        end

        print(string.format("[%s] Train arrived: %s at %s",
            os.date("%H:%M:%S"),
            station,
            branch))

        -- Update last arrival
        branches[branch].lastArrival = {
            station = station,
            timestamp = timestamp
        }

        -- Here you would calculate schedule updates
        -- For now just acknowledge
        return httplike.ok({ received = true })
    end)

    -- GET /branches
    router:get("/branches", function(request)
        local branchList = {}
        for name, _ in pairs(branches) do
            table.insert(branchList, name)
        end

        return httplike.ok({ branches = branchList })
    end)

    httplike.serve({
        handler = router:handler()
    })
end

-- ==========================
-- Example 7: Station Client
-- ==========================

local function stationClient(masterId, stationName, branch)
    print(string.format("Station: %s on branch: %s", stationName, branch))
    print("Master ID: " .. masterId)
    print("Reporting arrival...")

    local response, err = httplike.req(
        "POST",
        "rednet://" .. masterId .. "/arrival",
        {},
        {
            station = stationName,
            branch = branch,
            timestamp = os.epoch("utc") / 1000
        },
        5
    )

    if not response then
        print("Error: " .. err)
        return
    end

    if response.status == 200 then
        print("Arrival reported successfully!")
    else
        print("Error: " .. response.status)
        print(textutils.serialize(response.body))
    end
end

-- ==========================
-- Example 8: Monitor Client
-- ==========================

local function monitorClient(masterId, branch)
    print("Monitor for branch: " .. branch)
    print("Master ID: " .. masterId)
    print("Fetching schedule...")

    local response, err = httplike.req(
        "GET",
        "rednet://" .. masterId .. "/schedule/" .. branch,
        {},
        nil,
        5
    )

    if not response then
        print("Error: " .. err)
        return
    end

    if response.status == 200 then
        print("Schedule received:")
        print("Stations: " .. textutils.serialize(response.body.stations))
        print("Schedule: " .. textutils.serialize(response.body.schedule))
    else
        print("Error: " .. response.status)
        print(textutils.serialize(response.body))
    end
end

-- ==========================
-- Main
-- ==========================

local args = { ... }

if #args == 0 then
    print("HTTP-like Library Tests")
    print("")
    print("Usage:")
    print("  httplike_test.lua simple-server")
    print("  httplike_test.lua router-server")
    print("  httplike_test.lua client <serverId>")
    print("  httplike_test.lua query <serverId> <userId>")
    print("  httplike_test.lua post <serverId>")
    print("")
    print("Timetable Examples:")
    print("  httplike_test.lua tt-master")
    print("  httplike_test.lua tt-station <masterId> <station> <branch>")
    print("  httplike_test.lua tt-monitor <masterId> <branch>")
    return
end

local command = args[1]

if command == "simple-server" then
    simpleServer()
elseif command == "router-server" then
    routerServer()
elseif command == "client" then
    if not args[2] then
        print("Error: serverId required")
        return
    end
    simpleClient(tonumber(args[2]))
elseif command == "query" then
    if not args[2] or not args[3] then
        print("Error: serverId and userId required")
        return
    end
    clientWithQuery(tonumber(args[2]), args[3])
elseif command == "post" then
    if not args[2] then
        print("Error: serverId required")
        return
    end
    clientPost(tonumber(args[2]))
elseif command == "tt-master" then
    timetableMaster()
elseif command == "tt-station" then
    if not args[2] or not args[3] or not args[4] then
        print("Error: masterId, station, and branch required")
        return
    end
    stationClient(tonumber(args[2]), args[3], args[4])
elseif command == "tt-monitor" then
    if not args[2] or not args[3] then
        print("Error: masterId and branch required")
        return
    end
    monitorClient(tonumber(args[2]), args[3])
else
    print("Unknown command: " .. command)
end
