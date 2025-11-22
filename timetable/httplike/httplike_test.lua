-- HTTP-like Library Test/Examples
-- Made with Claude Code
---@diagnostic disable: undefined-field

local httplike = require("httplike.httplike")

-- ==========================
-- Example 1: Simple Server
-- ==========================

local function simpleServer()
    print("Starting simple server...")
    print("Computer ID: " .. os.getComputerID())

    local server = httplike.NewServer({
        protocol = "myapp",
        handler = function(request)
            print(string.format("[%s] %s %s from #%d",
                os.date("%H:%M:%S"),
                request.method,
                request.path,
                request.senderId))

            return httplike.Response(200, {
                message = "Hello from server!",
                timestamp = os.epoch("utc") / 1000
            })
        end
    })

    server:run()
end

-- ==========================
-- Example 2: Router Server
-- ==========================

local function routerServer()
    print("Starting router server...")
    print("Computer ID: " .. os.getComputerID())

    local router = httplike.NewRouter()

    -- GET /
    router:route("GET /", function(request)
        return httplike.Response(200, {
            message = "Welcome to the API",
            endpoints = { "/status", "/users", "/data" }
        })
    end)

    -- GET /status
    router:route("GET /status", function(request)
        return httplike.Response(200, {
            status = "online",
            uptime = os.clock(),
            id = os.getComputerID()
        })
    end)

    -- GET /users/:id
    router:route("GET /users/(%d+)", function(request)
        local userId = request.params[1]

        return httplike.Response(200, {
            id = tonumber(userId),
            name = "User " .. userId,
            query = request.query
        })
    end)

    -- POST /data
    router:route("POST /data", function(request)
        if not request.body then
            return httplike.Response(400, { error = "Body is required" })
        end

        print("Received data: " .. textutils.serialize(request.body))

        return httplike.Response(201, {
            received = true,
            data = request.body
        })
    end)

    local server = httplike.NewServer({
        protocol = "myapp",
        handler = router:handler()
    })

    server:run()
end

-- ==========================
-- Example 3: Simple Client
-- ==========================

local function simpleClient(serverId)
    print("Making request to server #" .. serverId)

    local response, err = httplike.Request(
        "GET",
        "myapp://" .. serverId .. "/status",
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

    local response, err = httplike.Request(
        "GET",
        "myapp://" .. serverId .. "/users/" .. userId .. "?format=json&detailed=true",
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

    local response, err = httplike.Request(
        "POST",
        "myapp://" .. serverId .. "/data",
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

    local router = httplike.NewRouter()

    -- GET /schedule/:branch
    router:route("GET /schedule/([%w%-]+)", function(request)
        local branch = request.params[1]

        if not branches[branch] then
            return httplike.Response(404, { error = "Branch not found: " .. branch })
        end

        return httplike.Response(200, {
            branch = branch,
            stations = branches[branch].stations,
            schedule = branches[branch].schedule,
            timestamp = os.epoch("utc") / 1000
        })
    end)

    -- POST /arrival
    router:route("POST /arrival", function(request)
        if not request.body or not request.body.station or not request.body.branch then
            return httplike.Response(400, { error = "Missing station or branch in body" })
        end

        local station = request.body.station
        local branch = request.body.branch
        local timestamp = request.body.timestamp

        if not branches[branch] then
            return httplike.Response(404, { error = "Branch not found: " .. branch })
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
        return httplike.Response(200, { received = true })
    end)

    -- GET /branches
    router:route("GET /branches", function(request)
        local branchList = {}
        for name, _ in pairs(branches) do
            table.insert(branchList, name)
        end

        return httplike.Response(200, { branches = branchList })
    end)

    local server = httplike.NewServer({
        protocol = "metro_timetable",
        handler = router:handler()
    })

    server:run()
end

-- ==========================
-- Example 7: Station Client
-- ==========================

local function stationClient(masterId, stationName, branch)
    print(string.format("Station: %s on branch: %s", stationName, branch))
    print("Master ID: " .. masterId)
    print("Reporting arrival...")

    local response, err = httplike.Request(
        "POST",
        "metro_timetable://" .. masterId .. "/arrival",
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

    local response, err = httplike.Request(
        "GET",
        "metro_timetable://" .. masterId .. "/schedule/" .. branch,
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
