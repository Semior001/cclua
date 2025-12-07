# Testing Framework for ComputerCraft Lua

A simple, lightweight testing framework for ComputerCraft Lua programs with mocking utilities.

## Features

- Test suites and test cases
- Setup/teardown hooks (beforeEach/afterEach)
- Rich assertion library
- Mocking and spying utilities
- Clean test output with pass/fail reporting

## Installation

Simply require the testing module in your test files:

```lua
local testing = require("testing.testing")
```

## Basic Usage

### Creating Test Suites

```lua
local testing = require("testing.testing")

testing.suite("Math Operations", function()
    testing.test("addition works", function()
        testing.assert.equal(1 + 1, 2)
    end)

    testing.test("subtraction works", function()
        testing.assert.equal(5 - 3, 2)
    end)
end)

testing.run()
```

### Setup and Teardown

Use `beforeEach` and `afterEach` to run code before/after each test:

```lua
testing.suite("Database Tests", function()
    local db

    testing.beforeEach(function()
        db = Database.new()
    end)

    testing.afterEach(function()
        db:close()
    end)

    testing.test("can insert data", function()
        db:insert("key", "value")
        testing.assert.equal(db:get("key"), "value")
    end)
end)
```

## Assertions

### `testing.assert.isTrue(condition, message)`
Asserts that a condition is true.

```lua
testing.assert.isTrue(x > 0, "x must be positive")
```

### `testing.assert.isFalse(condition, message)`
Asserts that a condition is false.

```lua
testing.assert.isFalse(user.isDeleted)
```

### `testing.assert.equal(actual, expected, message)`
Asserts that two values are equal (using `==`).

```lua
testing.assert.equal(result, 42)
```

### `testing.assert.notEqual(actual, expected, message)`
Asserts that two values are not equal.

```lua
testing.assert.notEqual(newValue, oldValue)
```

### `testing.assert.isNil(value, message)`
Asserts that a value is nil.

```lua
testing.assert.isNil(user.email)
```

### `testing.assert.notNil(value, message)`
Asserts that a value is not nil.

```lua
testing.assert.notNil(result)
```

### `testing.assert.throws(fn, message)`
Asserts that a function throws an error.

```lua
testing.assert.throws(function()
    divide(10, 0)
end, "should throw on division by zero")
```

### `testing.assert.deepEqual(actual, expected, message)`
Asserts that two tables are deeply equal.

```lua
testing.assert.deepEqual(
    { a = 1, b = { c = 2 } },
    { a = 1, b = { c = 2 } }
)
```

## Mocking

### Mock Functions

Create a mock function that returns a fixed value and tracks calls:

```lua
local mockFn, calls = testing.mock.fn("return value")

-- Use the mock
local result = mockFn("arg1", "arg2")

-- Check calls
testing.assert.equal(#calls, 1)
testing.assert.deepEqual(calls[1], {"arg1", "arg2"})
```

### Spy Functions

Wrap an existing function to track calls while preserving behavior:

```lua
local function greet(name)
    return "Hello, " .. name
end

local spy, calls = testing.mock.spy(greet)

-- Use the spy
local result = spy("World")

-- Original behavior preserved
testing.assert.equal(result, "Hello, World")

-- Calls tracked
testing.assert.equal(#calls, 1)
testing.assert.deepEqual(calls[1], {"World"})
```

### Mock Objects

Create a mock object with tracked methods:

```lua
local mockDB = testing.mock.object({
    get = function(key) return "value" end,
    set = function(key, value) end
})

-- Use the mock
mockDB.set("key", "value")
local result = mockDB.get("key")

-- Check calls
testing.assert.equal(#mockDB._calls.set, 1)
testing.assert.equal(#mockDB._calls.get, 1)
```

## Complete Example

