-- pkgm installer
-- Run with: wget run <url>

-- URL to the latest version of pkgm
local PKGM_URL = "https://raw.githubusercontent.com/Semior001/cclua/main/pkgm.lua"

print("Installing pkgm...")

-- Download pkgm
local response = http.get(PKGM_URL)
if not response then
  error("Failed to download pkgm")
end

local content = response.readAll()
response.close()

-- Save pkgm to disk
local file = fs.open("/pkgm.lua", "w")
file.write(content)
file.close()

-- Install pkgm
shell.run("/pkgm.lua")

print("pkgm has been installed successfully!")
print("You can now run commands from installed packages directly.")
print("For example, to install a package:")
print("pkgm install <url to pkgm.lua file>")