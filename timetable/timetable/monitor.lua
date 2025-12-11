---@diagnostic disable: different-requires

package.path = package.path .. ";../?.lua"
local httplike = require("httplike.httplike")
local log = require("logging.logging")

local Monitor = {
    branchName = nil,
    scale = 1,
    interval = 5, -- seconds
    running = false,
}
Monitor.__index = Monitor

-- Create a new Monitor instance
---@param branchName string
function Monitor.new(branchName, scale, interval)
    local self = setmetatable({}, Monitor)
    self.branchName = branchName
    self.scale = scale or 1
    self.interval = interval or 5
    return self
end

function Monitor:run()
    self.running = true

    log.Printf("[INFO] starting polling loop for branch '%s'", self.branchName)

    while self.running do
        local url = string.format("timetable://master/%s/schedule", self.branchName)
        local resp, err = httplike.Request("GET", url)
        if not resp or err ~= nil then
            log.Printf("[ERROR] failed to fetch schedule: %v", err)

            self:print({})
            os.sleep(self.interval)
            goto continue
        end

        if resp.status ~= 200 then
            log.Printf("[ERROR] unexpected status %d, response: %v", resp.status, resp.body)

            self:print({})
            os.sleep(self.interval)
            goto continue
        end

        log.Printf("[DEBUG] received schedule for branch '%s':", self.branchName)
        for i, station in ipairs(resp.body.stations) do
            log.Printf("[DEBUG]   %d. %s - arrives in %s", i, station.name, humanizeMS(station.arrivesIn))
        end

        self:print(resp.body.stations)
        os.sleep(self.interval)
        ::continue::
    end

    log.Printf("[WARN] stopped monitor for branch '%s'", self.branchName)
end

function Monitor:stop()
    self.running = false
end

-- prints the schedule to the monitor
-- @param schedule table - the schedule to print in format:
-- Body:
-- {
--   { name = "B", arrivesIn = 10 },
--   { name = "C", arrivesIn = 20 },
--   { name = "A", arrivesIn = 40 },
-- }
function Monitor:print(schedule)
    local monitor = peripheral.find("monitor")
    if not monitor then
        log.Printf("[ERROR] no monitor found")
        return
    end
    monitor.setTextScale(self.scale)
    monitor.clear()

    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)

    local w, h = monitor.getSize()
    local HEADER_HEIGHT = 1
    local header = string.format("=== Branch: %s ===", self.branchName)
    monitor.setCursorPos(math.max(1, math.floor((w - #header) / 2 + 1)), 1)
    monitor.write(header)

    -- we reserve the first line for the header
    -- we reserve last 6 characters for the arrivesIn time
    -- with space, e.g. "59.5ms"
    local TIME_WIDTH = 6
    local NAME_WIDTH = w - TIME_WIDTH - 1

    for i, station in ipairs(schedule) do
        if i + 1 > h then
            break
        end

        monitor.setCursorPos(1, i + HEADER_HEIGHT)
        local name = station.name
        if #name > NAME_WIDTH then
            name = name:sub(1, NAME_WIDTH - 3) .. "..."
        end
        monitor.write(name)

        monitor.setCursorPos(NAME_WIDTH + 1, i + HEADER_HEIGHT)

        if station.arrivesIn < 0 then
            monitor.write("OVERDUE")
        else
            -- round up to seconds
            station.arrivesIn = math.ceil(station.arrivesIn / 1000) * 1000
            monitor.write(humanizeMS(station.arrivesIn))
        end
    end

    local FOOTER_HEIGHT = 1
    local footer = string.format("last updated: %s", os.date("%H:%M:%S"))
    monitor.setCursorPos(math.max(1, math.floor((w - #footer) / 2 + 1)), h - FOOTER_HEIGHT + 1)
    monitor.write(footer)
end

-- converts milliseconds to a human-readable format
-- @param ms number - milliseconds
-- @return string   - human-readable time, e.g. "1h 2m 3s 456ms"
function humanizeMS(ms)
    local seconds = math.floor(ms / 1000)
    local milliseconds = ms % 1000
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60

    local parts = {}
    if hours > 0 then
        table.insert(parts, string.format("%dh", hours))
    end
    if minutes > 0 then
        table.insert(parts, string.format("%dm", minutes))
    end
    if seconds > 0 then
        table.insert(parts, string.format("%ds", seconds))
    end
    if milliseconds > 0 then
        table.insert(parts, string.format("%dms", milliseconds))
    end

    return table.concat(parts, " ")
end

return Monitor
