-- Turtle Control Program
-- WASD for movement, QE for up/down, Ctrl+C to exit
---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

local function clearScreen()
    term.clear()
    term.setCursorPos(1, 1)
end

local function printHelp()
    print("Turtle Manual Control")
    print("-----------------")
    print("Controls:")
    print("W - Move Forward")
    print("S - Move Backward")
    print("A - Turn Left")
    print("D - Turn Right")
    print("Q - Move Up")
    print("E - Move Down")
    print("Ctrl+C - Exit")
    print("-----------------")
end

local function handleMovement(key)
    if key == keys.w then
        print("Moving forward...")
        return turtle.forward()
    elseif key == keys.s then
        print("Moving backward...")
        return turtle.back()
    elseif key == keys.a then
        print("Turning left...")
        return turtle.turnLeft()
    elseif key == keys.d then
        print("Turning right...")
        return turtle.turnRight()
    elseif key == keys.q then
        print("Moving up...")
        return turtle.up()
    elseif key == keys.e then
        print("Moving down...")
        return turtle.down()
    end
    return false
end

-- Main loop
local function main()
    clearScreen()
    printHelp()

    -- Start the control loop
    while true do
        local event, key = os.pullEvent("key")

        if handleMovement(key) then
            -- Successfully moved
            sleep(0.2) -- small delay for feedback
        else
            -- Movement failed or unknown key
        end

        -- Redraw the screen
        clearScreen()
        printHelp()
    end
end

-- Run the main function in protected mode to handle Ctrl+C
local ok, err = pcall(main)
if not ok and err ~= "Terminated" then
    print("Error: " .. err)
end

print("Exiting turtle control program...")
