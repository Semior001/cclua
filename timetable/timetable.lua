-- Train Timetable Display Program
-- Displays train arrivals and departures using Create mod peripherals API

local function showUsage()
  print("Usage: timetable [options]")
  print("Options:")
  print("  --help        Show this help message")
  print("  --refresh N   Auto-refresh every N seconds (default: 30)")
  print("  --station X   Filter by station name")
  print("  --monitor     Use monitor peripheral for display")
end

local function findTrainPeripherals()
  local peripherals = {}
  for _, name in pairs(peripheral.getNames()) do
    local type = peripheral.getType(name)
    if type == "Create_SequencedGearshift" or type == "Create_TrainStation" then
      peripherals[#peripherals + 1] = {name = name, type = type}
    end
  end
  return peripherals
end

local function getMonitor()
  local monitors = peripheral.find("monitor")
  if monitors then
    return monitors
  end
  return nil
end

local function formatTime(seconds)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function formatTimeOfDay(ticks)
  local hours = math.floor(ticks / 1000)
  local minutes = math.floor((ticks % 1000) / 16.67)
  return string.format("%02d:%02d", hours, minutes)
end

local function parseScheduleEntry(entry)
  local result = {
    type = "unknown",
    destination = nil,
    conditions = {}
  }
  
  if entry.instruction then
    if entry.instruction.id == "create:destination" then
      result.type = "destination"
      if entry.instruction.data and entry.instruction.data.text then
        result.destination = entry.instruction.data.text
      end
    elseif entry.instruction.id == "create:throttle" then
      result.type = "throttle"
      if entry.instruction.data and entry.instruction.data.value then
        result.throttle = entry.instruction.data.value
      end
    elseif entry.instruction.id == "create:rename" then
      result.type = "rename"
      if entry.instruction.data and entry.instruction.data.text then
        result.name = entry.instruction.data.text
      end
    end
  end
  
  if entry.conditions then
    for _, conditionGroup in ipairs(entry.conditions) do
      for _, condition in ipairs(conditionGroup) do
        if condition.id == "create:delay" then
          result.conditions[#result.conditions + 1] = {
            type = "delay",
            value = condition.data.value,
            unit = condition.data.time_unit
          }
        elseif condition.id == "create:time_of_day" then
          result.conditions[#result.conditions + 1] = {
            type = "time_of_day",
            time = condition.data.time
          }
        elseif condition.id == "create:idle" then
          result.conditions[#result.conditions + 1] = {
            type = "idle",
            value = condition.data.value,
            unit = condition.data.time_unit
          }
        end
      end
    end
  end
  
  return result
end

local function getTrainSchedules(stationFilter)
  local schedules = {}
  local peripherals = findTrainPeripherals()
  
  for _, periph in ipairs(peripherals) do
    local success, schedule = pcall(function()
      return peripheral.call(periph.name, "getSchedule")
    end)
    
    if success and schedule then
      local trainName = "Unknown Train"
      local trainSuccess, name = pcall(function()
        return peripheral.call(periph.name, "getTrainName")
      end)
      if trainSuccess and name then
        trainName = name
      end
      
      local entries = {}
      if schedule.entries then
        for i, entry in ipairs(schedule.entries) do
          local parsed = parseScheduleEntry(entry)
          if not stationFilter or (parsed.destination and parsed.destination:find(stationFilter)) then
            entries[#entries + 1] = {
              index = i,
              data = parsed
            }
          end
        end
      end
      
      if #entries > 0 then
        schedules[#schedules + 1] = {
          peripheral = periph.name,
          train = trainName,
          cyclic = schedule.cyclic or false,
          entries = entries
        }
      end
    end
  end
  
  return schedules
end

local function displaySchedules(schedules, output)
  local write = output and output.write or write
  local print = output and function(text) 
    write(text or "")
    write("\n")
  end or print
  
  if output then
    output.clear()
    output.setCursorPos(1, 1)
  else
    term.clear()
    term.setCursorPos(1, 1)
  end
  
  print("==== TRAIN TIMETABLE ====")
  print("Updated: " .. os.date("%H:%M:%S"))
  print("=" .. string.rep("=", 25))
  print()
  
  if #schedules == 0 then
    print("No trains found or no stations match filter")
    return
  end
  
  for _, schedule in ipairs(schedules) do
    print("Train: " .. schedule.train)
    print("Peripheral: " .. schedule.peripheral)
    print("Cyclic: " .. (schedule.cyclic and "Yes" or "No"))
    print("-" .. string.rep("-", 25))
    
    for _, entry in ipairs(schedule.entries) do
      local data = entry.data
      if data.type == "destination" then
        print("  -> " .. (data.destination or "Unknown Station"))
        
        for _, condition in ipairs(data.conditions) do
          if condition.type == "delay" then
            local unit = condition.unit == 1 and "sec" or condition.unit == 2 and "min" or "hr"
            print("     Wait: " .. condition.value .. " " .. unit)
          elseif condition.type == "time_of_day" then
            print("     Until: " .. formatTimeOfDay(condition.time))
          elseif condition.type == "idle" then
            local unit = condition.unit == 1 and "sec" or condition.unit == 2 and "min" or "hr"
            print("     Idle: " .. condition.value .. " " .. unit)
          end
        end
      elseif data.type == "throttle" then
        print("  Speed: " .. (data.throttle or 0) .. "%")
      elseif data.type == "rename" then
        print("  Rename: " .. (data.name or "Unknown"))
      end
    end
    print()
  end
end

local function main()
  local args = {...}
  local refreshInterval = 30
  local stationFilter = nil
  local useMonitor = false
  local i = 1
  
  while i <= #args do
    if args[i] == "--help" then
      showUsage()
      return
    elseif args[i] == "--refresh" then
      i = i + 1
      if i <= #args then
        refreshInterval = tonumber(args[i]) or 30
      end
    elseif args[i] == "--station" then
      i = i + 1
      if i <= #args then
        stationFilter = args[i]
      end
    elseif args[i] == "--monitor" then
      useMonitor = true
    end
    i = i + 1
  end
  
  local output = nil
  if useMonitor then
    output = getMonitor()
    if not output then
      print("No monitor found! Using terminal display.")
      useMonitor = false
    end
  end
  
  local function refresh()
    local schedules = getTrainSchedules(stationFilter)
    displaySchedules(schedules, output)
  end
  
  if refreshInterval > 0 then
    print("Starting timetable display with " .. refreshInterval .. "s refresh...")
    if stationFilter then
      print("Filtering by station: " .. stationFilter)
    end
    if useMonitor then
      print("Using monitor display")
    end
    print("Press Ctrl+C to exit")
    print()
    
    local function autoRefresh()
      while true do
        refresh()
        sleep(refreshInterval)
      end
    end
    
    local ok, err = pcall(autoRefresh)
    if not ok and err ~= "Terminated" then
      print("Error: " .. err)
    end
  else
    refresh()
  end
end

main()