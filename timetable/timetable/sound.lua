---@diagnostic disable: different-requires

package.path = package.path .. ";../?.lua"
local httplike = require("httplike.httplike")
local log = require("logging.logging")
local dfpwm = require("cc.audio.dfpwm")

-- ==========================
-- Sound
-- ==========================
local Sound = {
    station = "",
    branch = "",
    file = "",
    interval = 5,  -- seconds
    running = false,
    within = 5000, -- milliseconds
}
Sound.__index = Sound

-- creates a new Sound instance
-- @param station   string - station name
-- @param branch string - branch name
function Sound.new(station, branch, file)
    local self = setmetatable({}, Sound)
    self.station = station
    self.branch = branch
    self.file = file
    self.interval = 5
    self.within = 5000
    return self
end

-- run starts the event loop for the station
function Sound:run()
    self.running = true
    log.Printf("[DEBUG] starting event loop")

    while self.running do
        if self:trainArrived() then
            log.Printf("[INFO] train arrives within 5 secs, playing sound")
            self:playSound()
        end
        os.sleep(self.interval)
    end
end

-- stop stops the station's event loop
function Sound:stop()
    self.running = false
end

function Sound:trainArrived()
    local url = string.format("timetable://master/%s/schedule", self.branchName)
    local resp, err = httplike.Request("GET", url)
    if not resp or err ~= nil then
        log.Printf("[ERROR] failed to fetch schedule: %v", err)
        return false
    end

    if resp.status ~= 200 then
        log.Printf("[ERROR] unexpected status %d, response: %v", resp.status, resp.body)
        return false
    end

    log.Printf("[DEBUG] received schedule for branch '%s':", self.branchName)
    for i, station in ipairs(resp.body.stations) do
        if station.name == self.station and station.arrivesIn <= self.within then
            return true
        end
    end
end

function Sound:playSound()
    local speaker = peripheral.find("speaker")
    if not speaker then
        log.Printf("[ERROR] no speaker found")
        return
    end

    local decoder = dfpwm.make_decoder()
    for chunk in io.lines(self.file, 16 * 1024) do
        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer, 3) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

return Sound
