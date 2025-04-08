-- Utility functions for the hello-world package

local utils = {}

-- Format a greeting message
function utils.formatGreeting(name)
  if not name or name == "" then
    name = "World"
  end
  
  return "Hello, " .. name .. "!"
end

-- Print fancy greeting
function utils.fancyGreeting(name)
  local greeting = utils.formatGreeting(name)
  local border = string.rep("*", #greeting + 4)
  
  print(border)
  print("* " .. greeting .. " *")
  print(border)
end

return utils