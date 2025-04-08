-- Example package definition for pkgm
-- Made with Claude Code (https://claude.ai/code)

return {
  -- Basic package information
  name = "hello-world",
  version = "1.0.0",
  description = "A simple hello world program",
  author = "cclua",
  
  -- Main file to run when the program is executed
  main = "hello.lua",
  
  -- Files to download (key = local path, value = URL or file config)
  files = {
    -- Simple format: ["local-path"] = "url"
    ["hello.lua"] = "hello.lua", -- Will be downloaded relative to this pkgm.lua file
    
    -- You can use subfolders
    ["lib/utils.lua"] = "lib/utils.lua",
    
    -- Use absolute URLs for files from other locations
    ["examples/advanced.lua"] = "https://raw.githubusercontent.com/Semior001/cclua/main/examples/hello-world/examples/advanced.lua"
  }
  
  -- Legacy support for older versions of pkgm:
  -- install = function(packageDir)
  --   -- This function is no longer needed with the 'files' mapping above
  -- end,
  
  -- Alternatively, you can define a custom run function instead of using 'main'
  -- run = function(...)
  --   local args = {...}
  --   print("Hello, " .. (args[1] or "World") .. "!")
  -- end
}