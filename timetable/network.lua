local network = {
    masterID = nil,
    branch = nil,
    station = nil
}

-- Prepare - prepare the rednet and host the timetable service
-- @param mode - the mode of the node (master, station, monitor), required
-- @param branch - name of the branch that the node is part of, required
-- @param station - name of the station for station mode
function network.Prepare(mode, branch, station)
    local modem = peripheral.find("modem") or error("no modem found")
    rednet.open(peripheral.getName(modem))

    network.masterID = network.findMaster()
    network.branch = branch
    network.station = station

    if mode ~= "master" and not network.masterID then
        error("no master node found, please start a master node first")
    end

    if mode == "master" then
        local nodes = { rednet.lookup("timetable", "master") }
        if #nodes > 0 then
            error("master node already exists: " .. nodes[1])
        end
        rednet.host("timetable", "master")
        return
    end

    if mode == "station" then
        if not branch or not station then
            error("branch and station names are required for station mode")
        end
        rednet.send(network.masterID, {
            type = "register",
            branch = branch,
            station = station
        }, "timetable")
        return
    end
end

-- Closes the network communication, effectively unregistering the node
-- from the master.
function network.Close()
    rednet.send(network.masterID, {
        type = "unregister",
        branch = network.branch,
        station = network.station
    }, "timetable")
end

-- TrainArrived - notifies master that a train has arrived at the station
function network.TrainArrived()
    rednet.send(network.masterID, {
        type = "train_arrived",
        branch = network.branch,
        station = network.station
    }, "timetable")
end

-- Broadcast - broadcast a timetable update to all monitors in the network
--
-- @param branch - the branch name to update
-- @param timetable - the timetable data to broadcast
function network.Broadcast(timetable)
    rednet.broadcast({
        type = "timetable_update",
        branch = network.branch,
        timetable = timetable
    }, "timetable")
end

-- AwaitMasterUpdate - receive a master notification
-- This function blocks until a station registration is received
--
-- @return string type - the type of the message received
-- @return string station - the name of the station that registered
function network.AwaitMasterUpdate()
    local message = { type = "not yet received" }
    repeat
        _, message, _ = rednet.receive("timetable")
    until (message.type == "register" or message.type == "train_arrived")
        and message.branch == network.branch
    return message.type, message.station
end

-- AwaitTimetableUpdate - receive a broadcasted monitor update
-- This function blocks until a timetable update is received
--
-- @return the timetable data if received, or nil if not
function network.AwaitTimetableUpdate()
    local message = { type = "not yet received" }
    repeat
        _, message, _ = rednet.receive("timetable")
    until message.type == "timetable_update" and message.branch == network.branch
    return message.timetable
end

-- find the master node ID in the network
--
-- @return the ID of the master node, or nil if not found
function network.findMaster()
    local nodes = { rednet.lookup("timetable", "master") }
    if #nodes == 0 then
        return nil
    end
    return nodes[1]
end

return network
