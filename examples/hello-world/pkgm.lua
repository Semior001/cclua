-- Example package definition for pkgm

return {
  -- Basic package information
  name = "hello-world",
  version = "1.0.0",
  description = "A simple hello world program",
  author = "cclua",
  
  -- Installation function - called when package is installed
  install = function(packageDir)
    -- Download main program file
    local response = http.get("https://raw.githubusercontent.com/Semior001/cclua/main/examples/hello-world/hello.lua")
    if not response then
      error("Failed to download main program file")
    end
    
    local content = response.readAll()
    response.close()
    
    -- Save file to package directory
    local file = fs.open(packageDir .. "/hello.lua", "w")
    file.write(content)
    file.close()
    
    print("Hello World program installed!")
  end,
  
  -- Main file to run when program is executed
  main = "hello.lua",
  
  -- Alternative: Run function can be defined instead of main
  -- run = function(...)
  --   local args = {...}
  --   print("Hello, " .. (args[1] or "World") .. "!")
  -- end
}