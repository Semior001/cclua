-- pkgm: Package Manager for ComputerCraft
-- Usage: pkgm install <link to pkgm.lua file>

local args = {...}
local command = args[1]
local target = args[2]

-- Function to download a file from URL
local function download(url, path)
  print("Downloading " .. url .. " to " .. path)
  local response = http.get(url)
  if response then
    local file = fs.open(path, "w")
    file.write(response.readAll())
    file.close()
    response.close()
    return true
  else
    print("Failed to download " .. url)
    return false
  end
end

-- Install the pkgm program itself
local function installSelf()
  print("Installing pkgm...")
  shell.run("mkdir -p /pkgm")
  if fs.exists("/startup.lua") then
    local file = fs.open("/startup.lua", "r")
    local content = file.readAll()
    file.close()
    
    if not string.find(content, "shell.run%(\"pkgm") then
      local file = fs.open("/startup.lua", "a")
      file.writeLine("\nshell.run(\"pkgm\", \"startup\")")
      file.close()
    end
  else
    local file = fs.open("/startup.lua", "w")
    file.writeLine("shell.run(\"pkgm\", \"startup\")")
    file.close()
  end
  
  -- Create a shell alias
  if not fs.exists("/rom/programs/pkgm") then
    local file = fs.open("/rom/programs/pkgm", "w")
    file.writeLine("shell.run(\"/pkgm/pkgm.lua\", ...)")
    file.close()
  end
  
  -- Copy self to installation directory
  local file = fs.open(shell.getRunningProgram(), "r")
  local content = file.readAll()
  file.close()
  
  local dest = fs.open("/pkgm/pkgm.lua", "w")
  dest.write(content)
  dest.close()
  
  print("pkgm installed successfully!")
end

-- Function to install a package from a pkgm.lua file
local function installPackage(packageUrl)
  print("Installing package from " .. packageUrl)
  
  -- Download the package definition file
  local tempPath = "/pkgm/temp.lua"
  if not download(packageUrl, tempPath) then
    return false
  end
  
  -- Load and execute the package definition
  local packageDef = loadfile(tempPath)
  if packageDef then
    local success, packageInfo = pcall(packageDef)
    if success and type(packageInfo) == "table" then
      -- Save package info
      local name = packageInfo.name or "unknown"
      local version = packageInfo.version or "0.0.0"
      
      print("Installing " .. name .. " v" .. version)
      
      -- Create package directory
      local packageDir = "/pkgm/packages/" .. name
      fs.makeDir(packageDir)
      
      -- Save package info
      local infoFile = fs.open(packageDir .. "/info.lua", "w")
      infoFile.writeLine("return {")
      infoFile.writeLine("  name = \"" .. name .. "\",")
      infoFile.writeLine("  version = \"" .. version .. "\",")
      infoFile.writeLine("  url = \"" .. packageUrl .. "\",")
      infoFile.writeLine("}")
      infoFile.close()
      
      -- Copy the package definition
      fs.copy(tempPath, packageDir .. "/pkgm.lua")
      
      -- Run the install function if it exists
      if type(packageInfo.install) == "function" then
        print("Running install script...")
        local installSuccess, installError = pcall(packageInfo.install, packageDir)
        if not installSuccess then
          print("Error during installation: " .. tostring(installError))
          return false
        end
      end
      
      -- Create an alias for running the package
      if type(packageInfo.run) == "function" or packageInfo.main then
        local aliasFile = fs.open("/rom/programs/" .. name, "w")
        aliasFile.writeLine("shell.run(\"/pkgm/packages/" .. name .. "/run.lua\", ...)")
        aliasFile.close()
        
        local runFile = fs.open(packageDir .. "/run.lua", "w")
        runFile.writeLine("local args = {...}")
        if type(packageInfo.run) == "function" then
          runFile.writeLine("local pkg = loadfile(\"/pkgm/packages/" .. name .. "/pkgm.lua\")()")
          runFile.writeLine("pkg.run(unpack(args))")
        elseif packageInfo.main then
          runFile.writeLine("shell.run(\"/pkgm/packages/" .. name .. "/" .. packageInfo.main .. "\", unpack(args))")
        end
        runFile.close()
      end
      
      fs.delete(tempPath)
      print(name .. " installed successfully!")
      return true
    else
      print("Invalid package definition")
      return false
    end
  else
    print("Failed to load package definition")
    return false
  end
end

-- Function to handle startup tasks
local function handleStartup()
  if fs.exists("/pkgm/startup") then
    local startupFiles = fs.list("/pkgm/startup")
    for _, file in ipairs(startupFiles) do
      if file:match("%.lua$") then
        shell.run("/pkgm/startup/" .. file)
      end
    end
  end
end

-- Create necessary directories
fs.makeDir("/pkgm")
fs.makeDir("/pkgm/packages")
fs.makeDir("/pkgm/startup")

-- Main command processor
if command == "install" then
  if target then
    installPackage(target)
  else
    print("Usage: pkgm install <url>")
  end
elseif command == "update" then
  if target then
    print("Updating " .. target)
    -- Check if package exists
    if fs.exists("/pkgm/packages/" .. target) then
      local infoPath = "/pkgm/packages/" .. target .. "/info.lua"
      if fs.exists(infoPath) then
        local info = loadfile(infoPath)()
        if info and info.url then
          installPackage(info.url)
        else
          print("Package information corrupted")
        end
      else
        print("Package information not found")
      end
    else
      print("Package not found")
    end
  else
    print("Usage: pkgm update <package>")
  end
elseif command == "list" then
  print("Installed packages:")
  if fs.exists("/pkgm/packages") then
    local packages = fs.list("/pkgm/packages")
    for _, package in ipairs(packages) do
      local infoPath = "/pkgm/packages/" .. package .. "/info.lua"
      if fs.exists(infoPath) then
        local info = loadfile(infoPath)()
        if info then
          print("- " .. info.name .. " (v" .. info.version .. ")")
        else
          print("- " .. package .. " (unknown version)")
        end
      else
        print("- " .. package .. " (no info)")
      end
    end
  end
elseif command == "remove" or command == "uninstall" then
  if target then
    print("Removing " .. target)
    if fs.exists("/pkgm/packages/" .. target) then
      fs.delete("/pkgm/packages/" .. target)
      if fs.exists("/rom/programs/" .. target) then
        fs.delete("/rom/programs/" .. target)
      end
      print(target .. " removed successfully")
    else
      print("Package not found")
    end
  else
    print("Usage: pkgm remove <package>")
  end
elseif command == "help" then
  print("pkgm - Package Manager for ComputerCraft")
  print("Commands:")
  print("  install <url>    - Install a package from URL")
  print("  update <package> - Update an installed package")
  print("  list            - List installed packages")
  print("  remove <package> - Remove an installed package")
  print("  help            - Show this help")
elseif command == "startup" then
  handleStartup()
else
  print("Unknown command: " .. (command or ""))
  print("Run 'pkgm help' for usage information")
end