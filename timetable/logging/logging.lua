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
    self.minLevel = Levels.INFO
    self.dateFormat = "%m-%d %H:%M:%S"
    self.filePath = nil
    return self
end

function Logger:setLevel(level)
    if not Levels[level] then
        error("invalid log level: " .. tostring(level))
    end
    self.minLevel = Levels[level]
    self:printf("[DEBUG] log level set to %v", level)
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

    local levelStr = string.match(fmt, "^%[(%a+)%]%s*(.*)")
    if levelStr and Levels[levelStr] then
        level = Levels[levelStr]
    end

    if level < self.minLevel then
        return
    end

    message, args = self:processVFormat(message, args)

    local formattedMessage = string.format(message, table.unpack(args))
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

    self:logrotate()
end

local formats = {
    ["%d"] = {},
    ["%a"] = {},
    ["%l"] = {},
    ["%u"] = {},
    ["%c"] = {},
    ["%s"] = {},
    ["%p"] = {},
    ["%w"] = {},
    ["%x"] = {},
    ["%z"] = {},
    ["%A"] = {},
    ["%D"] = {},
    ["%U"] = {},
    ["%C"] = {},
    ["%S"] = {},
    ["%P"] = {},
    ["%W"] = {},
    ["%X"] = {},
    ["%Z"] = {},
}

-- Processes %v format specifiers in the log message.
-- If %v is detected, the corresponding argument is converted using textutils.serialize.
function Logger:processVFormat(fmt, args)
    local processedArgs = {}
    local argIndex = 1
    local i = 1
    while i <= #fmt do
        local charseq = fmt:sub(i, i+1)
        if charseq == "%%" then
            -- escaped % character, no format specifier
            i = i + 2
            goto continue
        end
        
        if formats[charseq] then
            -- other format specifier
            table.insert(processedArgs, args[argIndex])
            argIndex = argIndex + 1
            i = i + 2
            goto continue
        end
        
        if charseq ~= "%v" then
            -- not a %v specifier
            i = i + 1
            goto continue
        end
        
        local arg = args[argIndex]
        table.insert(processedArgs, textutils.serialize(arg, {
            allow_repetitions = true,
            compact = true,
        }))
        i = i + 2
        argIndex = argIndex + 1
           
        ::continue::
    end

    -- Append remaining arguments that are not %v
    for j = argIndex, #args do
        table.insert(processedArgs, args[j])
    end

    -- Replace %v with %s in the format string
    local newFmt = fmt:gsub("%%v", "%%s")

    return newFmt, processedArgs
end

-- logrotate removes the current log file and starts a new one
-- if log file has reached 1MB size
function Logger:logrotate()
    if not self.filePath then
        return
    end

    local file, err = io.open(self.filePath, "r")
    if not file then
        return
    end

    local size = file:seek("end")
    file:close()

    if size >= 1024 * 1024 then
        os.remove(self.filePath)
        self:printf("[INFO] log rotated, new log file created")
    end
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
