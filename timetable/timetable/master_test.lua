---@diagnostic disable: different-requires

package.path = package.path .. ";../?.lua"
local testing = require("testing.testing")
local log = require("logging.logging")


testing.cc.init()

testing.mock.setGlobal("fs", {
    exists = function(name) return true end,
    open = function(name, mode)
        return {
            readAll = function()
                return [[
{
    [ "ST-EF" ] = {
    stations = { EndFortress = true, SpawnTown = true, Novozavodsk = true },
    edges = {
        [ "EndFortress->Novozavodsk" ] = { travels = { 247900 } },
        [ "SpawnTown->Novozavodsk"   ] = { travels = { 185100 } },
        [ "Novozavodsk->SpawnTown"   ] = { travels = { 185150 } },
        [ "Novozavodsk->EndFortress" ] = { travels = { 248100 } },
    },
    },
}
]]
            end,
            close = function() end,
        }
    end,
})
testing.mock.setGlobal("rednet", { isOpen = function() return true end })
testing.mock.setGlobal("peripheral", {
    getNames = function() return { "side" } end,
    getType = function(name) return "modem" end,
    wrap = function(name) return { isWireless = function() return true end } end,
})

testing.suite("Branch.etas()", function()
    testing.test("error - no direction available", function()
        local master = require("timetable.master").new("./testdata/data.luad")
        local req = { params = { "ST-EF" } }
        testing.assert.throws(function() master:handleSchedule(req) end,
            "can't determine direction of travel, insufficient arrival data")
    end)

    testing.test("ST-EF: arrived to EF", function()
        testing.mock.setGlobal("os", (function()
            -- extend os, adding function 'epoch'
            local originalOs = _G["os"]
            local mockOs = {}
            for k, v in pairs(originalOs) do
                mockOs[k] = v
            end
            mockOs.epoch = function() return 1765116358704 end
            return mockOs
        end)())

        local master = require("timetable.master").new("./testdata/data.luad")

        master.branches["ST-EF"].lastArrival = {
            { station = "EndFortress", timestamp = 1765116358704 },
            { station = "Novozavodsk", timestamp = 1765116110604 },
        }
        local req = { params = { "ST-EF" } }
        local resp = master:handleSchedule(req)
        testing.assert.equal(resp.status, 200)
        testing.assert.deepEqual(resp.body, {
            branch = "ST-EF",
            stations = {
                { name = "Novozavodsk", arrivesIn = 247900.0 },
                { name = "SpawnTown",   arrivesIn = 247900.0 + 185100.0 },
                { name = "EndFortress", arrivesIn = 247900.0 + 185100.0 + 248100.0 },
            }
        })
    end)

    testing.test("ST-EF: arrived to NZ from EF", function()
        testing.mock.setGlobal("os", (function()
            -- extend os, adding function 'epoch'
            local originalOs = _G["os"]
            local mockOs = {}
            for k, v in pairs(originalOs) do
                mockOs[k] = v
            end
            mockOs.epoch = function() return 1765116358704 end
            return mockOs
        end)())

        local master = require("timetable.master").new("./testdata/data.luad")

        master.branches["ST-EF"].lastArrival = {
            { station = "Novozavodsk", timestamp = 1765116358704 },
            { station = "EndFortress", timestamp = 1765116606604 },
        }
        local req = { params = { "ST-EF" } }
        local resp = master:handleSchedule(req)
        testing.assert.equal(resp.status, 200)
        testing.assert.deepEqual(resp.body, {
            branch = "ST-EF",
            stations = {
                { name = "SpawnTown",   arrivesIn = 185150.0 },
                { name = "Novozavodsk", arrivesIn = 185150.0 + 185100.0 },
                { name = "EndFortress", arrivesIn = 185150.0 + 185100.0 + 248100.0 },
            }
        })
    end)
end)

testing.run()
