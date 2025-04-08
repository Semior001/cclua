# cclua
A set of ComputerCraft programs, easy to use and install

## pkgm
A simple package manager for ComputerCraft that makes it easy to install and manage programs.

### Installation
Install with a single command:
```
wget run https://raw.githubusercontent.com/Semior001/cclua/main/install.lua
```

### Usage
```
pkgm install <url>     - Install a package from a pkgm.lua file URL
pkgm update <package>  - Update an installed package
pkgm list              - List all installed packages
pkgm remove <package>  - Remove an installed package
pkgm help              - Show help
```

### Creating Packages
Create a `pkgm.lua` file for your program with the following structure:

```lua
return {
  -- Required fields
  name = "your-package-name",
  version = "1.0.0",
  
  -- Optional fields
  description = "Description of your package",
  author = "Your Name",
  
  -- Installation function - called when package is installed
  install = function(packageDir)
    -- Download your program files
    -- Example:
    local response = http.get("https://example.com/your-program.lua")
    local content = response.readAll()
    response.close()
    
    local file = fs.open(packageDir .. "/your-program.lua", "w")
    file.write(content)
    file.close()
  end,
  
  -- Either specify the main file to run
  main = "your-program.lua",
  
  -- Or define a custom run function
  run = function(...)
    -- Code to run your program with args
  end
}
```

### Examples
See the `examples` directory for sample packages.

#### Hello World Example
Install the example hello-world program:
```
pkgm install https://raw.githubusercontent.com/Semior001/cclua/main/examples/hello-world/pkgm.lua
```

Then run it:
```
hello-world [your name]
```