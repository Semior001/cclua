local middleware = {}

function middleware.wrap(base, ...)
    local funcs = { ... }
    local wrapped = base
    for i = #funcs, 1, -1 do
        wrapped = funcs[i](wrapped)
    end
    return wrapped
end

function middleware.logging(next)
    return function(req)
        local res = next(req)
        print(os.date("%m-%d %H:%M:%S") .. " - " .. req.method .. " " .. req.path .. " - " .. res.status)
        return res
    end
end

return middleware
