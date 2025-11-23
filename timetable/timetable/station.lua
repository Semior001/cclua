---@diagnostic disable: different-requires

package.path = package.path .. ";../?.lua"
local httplike = require("httplike.httplike")
local log = require("logging.logging")

-- ==========================
-- Station
-- ==========================
local Station = { name = "", branch = "", running = false }
Station.__index = Station

-- creates a new Station instance
-- @param name   string - station name
-- @param branch string - branch name
function Station.new(name, branch)
    local self = setmetatable({}, Station)
    self.name = name
    self.branch = branch
    return self
end

-- run starts the event loop for the station
function Station:run()
    while self.running do
        ---@diagnostic disable-next-line: undefined-field
        local event = os.pullEvent()
        if event ~= "redstone" then
            goto continue
        end

        self:signalArrival()
        ::continue::
    end
end

-- stop stops the station's event loop
function Station:stop()
    self.running = false
end

function Station:signalArrival()
    local url = string.format("timetable://master/%s/%s/arrival", self.branch, self.name)
    local resp, err = httplike.Request("POST", url)
    if err or resp == nil then
        log.Printf("[ERROR] failed to signal arrival to master: %s", err)
        return
    end

    if resp.status ~= 200 then
        log.Printf("[ERROR] master returned non-200 status: %d, body: %v",
            resp.status, resp)
        return
    end

    log.Printf("[INFO] successfully signaled arrival to master")
end

return Station
