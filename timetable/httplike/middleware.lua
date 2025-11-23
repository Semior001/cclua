package.path = package.path .. ";../?.lua"
local log = require("logging.logging")

local function Wrap(base, ...)
    local funcs = { ... }
    local wrapped = base
    for i = #funcs, 1, -1 do
        wrapped = funcs[i](wrapped)
    end
    return wrapped
end

local function Logging(level)
    return function(next)
        return function(req)
            local res = next(req)
            log.Printf("[INFO] %s %s - %d", req.method, req.path, res.status)
            if res.status >= 400 then
                log.Printf("[DEBUG] Request headers: %s", tostring(req.headers))
                log.Printf("[DEBUG] Request body: %s", tostring(req.body))
                log.Printf("[DEBUG] Response body: %s", tostring(res.body))
            end
            return res
        end
    end
end

return {
    Wrap = Wrap,
    Logging = Logging,
}
