-- testing.lua - Simple testing framework for ComputerCraft Lua
-- Made with Claude Code

local testing = {}

-- Test suite state
local currentSuite = nil
local stats = {
    total = 0,
    passed = 0,
    failed = 0,
    suites = {}
}

function serialize(o)
    if type(o) == "number" then
        return tostring(o)
    elseif type(o) == "string" then
        return string.format("%q", o) -- %q handles special characters
    elseif type(o) == "boolean" then
        return tostring(o)
    elseif type(o) == "table" then
        local parts = {}
        -- print by sorted keys to have consistent output
        local keys = {}
        for k in pairs(o) do table.insert(keys, k) end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local v = o[k]
            local key_str = type(k) == "string" and string.format("[%q]", k) or tostring(k)
            table.insert(parts, key_str .. " = " .. serialize(v))
        end

        return "{" .. table.concat(parts, ", ") .. "}"
    else
        error("cannot serialize a " .. type(o))
    end
end

-- Creates a new test suite
-- @param name string - name of the test suite
-- @param fn function - function containing test cases
function testing.suite(name, fn)
    currentSuite = {
        name = name,
        tests = {},
        beforeEach = nil,
        afterEach = nil
    }

    fn()

    table.insert(stats.suites, currentSuite)
    currentSuite = nil
end

-- Defines a test case within a suite
-- @param name string - name of the test
-- @param fn function - test function
function testing.test(name, fn)
    if not currentSuite then
        error("test() must be called within a suite()")
    end

    table.insert(currentSuite.tests, {
        name = name,
        fn = fn
    })
end

-- Defines a function to run before each test
-- @param fn function - setup function
function testing.beforeEach(fn)
    if not currentSuite then
        error("beforeEach() must be called within a suite()")
    end
    currentSuite.beforeEach = fn
end

-- Defines a function to run after each test
-- @param fn function - teardown function
function testing.afterEach(fn)
    if not currentSuite then
        error("afterEach() must be called within a suite()")
    end
    currentSuite.afterEach = fn
end

-- Assertion functions
testing.assert = {}

-- Asserts that a condition is true
-- @param condition boolean - condition to check
-- @param message string - optional error message
function testing.assert.isTrue(condition, message)
    if not condition then
        error(message or "expected true, got false")
    end
end

-- Asserts that a condition is false
-- @param condition boolean - condition to check
-- @param message string - optional error message
function testing.assert.isFalse(condition, message)
    if condition then
        error(message or "expected false, got true")
    end
end

