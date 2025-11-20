-- HTTP-like Library for ComputerCraft
-- Made with Claude Code
--
-- Provides HTTP-style client/server communication over rednet

local httplike = {}

local PROTOCOL = "httplike"

-- ==========================
-- Utility Functions
-- ==========================

-- Find wireless modem on any side
local function findModem()
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "modem" then
            local modem = peripheral.wrap(side)
            if modem.isWireless() then
                return side
            end
        end
    end
    return nil
end

-- Ensure modem is open
local function ensureModemOpen()
    local modemSide = findModem()
    if not modemSide then
        error("No wireless modem found")
    end

    if not rednet.isOpen(modemSide) then
        rednet.open(modemSide)
    end

    return modemSide
end

-- Generate unique request ID
local function generateRequestId()
    return tostring(os.epoch("utc")) .. "-" .. tostring(math.random(10000, 99999))
end

-- Parse query string into table
-- Example: "key1=value1&key2=value2" -> {key1="value1", key2="value2"}
local function parseQuery(queryString)
    if not queryString or queryString == "" then
        return {}
    end

    local query = {}
    for pair in string.gmatch(queryString, "[^&]+") do
        local key, value = string.match(pair, "([^=]+)=?(.*)")
        if key then
            query[key] = value ~= "" and value or true
        end
    end

    return query
end

-- Parse rednet:// URL
-- Format: rednet://{serverID}{path}?{query}
-- Example: rednet://42/schedule/ST-EF?format=json
local function parseUrl(url)
    if not url then
        error("URL is required")
    end

    -- Check scheme
    if not string.match(url, "^rednet://") then
        error("Invalid URL scheme, expected rednet://")
    end

    -- Remove scheme
    local rest = string.sub(url, 10) -- length of "rednet://" + 1

    -- Extract serverID
    local serverId, pathAndQuery = string.match(rest, "^(%d+)(.*)")
    if not serverId then
        error("Invalid URL format, expected rednet://{serverID}{path}")
    end

    serverId = tonumber(serverId)

    -- Split path and query
    local path, query
    if string.find(pathAndQuery, "?", 1, true) then
        path, query = string.match(pathAndQuery, "^([^?]*)%??(.*)")
    else
        path = pathAndQuery
        query = ""
    end

    -- Default path to "/"
    if not path or path == "" then
        path = "/"
    end

    return {
        serverId = serverId,
        path = path,
        query = parseQuery(query)
    }
end

-- ==========================
-- Client API
-- ==========================

-- Make an HTTP-like request
-- Usage: httplike.req(method, url, headers, body, timeout)
-- Returns: {status, body, headers} or nil, error
function httplike.req(method, url, headers, body, timeout)
    ensureModemOpen()

    -- Parse URL
    local parsed = parseUrl(url)

    -- Build request
    local request = {
        type = "http_request",
        id = generateRequestId(),
        method = method or "GET",
        path = parsed.path,
        query = parsed.query,
        headers = headers or {},
        body = body
    }

    -- Send request
    rednet.send(parsed.serverId, request, PROTOCOL)

    -- Wait for response with timeout
    timeout = timeout or 5
    local timerId = os.startTimer(timeout)

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "rednet_message" then
            local senderId = p1
            local message = p2
            local protocol = p3

            -- Check if this is our response
            if protocol == PROTOCOL and
                type(message) == "table" and
                message.type == "http_response" and
                message.requestId == request.id and
                senderId == parsed.serverId then
                os.cancelTimer(timerId)

                return {
                    status = message.status,
                    body = message.body,
                    headers = message.headers or {}
                }, nil
            end
        elseif event == "timer" and p1 == timerId then
            return nil, "request timeout"
        end
    end
end

-- ==========================
-- Server API
-- ==========================