```lua
local testing = require("testing.testing")
local Branch = require("timetable.master")

testing.suite("Branch Edge Management", function()
    local branch

    testing.beforeEach(function()
        branch = setmetatable({
            edges = {},
            stations = {},
            lastArrival = {}
        }, Branch)
    end)

    testing.test("records first arrival", function()
        branch:recordArrival("A", 1000)

        testing.assert.equal(branch.lastArrival[1].station, "A")
        testing.assert.equal(branch.lastArrival[1].timestamp, 1000)
        testing.assert.isTrue(branch.stations["A"])
    end)

    testing.test("creates edge on second arrival", function()
        branch:recordArrival("A", 1000)
        branch:recordArrival("B", 2000)

        local key = branch:edgeKey("A", "B")
        testing.assert.notNil(branch.edges[key])
        testing.assert.equal(#branch.edges[key].travels, 1)
        testing.assert.equal(branch.edges[key].travels[1], 1000)
    end)

    testing.test("removes obsolete shortcut edge", function()
        -- Setup: Create shortcut A->C
        branch:recordArrival("A", 1000)
        branch:recordArrival("C", 3000)

        local shortcutKey = branch:edgeKey("A", "C")
        testing.assert.notNil(branch.edges[shortcutKey])

        -- Add intermediate station B
        branch:recordArrival("A", 4000)
        branch:recordArrival("B", 5000)
        branch:recordArrival("C", 6000)

        -- Shortcut should be removed
        testing.assert.isNil(branch.edges[shortcutKey])
    end)
end)

testing.run()
```

## Running Tests

Simply run your test file:

```bash
lua test_file.lua
```

Or in ComputerCraft:

```
test_file
```

The output will show:

```
========================================
Running tests...
========================================

Suite: Branch Edge Management
  ✓ records first arrival
  ✓ creates edge on second arrival
  ✓ removes obsolete shortcut edge

========================================
Results: 3 passed, 0 failed, 3 total
========================================
```

## ComputerCraft Testing

The framework provides built-in mocks for ComputerCraft APIs to make testing easier.

### Initialize ComputerCraft Globals

Call `testing.cc.init()` at the start of your test file to set up ComputerCraft globals like `colors` and `textutils`:

```lua
local testing = require("testing.testing")
testing.cc.init()  -- Sets up colors, textutils, etc.
```

### Mock Monitor Peripheral

Create a mock monitor with comprehensive testing methods:

```lua
local mockMonitor = testing.cc.mockMonitor({ width = 50, height = 20 })

-- ComputerCraft API methods work as expected
mockMonitor.setTextScale(2)
mockMonitor.clear()
mockMonitor.setCursorPos(1, 1)
mockMonitor.write("Hello")

-- Test helper methods
local writes = mockMonitor.getWrites()                    -- Get all writes
local line1 = mockMonitor.getWritesAtLine(1)             -- Get writes at line 1
local output = mockMonitor.getOutput()                    -- Get all text as string
local found = mockMonitor.findText("Hello")               -- Find text by pattern
local count = mockMonitor.countWrites("Station")          -- Count matching writes
mockMonitor.setSize(80, 25)                               -- Change monitor size
```

### Set Global Variables

Use `testing.mock.setGlobal()` instead of accessing `_G` directly:

```lua
-- Set up peripheral mock
testing.mock.setGlobal("peripheral", {
    find = function(type)
        if type == "monitor" then
            return mockMonitor
        end
        return nil
    end
})
```

### Complete ComputerCraft Example

```lua
local testing = require("testing.testing")

-- Initialize ComputerCraft globals
testing.cc.init()

-- Set up mocks
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

testing.suite("Monitor Tests", function()
    testing.beforeEach(function()
        mockMonitor = testing.cc.mockMonitor({ width = 50, height = 20 })
    end)

    testing.test("prints to monitor", function()
        local mon = Monitor.new("test-branch")
        mon:print({})

        local header = mockMonitor.findText("Branch:")
        testing.assert.notNil(header)
        testing.assert.equal(header.y, 1)
    end)

    testing.test("respects monitor size", function()
        mockMonitor.setSize(30, 10)  -- Smaller monitor

        local mon = Monitor.new("test-branch")
        mon:print({})

        local w, h = mockMonitor.getSize()
        testing.assert.equal(w, 30)
        testing.assert.equal(h, 10)
    end)
end)

testing.run()
```

## Tips

1. **Keep tests focused** - Each test should verify one behavior
2. **Use descriptive names** - Test names should clearly describe what they test
3. **Test edge cases** - Don't just test the happy path
4. **Use mocks for dependencies** - Isolate the code under test
5. **Clean up resources** - Use `afterEach` to clean up files, connections, etc.
6. **Initialize CC globals** - Call `testing.cc.init()` before loading CC modules
7. **Use helper methods** - The mock monitor provides `findText()`, `countWrites()`, etc.

## Made with Claude Code
