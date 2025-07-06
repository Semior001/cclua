local master = {
    stations = {
        -- list of all registered stations
        -- format:
        -- {
        --     name = "station_name",
        --     arrival = os.epoch("local"),
        -- }
    }
}

-- Run - start the master node
-- Blocking call
-- @param branch - the branch name for this master node
function master.Run(network, branch)
    local network = require("network")
    network.Prepare("master", branch, "")
    repeat
        msgType, station = network.AwaitMasterUpdate()
        if msgType == "register" then
            network.Broadcast(master.data)
        end
    until true
end