-- Start HTTP-like server
-- Usage: httplike.serve({handler = function(request) ... end, timeout = 0})
function httplike.serve(config)
    if not config or not config.handler then
        error("handler is required")
    end

    ensureModemOpen()

    local handler = config.handler
    local timeout = config.timeout or 0

    while true do
        local senderId, message, protocol = rednet.receive(PROTOCOL, timeout)

        if senderId and message and type(message) == "table" and message.type == "http_request" then
            -- Build request object for handler
            local request = {
                id = message.id,
                senderId = senderId,
                method = message.method or "GET",
                path = message.path or "/",
                query = message.query or {},
                headers = message.headers or {},
                body = message.body
            }

            -- Call handler
            local success, result = pcall(handler, request)

            local response
            if success then
                if result then
                    response = {
                        type = "http_response",
                        requestId = message.id,
                        status = result.status or 200,
                        body = result.body,
                        headers = result.headers or {}
                    }
                else
                    -- Handler returned nil, send 204 No Content
                    response = {
                        type = "http_response",
                        requestId = message.id,
                        status = 204,
                        body = nil,
                        headers = {}
                    }
                end
            else
                -- Handler errored, send 500
                response = {
                    type = "http_response",
                    requestId = message.id,
                    status = 500,
                    body = { error = "Internal server error: " .. tostring(result) },
                    headers = {}
                }
            end

            -- Send response back
            rednet.send(senderId, response, PROTOCOL)
        end
    end
end

-- ==========================
-- Router
-- ==========================

local Router = {}
Router.__index = Router

function httplike.Router()
    local self = setmetatable({}, Router)
    self.routes = {}
    return self
end

-- Add a route
-- router:route(method, pattern, handler)
function Router:route(method, pattern, handler)
    if not self.routes[method] then
        self.routes[method] = {}
    end

    table.insert(self.routes[method], {
        pattern = pattern,
        handler = handler
    })

    return self
end

-- Convenience methods
function Router:get(pattern, handler)
    return self:route("GET", pattern, handler)
end

function Router:post(pattern, handler)
    return self:route("POST", pattern, handler)
end

function Router:put(pattern, handler)
    return self:route("PUT", pattern, handler)
end

function Router:delete(pattern, handler)
    return self:route("DELETE", pattern, handler)
end

function Router:patch(pattern, handler)
    return self:route("PATCH", pattern, handler)
end

-- Handle a request
function Router:handle(request)
    local routes = self.routes[request.method]

    if not routes then
        return {
            status = 405,
            body = { error = "Method not allowed: " .. request.method },
            headers = {}
        }
    end

    -- Try to match route patterns
    for _, route in ipairs(routes) do
        local matches = { string.match(request.path, "^" .. route.pattern .. "$") }

        if #matches > 0 or request.path == route.pattern then
            -- Add captures to request
            request.params = matches

            -- Call handler
            local success, result = pcall(route.handler, request)

            if success then
                return result
            else
                return {
                    status = 500,
                    body = { error = "Handler error: " .. tostring(result) },
                    headers = {}
                }
            end
        end
    end

    -- No route matched
    return {
        status = 404,
        body = { error = "Not found: " .. request.method .. " " .. request.path },
        headers = {}
    }
end

-- Convert router to handler function for httplike.serve()
function Router:handler()
    return function(request)
        return self:handle(request)
    end
end

-- ==========================
-- Helper Functions
-- ==========================

-- Response builders
function httplike.ok(body, headers)
    return {
        status = 200,
        body = body,
        headers = headers or {}
    }
end

function httplike.created(body, headers)
    return {
        status = 201,
        body = body,
        headers = headers or {}
    }
end

function httplike.noContent()
    return {
        status = 204,
        body = nil,
        headers = {}
    }
end

function httplike.badRequest(message, headers)
    return {
        status = 400,
        body = { error = message or "Bad request" },
        headers = headers or {}
    }
end

function httplike.notFound(message, headers)
    return {
        status = 404,
        body = { error = message or "Not found" },
        headers = headers or {}
    }
end

function httplike.methodNotAllowed(message, headers)
    return {
        status = 405,
        body = { error = message or "Method not allowed" },
        headers = headers or {}
    }
end

function httplike.internalError(message, headers)
    return {
        status = 500,
        body = { error = message or "Internal server error" },
        headers = headers or {}
    }
end

function httplike.loggingMiddleware(next)
    return function(req)
        resp = next(req)
        print(os.date("%H:%M:%S") .. " - " .. req.method .. " " .. req.path .. " -> " .. resp.status)
        return resp
    end
end

return httplike
