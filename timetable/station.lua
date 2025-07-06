local station = {}

-- Run - start the station node
-- This node detects train arrivals and notifies the master
-- @param branch - the branch name for this station
-- @param stationName - the name of this station
-- @param detectionMethod - how to detect trains ("redstone", "detector", "manual")
function station.Run(branch, stationName, detectionMethod)
    local network = require("network")

    if not branch or not stationName then
        error("Branch and station name are required")
    end

    detectionMethod = detectionMethod or "redstone"

    network.Prepare("station", branch, stationName)

    print("Station node started:")
    print("  Branch: " .. branch)
    print("  Station: " .. stationName)
    print("  Detection method: " .. detectionMethod)

    if detectionMethod == "redstone" then
        station.runRedstoneDetection(network)
    elseif detectionMethod == "detector" then
        station.runDetectorDetection(network)
    elseif detectionMethod == "manual" then
        station.runManualDetection(network)
    else
        error("Invalid detection method: " .. detectionMethod)
    end
end

-- Redstone-based train detection
function station.runRedstoneDetection(network)
    print("Waiting for redstone signals...")
    print("Connect redstone signal to any side of the computer")
    print("Signal will trigger when train arrives")

    local lastSignalTime = 0
    local minDelay = 5000 -- 5 seconds minimum between signals

    while true do
        local event, side = os.pullEvent("redstone")
        local currentTime = os.epoch("local")

        -- Check if redstone is currently on
        if redstone.getInput(side) then
            -- Debounce signals
            if currentTime - lastSignalTime > minDelay then
                print("Train detected via redstone on side: " .. side)
                network.TrainArrived()
                lastSignalTime = currentTime
            end
        end
    end
end

-- Detector rail-based detection (using peripheral)
function station.runDetectorDetection(network)
    print("Looking for detector rail peripheral...")

    local detector = peripheral.find("minecraft:detector_rail")
    if not detector then
        error("No detector rail peripheral found")
    end

    print("Detector rail found, monitoring for train arrivals...")

    local lastDetectionTime = 0
    local minDelay = 5000 -- 5 seconds minimum between detections

    while true do
        local isPowered = detector.isPowered()
        local currentTime = os.epoch("local")

        if isPowered and currentTime - lastDetectionTime > minDelay then
            print("Train detected via detector rail")
            network.TrainArrived()
            lastDetectionTime = currentTime

            -- Wait for detector to turn off before checking again
            while detector.isPowered() do
                sleep(0.1)
            end
        end

        sleep(0.1)
    end
end

-- Manual train detection (for testing)
function station.runManualDetection(network)
    print("Manual detection mode")
    print("Press any key to simulate train arrival")
    print("Press 'q' to quit")

    while true do
        local event, key = os.pullEvent("key")

        if key == keys.q then
            print("Quitting manual detection mode")
            break
        else
            print("Manual train arrival triggered")
            network.TrainArrived()
        end
    end
end

return station
