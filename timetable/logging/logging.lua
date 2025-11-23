local Levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local Logger = {
    minLevel = Levels.Info,
    dateFormat = "%m-%d %H:%M:%S",
    filePath = nil,
}
Logger.__index = Logger

function Logger.new()
    local self = setmetatable({}, Logger)
    return self
end

function Logger:setLevel(level)
    if not Levels[level] then
        error("invalid log level: " .. tostring(level))
    end

    self.minLevel = Levels[level]
end

function Logger:setDateFormat(format)
    self.dateFormat = format
end

function Logger:setOutputFile(filePath)
    self.filePath = filePath
end

-- make a global logger instance
local globalLogger = Logger.new()

-- Prints a formatted log message if the level is at or above the minimum level.
-- Parses the level from the log message in format "[LEVEL] message", if no
-- level detected - log as INFO.
-- Usage: Logger:printf("[DEBUG] This is a debug message: %s", "details")
function Logger:printf(fmt, ...)
    local level = Levels.INFO
    local message = fmt
    local args = { ... }

    local levelStr = string.match(fmt, "^%[(%u+)%]")
    if levelStr and Levels[levelStr] then
        level = Levels[levelStr]
    end

    if level < self.minLevel then
        return
    end

    message, args = self:processVFormat(message, args)

    local formattedMessage = string.format(message, args)
    local timestamp = os.date(self.dateFormat)
    print(string.format("%s %s", timestamp, formattedMessage))

    if not self.filePath then
        return
    end

    local file, err = io.open(self.filePath, "a")
    if not file then
        print(string.format("%s [ERROR] can't open log file: %s", timestamp, err))
        return
    end

    file:write(string.format("%s %s\n", timestamp, formattedMessage))
    file:flush()
    file:close()
end

-- Processes %v format specifiers in the log message.
-- If %v is detected, the corresponding argument is converted using textutils.serialize.
function Logger:processVFormat(fmt, args)
    local processedArgs = {}
    local argIndex = 1
    local i = 1
    while i <= #fmt do
        if fmt:sub(i, i) == "%" and fmt:sub(i + 1, i + 1) == "v" then
            local arg = args[argIndex]
            table.insert(processedArgs, textutils.serialize(arg))
            i = i + 2
            argIndex = argIndex + 1
        elseif fmt:sub(i, i) == "%" and fmt:sub(i + 1, i + 1) == "%" then
            i = i + 2
        else
            i = i + 1
        end
    end

    -- Append remaining arguments that are not %v
    for j = argIndex, #args do
        table.insert(processedArgs, args[j])
    end

    -- Replace %v with %s in the format string
    local newFmt = fmt:gsub("%%v", "%%s")

    return newFmt, processedArgs
end

return {
    Logger = Logger,
    Levels = Levels,
    Printf = function(fmt, ...)
        globalLogger:printf(fmt, ...)
    end,
    SetLogger = function(logger)
        if getmetatable(logger) ~= Logger then
            error("invalid logger instance")
        end
        globalLogger = logger
    end,
}
