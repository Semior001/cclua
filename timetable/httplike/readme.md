# httplike.lua - HTTP-like API for ComputerCraft

Clean HTTP-style client/server communication over rednet.

Made with Claude Code

## API

### Client

```lua
local httplike = require("httplike.httplike")

local response, err = httplike.req(method, url, headers, body, timeout)
```

**Parameters:**
- `method` (string): HTTP method - "GET", "POST", "PUT", "DELETE", "PATCH"
- `url` (string): URL in format `{protocol}://{host}{path}?{query}`
  - `host` can be a computer ID (number) or hostname (string)
- `headers` (table, optional): Request headers (default: `{}`)
- `body` (any, optional): Request body (default: `nil`)
- `timeout` (number, optional): Timeout in seconds (default: `5`)

**Returns:**
- Success: `response, nil`
  - `response.status` (number): HTTP status code
  - `response.body` (any): Response body
  - `response.headers` (table): Response headers
- Failure: `nil, error_message`

**URL Format:**
```
{protocol}://{host}{path}?{queryParams}

where:
  protocol = rednet protocol name
  host = computer ID (number) or hostname (string)
```

**Examples:**
```lua
-- Simple GET with computer ID
local response, err = httplike.req("GET", "myapp://42/status")

-- GET with hostname (resolved via rednet.lookup)
local response, err = httplike.req("GET", "myapp://master/status")

-- GET with query params
local response, err = httplike.req("GET", "myapp://42/users/123?format=json&detailed=true")

-- POST with body
local response, err = httplike.req(
    "POST",
    "myapp://42/data",
    {["Content-Type"] = "application/json"},
    {name = "Steve", age = 25},
    10  -- 10 second timeout
)

-- Cross-protocol example
local response, err = httplike.req("GET", "metro_timetable://master/schedule/ST-EF")
```

### Server

```lua
local httplike = require("httplike.httplike")

local server = httplike.serve({
    protocol = "myapp",           -- required: rednet protocol
    hostname = "master",           -- optional: register hostname via rednet.host()
    handler = function(request)
        -- Handle request
        return {
            status = 200,
            body = {...},
            headers = {}
        }
    end,
    timeout = 0  -- optional, 0 = wait forever
})

-- Later, stop the server gracefully
server:stop()
```

**Request Object:**
```lua
{
    id = "...",              -- Unique request ID
    senderId = 42,           -- Client computer ID
    method = "GET",          -- HTTP method
    path = "/users/123",     -- URL path
    query = {                -- Parsed query parameters
        format = "json",
        detailed = "true"
    },
    headers = {...},         -- Request headers
    body = {...}             -- Request body
}
```

**Response Object:**
```lua
{
    status = 200,      -- HTTP status code
    body = {...},      -- Response body (can be nil)
    headers = {}       -- Response headers
}
```

**Example:**
```lua
httplike.serve({
    handler = function(request)
        if request.path == "/status" then
            return {
                status = 200,
                body = {status = "online"},
                headers = {}
            }
        else
            return {
                status = 404,
                body = {error = "Not found"},
                headers = {}
            }
        end
    end
})
```

### Router

```lua
local httplike = require("httplike")

local router = httplike.Router()

-- Add routes
router:get(pattern, handler)
router:post(pattern, handler)
router:put(pattern, handler)
router:delete(pattern, handler)
router:patch(pattern, handler)

-- Serve with router
httplike.serve({
    handler = router:handler()
})
```

**Pattern Matching:**
- Exact match: `"/status"`
- Lua patterns: `"/users/(%d+)"` captures user ID
- Captures available in `request.params` array

**Example:**
```lua
local router = httplike.Router()

-- GET /
router:get("/", function(request)
    return httplike.ok({message = "Welcome"})
end)

-- GET /users/:id
router:get("/users/(%d+)", function(request)
    local userId = tonumber(request.params[1])

    return httplike.ok({
        id = userId,
        name = "User " .. userId
    })
end)

-- POST /data
router:post("/data", function(request)
    if not request.body then
        return httplike.badRequest("Body required")
    end

    return httplike.created({received = true})
end)

httplike.serve({
    handler = router:handler()
})
```

### Helper Functions

Response builders for common status codes:

```lua
-- 200 OK
httplike.ok(body, headers)

-- 201 Created
httplike.created(body, headers)

-- 204 No Content
httplike.noContent()

-- 400 Bad Request
httplike.badRequest(message, headers)

-- 404 Not Found
httplike.notFound(message, headers)

-- 405 Method Not Allowed
httplike.methodNotAllowed(message, headers)

-- 500 Internal Server Error
httplike.internalError(message, headers)
```

## Complete Examples

### Simple Server

```lua
local httplike = require("httplike")

httplike.serve({
    handler = function(request)
        print(request.method .. " " .. request.path)

        return httplike.ok({
            message = "Hello!",
            timestamp = os.epoch("utc")
        })
    end
})
```

### RESTful API Server

