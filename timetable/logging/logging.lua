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

    local levelStr = string.match(fmt, "^%[(%u+)%]")
    if levelStr and Levels[levelStr] then
        level = Levels[levelStr]
    end

    if level < self.minLevel then
        return
    end

    local formattedMessage = string.format(message, ...)
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
