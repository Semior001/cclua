-- Hello World program
-- Made with Claude Code (https://claude.ai/code)

local function showUsage()
  print("Usage: hello-world [options] [name]")
  print("Options:")
  print("  --help    Show this help message")
  print("  --fancy   Display a fancy greeting")
  print("  --example Run the advanced example")
end

local args = {...}
local name
local fancy = false
local showExample = false
local i = 1

-- Parse arguments
while i <= #args do
  if args[i] == "--help" then
    showUsage()
    return
  elseif args[i] == "--fancy" then
    fancy = true
  elseif args[i] == "--example" then
    showExample = true
  else
    name = args[i]
  end
  i = i + 1
end

-- Handle example flag
if showExample then
  shell.run("examples/advanced.lua")
  return
end

-- Display greeting
if fancy then
  local utils = require("lib.utils")
  utils.fancyGreeting(name)
else
  if not name or name == "" then
    name = "World"
  end
  print("Hello, " .. name .. "!")
  print("This program was installed using pkgm!")
  print("Try --fancy for a nicer greeting!")
end