```lua
local httplike = require("httplike")
local router = httplike.Router()

local users = {}

-- List all users
router:get("/users", function(request)
    return httplike.ok(users)
end)

-- Get user by ID
router:get("/users/(%d+)", function(request)
    local userId = tonumber(request.params[1])

    if users[userId] then
        return httplike.ok(users[userId])
    else
        return httplike.notFound("User not found")
    end
end)

-- Create user
router:post("/users", function(request)
    if not request.body or not request.body.name then
        return httplike.badRequest("Name required")
    end

    local userId = #users + 1
    users[userId] = {
        id = userId,
        name = request.body.name
    }

    return httplike.created(users[userId])
end)

-- Delete user
router:delete("/users/(%d+)", function(request)
    local userId = tonumber(request.params[1])

    if users[userId] then
        users[userId] = nil
        return httplike.noContent()
    else
        return httplike.notFound("User not found")
    end
end)

httplike.serve({handler = router:handler()})
```

### Client Usage

```lua
local httplike = require("httplike")
local serverId = 42

-- Create user
local response, err = httplike.do(
    "POST",
    "rednet://" .. serverId .. "/users",
    {},
    {name = "Steve"}
)

if not response then
    print("Error: " .. err)
    return
end

if response.status == 201 then
    local userId = response.body.id
    print("Created user #" .. userId)

    -- Get user
    response, err = httplike.do(
        "GET",
        "rednet://" .. serverId .. "/users/" .. userId
    )

    if response and response.status == 200 then
        print("User: " .. response.body.name)
    end
end
```

## Timetable System Example

### Master Server

```lua
local httplike = require("httplike")
local router = httplike.Router()

local branches = {
    ["ST-EF"] = {
        stations = {"SpawnTown", "Novozavodsk", "EndFortress"},
        schedule = {}
    }
}

-- GET /schedule/:branch
router:get("/schedule/([%w%-]+)", function(request)
    local branch = request.params[1]

    if not branches[branch] then
        return httplike.notFound("Branch not found")
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
        return httplike.badRequest("Missing station or branch")
    end

    -- Update schedule calculations here

    return httplike.ok({received = true})
end)

httplike.serve({handler = router:handler()})
```

### Station Computer

```lua
local httplike = require("httplike")

local masterId = 42
local stationName = "SpawnTown"
local branch = "ST-EF"

-- When train arrives
local response, err = httplike.do(
    "POST",
    "rednet://" .. masterId .. "/arrival",
    {},
    {
        station = stationName,
        branch = branch,
        timestamp = os.epoch("utc") / 1000
    }
)

if response and response.status == 200 then
    print("Arrival reported!")
end
```

### Monitor Computer

```lua
local httplike = require("httplike")

local masterId = 42
local branch = "ST-EF"

while true do
    local response, err = httplike.do(
        "GET",
        "rednet://" .. masterId .. "/schedule/" .. branch
    )

    if response and response.status == 200 then
        -- Display response.body.schedule on monitor
        print("Stations: " .. textutils.serialize(response.body.stations))
    end

    sleep(5)
end
```

## URL Parsing

The library parses URLs in the following format:

```
rednet://{serverID}{path}?{queryParams}
```

**Components:**
- `serverID`: Computer ID (required)
- `path`: Request path, defaults to `/`
- `queryParams`: URL query string, parsed into `request.query` table

**Examples:**
```
rednet://42                          -> serverId=42, path="/", query={}
rednet://42/status                   -> serverId=42, path="/status", query={}
rednet://42/users/123                -> serverId=42, path="/users/123", query={}
rednet://42/search?q=test            -> serverId=42, path="/search", query={q="test"}
rednet://42/users?active=true&page=2 -> serverId=42, path="/users", query={active="true", page="2"}
```

## Status Codes

Common HTTP status codes:

- **200 OK**: Request succeeded
- **201 Created**: Resource created successfully
- **204 No Content**: Success with no response body
- **400 Bad Request**: Invalid request
- **404 Not Found**: Resource not found
- **405 Method Not Allowed**: HTTP method not supported
- **500 Internal Server Error**: Server error

## Error Handling

### Client Side

```lua
local response, err = httplike.do("GET", "rednet://42/status")

if not response then
    -- Network error or timeout
    print("Request failed: " .. err)
    return
end

if response.status >= 400 then
    -- HTTP error
    print("HTTP error: " .. response.status)
    if response.body and response.body.error then
        print(response.body.error)
    end
    return
end

-- Success
print("Success!")
```

### Server Side

The server automatically catches handler errors and returns 500. To return specific errors:

```lua
router:post("/data", function(request)
    if not request.body then
        return httplike.badRequest("Body is required")
    end

    if not request.body.name then
        return httplike.badRequest("Name field is required")
    end

    -- Process data...

    return httplike.ok({success = true})
end)
```

## Testing

See `httplike_test.lua` for complete working examples.

**Start a server:**
```bash
httplike_test.lua router-server
```

**Make requests (from another computer):**
```bash
httplike_test.lua client <serverId>
httplike_test.lua query <serverId> 123
httplike_test.lua post <serverId>
```

**Test timetable system:**
```bash
# Computer 1 - Master
httplike_test.lua tt-master

# Computer 2 - Station
httplike_test.lua tt-station <masterId> SpawnTown ST-EF

# Computer 3 - Monitor
httplike_test.lua tt-monitor <masterId> ST-EF
```

## Requirements

- ComputerCraft or CC: Tweaked
- Wireless modem (ender modem recommended for cross-dimensional communication)

## License

Made with Claude Code
Free to use and modify
