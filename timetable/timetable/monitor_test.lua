---@diagnostic disable: different-requires

package.path = package.path .. ";../?.lua"
local testing = require("testing.testing")

-- Initialize ComputerCraft globals
testing.cc.init()

-- Save original os.date for mocking
local originalOsDate = os.date

-- Set up peripheral mock and load Monitor module
local mockMonitor = nil
testing.mock.setGlobal("peripheral", {
    find = function(type)
        if type == "monitor" then
            return mockMonitor
        end
        return nil
    end
})

local Monitor = require("timetable.monitor")

testing.suite("Monitor.print()", function()
    local monitor

    testing.beforeEach(function()
        -- Create mock monitor
        mockMonitor = testing.cc.mockMonitor({ width = 50, height = 20 })

        -- Mock os.date to return fixed time
        os.date = function(format)
            if format == "%H:%M:%S" then
                return "12:34:56"
            end
            return originalOsDate(format)
        end

        -- Create new Monitor instance
        monitor = Monitor.new("test-branch", 1, 5)
    end)

    testing.afterEach(function()
        -- Restore os.date
        os.date = originalOsDate
    end)

    testing.test("prints header with branch name", function()
        monitor:print({})

        local header = mockMonitor.findText("Branch: test%-branch")
        testing.assert.notNil(header, "header not found")
        testing.assert.equal(header.y, 1, "header should be on line 1")
    end)

    testing.test("prints station names and arrival times", function()
        local schedule = {
            { name = "Station-A", arrivesIn = 30000 },  -- 30 seconds
            { name = "Station-B", arrivesIn = 120000 }, -- 2 minutes
        }

        monitor:print(schedule)

        local stationA = mockMonitor.findText("Station%-A")
        testing.assert.notNil(stationA, "Station-A not found")
        testing.assert.equal(stationA.y, 2, "first station should be on line 2")

        local stationB = mockMonitor.findText("Station%-B")
        testing.assert.notNil(stationB, "Station-B not found")
        testing.assert.equal(stationB.y, 3, "second station should be on line 3")
    end)

    testing.test("truncates long station names", function()
        -- Monitor width is 50, TIME_WIDTH is 6, so NAME_WIDTH is 43
        local longName = string.rep("A", 50) -- 50 characters, way too long

        local schedule = {
            { name = longName, arrivesIn = 1000 }
        }

        monitor:print(schedule)

        local truncated = mockMonitor.findText("^A+%.%.%.$")
        testing.assert.notNil(truncated, "truncated name not found")
        testing.assert.isTrue(#truncated.text <= 43, "name should be truncated to NAME_WIDTH")
    end)

    testing.test("formats arrival times correctly", function()
        local schedule = {
            { name = "A", arrivesIn = 1500 },       -- 1s 500ms -> rounds to 2s
            { name = "B", arrivesIn = 65000 },      -- 1m 5s
            { name = "C", arrivesIn = 3661000 },    -- 1h 1m 1s
        }

        monitor:print(schedule)

        -- Count time values (contain 's', 'm', or 'h' and start with digit)
        local timeCount = 0
        for _, write in ipairs(mockMonitor.getWrites()) do
            if write.text:match("^%d") and (write.text:match("s") or write.text:match("m") or write.text:match("h")) then
                timeCount = timeCount + 1
            end
        end

        testing.assert.equal(timeCount, 3, "should have 3 time values")
    end)

    testing.test("prints footer with timestamp", function()
        monitor:print({})

        local footer = mockMonitor.findText("last updated: 12:34:56")
        testing.assert.notNil(footer, "footer not found")
        testing.assert.equal(footer.y, mockMonitor._height, "footer should be on last line")
    end)

    testing.test("handles empty schedule", function()
        monitor:print({})

        testing.assert.notNil(mockMonitor.findText("Branch:"), "header should be present")
        testing.assert.notNil(mockMonitor.findText("last updated:"), "footer should be present")
    end)

    testing.test("respects monitor height limit", function()
        -- Create schedule with more items than monitor height
        local schedule = {}
        for i = 1, 25 do -- More than mockMonitor._height (20)
            table.insert(schedule, {
                name = "Station-" .. i,
                arrivesIn = i * 1000
            })
        end

        monitor:print(schedule)

        local stationCount = mockMonitor.countWrites("^Station%-")

        -- Should be limited by monitor height minus header and footer
        testing.assert.isTrue(stationCount <= mockMonitor._height - 2,
            "should not exceed monitor height")
    end)

    testing.test("sets monitor scale correctly", function()
        local customMonitor = Monitor.new("test", 2, 5)
        customMonitor:print({})

        testing.assert.equal(mockMonitor._textScale, 2, "should set custom scale")
    end)

    testing.test("handles missing monitor peripheral", function()
        -- Mock peripheral.find to return nil
        testing.mock.setGlobal("peripheral", {
            find = function() return nil end
        })

        -- Should not crash, just log error and return
        local success = pcall(function()
            monitor:print({})
        end)

        -- Should succeed (not crash) even without monitor
        testing.assert.isTrue(success, "should not crash when monitor is missing")
    end)
end)

testing.run()