-- Asserts that two values are equal
-- @param actual any - actual value
-- @param expected any - expected value
-- @param message string - optional error message
function testing.assert.equal(actual, expected, message)
    if actual ~= expected then
        error(message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
    end
end

-- Asserts that two values are not equal
-- @param actual any - actual value
-- @param expected any - expected value
-- @param message string - optional error message
function testing.assert.notEqual(actual, expected, message)
    if actual == expected then
        error(message or string.format("expected values to be different, both are %s", tostring(actual)))
    end
end

-- Asserts that a value is nil
-- @param value any - value to check
-- @param message string - optional error message
function testing.assert.isNil(value, message)
    if value ~= nil then
        error(message or string.format("expected nil, got %s", tostring(value)))
    end
end

-- Asserts that a value is not nil
-- @param value any - value to check
-- @param message string - optional error message
function testing.assert.notNil(value, message)
    if value == nil then
        error(message or "expected value to not be nil")
    end
end

-- Asserts that a function throws an error
-- @param fn function - function that should throw
-- @param message string - optional error message
function testing.assert.throws(fn, message)
    local success, err = pcall(fn)
    if success then
        error(message or "expected function to throw an error")
    end
end

-- Asserts that two tables are deeply equal
-- @param actual table - actual table
-- @param expected table - expected table
-- @param message string - optional error message
function testing.assert.deepEqual(actual, expected, message)
    local function deepCompare(t1, t2)
        if type(t1) ~= type(t2) then return false end
        if type(t1) ~= "table" then return t1 == t2 end

        for k, v in pairs(t1) do
            if not deepCompare(v, t2[k]) then
                return false
            end
        end

        for k, v in pairs(t2) do
            if not deepCompare(v, t1[k]) then
                return false
            end
        end

        return true
    end

    if not deepCompare(actual, expected) then
        error(message or string.format("tables are not equal:\n    expected: %s\n    actual:   %s",
            serialize(expected), serialize(actual)))
    end
end

-- Mocking utilities
testing.mock = {}

-- Sets a global variable (cleaner than accessing _G directly)
-- @param name string - name of the global variable
-- @param value any - value to set
-- @return any - previous value of the global
function testing.mock.setGlobal(name, value)
    local previous = _G[name]
    _G[name] = value
    return previous
end

-- Creates a mock function that tracks calls
-- @param returnValue any - optional value to return
-- @return function, table - mock function and call tracker
function testing.mock.fn(returnValue)
    local calls = {}

    local mockFn = function(...)
        local args = { ... }
        table.insert(calls, args)
        return returnValue
    end

    return mockFn, calls
end

-- Creates a spy that wraps an existing function
-- @param fn function - function to spy on
-- @return function, table - spy function and call tracker
function testing.mock.spy(fn)
    local calls = {}

    local spyFn = function(...)
        local args = { ... }
        table.insert(calls, args)
        return fn(...)
    end

    return spyFn, calls
end

-- Creates a mock object with methods
-- @param methods table - table of method names to mock values/functions
-- @return table - mock object
function testing.mock.object(methods)
    local mock = {}
    local callTrackers = {}

    for name, value in pairs(methods) do
        if type(value) == "function" then
            mock[name], callTrackers[name] = testing.mock.spy(value)
        else
            local mockFn, calls = testing.mock.fn(value)
            mock[name] = mockFn
            callTrackers[name] = calls
        end
    end

    mock._calls = callTrackers

    return mock
end

-- ==========================
-- ComputerCraft Mocks
-- ==========================

testing.cc = {}

-- ComputerCraft colors API
testing.cc.colors = {
    white = 1,
    orange = 2,
    magenta = 4,
    lightBlue = 8,
    yellow = 16,
    lime = 32,
    pink = 64,
    gray = 128,
    lightGray = 256,
    cyan = 512,
    purple = 1024,
    blue = 2048,
    brown = 4096,
    green = 8192,
    red = 16384,
    black = 32768,
}

-- Creates a mock ComputerCraft monitor peripheral
-- @param options table - optional configuration { width = 50, height = 20 }
-- @return table - mock monitor with methods and test helpers
function testing.cc.mockMonitor(options)
    options = options or {}

    local monitor = {
        -- Configuration
        _width = options.width or 50,
        _height = options.height or 20,

        -- State
        _textScale = 1,
        _textColor = testing.cc.colors.white,
        _backgroundColor = testing.cc.colors.black,
        _cursorX = 1,
        _cursorY = 1,
        _writes = {}, -- Track all write calls with position and text
    }

    -- ComputerCraft monitor API methods (use dot notation, not colon)
    monitor.setTextScale = function(scale)
        monitor._textScale = scale
    end

    monitor.clear = function()
        monitor._writes = {}
    end

    monitor.setTextColor = function(color)
        monitor._textColor = color
    end

    monitor.setBackgroundColor = function(color)
        monitor._backgroundColor = color
    end

    monitor.getSize = function()
        return monitor._width, monitor._height
    end

    monitor.setCursorPos = function(x, y)
        monitor._cursorX = x
        monitor._cursorY = y
    end

    monitor.write = function(text)
        table.insert(monitor._writes, {
            x = monitor._cursorX,
            y = monitor._cursorY,
            text = text,
            textColor = monitor._textColor,
            backgroundColor = monitor._backgroundColor,
        })
    end

    -- Test helper methods

    -- Sets the monitor size (for testing different screen sizes)
    monitor.setSize = function(width, height)
        monitor._width = width
        monitor._height = height
    end

    -- Gets all writes (for assertions)
    monitor.getWrites = function()
        return monitor._writes
    end

    -- Gets writes at a specific line
    monitor.getWritesAtLine = function(line)
        local result = {}
        for _, write in ipairs(monitor._writes) do
            if write.y == line then
                table.insert(result, write)
            end
        end
        return result
    end

    -- Gets all text written to the monitor as a string
    monitor.getOutput = function()
        local lines = {}
        for _, write in ipairs(monitor._writes) do
            if not lines[write.y] then
                lines[write.y] = {}
            end
            table.insert(lines[write.y], write.text)
        end

        local result = {}
        for lineNum = 1, monitor._height do
            if lines[lineNum] then
                table.insert(result, table.concat(lines[lineNum], ""))
            else
                table.insert(result, "")
            end
        end

        return table.concat(result, "\n")
    end

    -- Finds text in writes (returns first match)
    monitor.findText = function(pattern)
        for _, write in ipairs(monitor._writes) do
            if write.text:match(pattern) then
                return write
            end
        end
        return nil
    end

    -- Counts writes matching a pattern
    monitor.countWrites = function(pattern)
        local count = 0
        for _, write in ipairs(monitor._writes) do
            if write.text:match(pattern) then
                count = count + 1
            end
        end
        return count
    end

    return monitor
end

-- Initializes ComputerCraft globals (call once at the start of your tests)
-- This sets up colors API and textutils if not present
function testing.cc.init()
    if not _G.colors then
        _G.colors = testing.cc.colors
    end

    if not _G.textutils then
        _G.textutils = {
            serialize = function(o) return serialize(o) end,
            unserialize = function(s)
                local fn, err = load("return " .. s)
                if not fn then
                    return nil
                end
                return fn()
            end
        }
    end
end

-- Runs all registered test suites
-- @return boolean - true if all tests passed
function testing.run()
    stats = {
        total = 0,
        passed = 0,
        failed = 0,
        suites = stats.suites
    }

    print("\n========================================")
    print("Running tests...")
    print("========================================\n")

    for _, suite in ipairs(stats.suites) do
        print(string.format("Suite: %s", suite.name))

        for _, test in ipairs(suite.tests) do
            stats.total = stats.total + 1

            -- Run beforeEach if defined
            if suite.beforeEach then
                pcall(suite.beforeEach)
            end

            -- Run test
            local success, err = pcall(test.fn)

            -- Run afterEach if defined
            if suite.afterEach then
                pcall(suite.afterEach)
            end

            if success then
                stats.passed = stats.passed + 1
                print(string.format("  ✓ %s", test.name))
            else
                stats.failed = stats.failed + 1
                print(string.format("  ✗ %s", test.name))
                print(string.format("    Error: %s", err))
            end

            print()
        end

        print()
    end

    print("========================================")
    print(string.format("Results: %d passed, %d failed, %d total",
        stats.passed, stats.failed, stats.total))
    print("========================================\n")

    return stats.failed == 0
end

return testing
