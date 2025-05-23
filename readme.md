# cclua
A set of ComputerCraft programs, easy to use and install

_Made with [Claude Code](https://claude.ai/code) 🤖_

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
pkgm upgrade [pkg]     - Upgrade all packages or a specific package
pkgm list              - List all installed packages
pkgm remove <package>  - Remove an installed package
pkgm path              - Update PATH to include pkgm binaries
pkgm help              - Show help
```

### Features
- Simple package definitions with file mappings
- Packages are structured based on their download URL
- Installed packages are automatically added to PATH
- Run installed packages directly without additional steps
- Package structure mirrors the URL path from which they are downloaded

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
  
  -- Main file to run when the program is executed
  main = "main.lua",
  
  -- Files to download (key = local path, value = URL or file config)
  files = {
    -- Simple format: ["local-path"] = "url"
    ["main.lua"] = "main.lua", -- Relative to pkgm.lua file location
    
    -- You can use subfolders
    ["lib/utils.lua"] = "lib/utils.lua",
    
    -- Use absolute URLs for files from different locations
    ["examples/demo.lua"] = "https://example.com/demo.lua"
  }
}
```

### Files Mapping
The files mapping simplifies package installation by allowing you to declare all required files:

1. **Simple form**: `["local-path"] = "url"`
   - The local path where the file will be saved
   - The URL can be relative (to the pkgm.lua location) or absolute

2. **Advanced form**: `["local-path"] = { url = "url", other_options = value }`
   - Allows for additional options per file in the future

Relative URLs are automatically resolved based on the location of the pkgm.lua file.

### Examples
See the `examples` directory for sample packages.

#### Hello World Example
Install the example hello-world program:
```
pkgm install https://raw.githubusercontent.com/Semior001/cclua/main/examples/hello-world/pkgm.lua
```

Then run it directly (it's automatically added to PATH):
```
hello-world [your name]
```

Try the fancy mode:
```
hello-world --fancy [your name]
```