local function help()
    print("Usage: timetable [options]")
    print("Options:")
    print("    --mode master|station|monitor - mode of the node (required)")
    print("    --branch name - name of the branch (required)")
    print("    --station name - name of the station (required for station mode)")
    print("    --interval seconds - update interval for master mode (default: 5)")
    print("    --detection method - detection method for station mode")
    print("                        (redstone|detector|manual, default: redstone)")
    print("    --scale number - text scale for monitor mode (default: 1)")
    print()
    print("Examples:")
    print("    timetable --mode master --branch red --interval 10")
    print("    timetable --mode station --branch red --station central --detection redstone")
    print("    timetable --mode monitor --branch red --scale 0.5")
end

local function main(args)
    if #args == 0 then
        help()
        return
    end

    local mode, branchName, stationName, updateInterval, detectionMethod, scale

    for i = 1, #args do
        if args[i] == "--mode" then
            mode = args[i + 1]
        elseif args[i] == "--branch" then
            branchName = args[i + 1]
        elseif args[i] == "--station" then
            stationName = args[i + 1]
        elseif args[i] == "--interval" then
            updateInterval = tonumber(args[i + 1])
        elseif args[i] == "--detection" then
            detectionMethod = args[i + 1]
        elseif args[i] == "--scale" then
            scale = tonumber(args[i + 1])
        end
    end

    if not mode or (mode ~= "master" and mode ~= "station" and mode ~= "monitor") then
        print("Error: Invalid or missing --mode option")
        help()
        return
    end

    if not branchName then
        print("Error: Missing --branch option")
        help()
        return
    end

    if mode == "station" and not stationName then
        print("Error: Missing --station option for station mode")
        help()
        return
    end

    if mode == "master" then
        require("master").Run(branchName, updateInterval)
    elseif mode == "station" then
        require("station").Run(branchName, stationName, detectionMethod)
    elseif mode == "monitor" then
        require("monitor").Run(branchName, scale)
    end
end

local args = { ... }
main(args)
