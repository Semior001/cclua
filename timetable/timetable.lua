local function help()
    print("Usage: timetable [options]")
    print("Options:")
    print("    --mode master|station|monitor - mode of the node")
    print("    --branch name - name of the branch for station mode")
end

local function main(args)
    if #args == 0 then
        help()
        return
    end

    local mode, masterId, branchName

    for i = 1, #args do
        if args[i] == "--mode" then
            mode = args[i + 1]
        elseif args[i] == "--master" then
            masterId = args[i + 1]
        elseif args[i] == "--branch" then
            branchName = args[i + 1]
        end
    end

    if not mode or (mode ~= "master" and mode ~= "station" and mode ~= "monitor") then
        print("Error: Invalid or missing --mode option")
        help()
        return
    end

    if mode == "master" then
        require("master").run(masterId)
    elseif mode == "station" then
        require("station").run(branchName)
    elseif mode == "monitor" then
        require("monitor").run()
    end
end

local args = { ... }
main(args)
