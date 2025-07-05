# CCLUA - ComputerCraft Lua Package Manager

## Overview
This repository contains `pkgm`, a package manager for ComputerCraft (Minecraft mod) that allows easy installation and management of Lua programs on ComputerCraft computers. The repository also includes example programs demonstrating the package manager's functionality.

## Project Structure

### Core Package Manager Files
- `pkgm.lua` - Main package manager script (528 lines)
- `install.lua` - One-line installer script that downloads and installs pkgm
- `readme.md` - User documentation with installation and usage instructions

### Example Programs
1. **hello-world** (`examples/hello-world/`)
   - `hello.lua` - Main program with argument parsing, fancy mode, and help
   - `lib/utils.lua` - Utility functions for formatting and fancy greeting display
   - `examples/advanced.lua` - Advanced example demonstrating multi-file downloads
   - `pkgm.lua` - Package definition showing file mapping structure

2. **control** (`control/`)
   - `control.lua` - Turtle control program with WASD+QE navigation
   - `pkgm.lua` - Package definition for the control program

## Package Manager Features

### Installation Methods
- **Quick install**: `wget run https://raw.githubusercontent.com/Semior001/cclua/main/install.lua`
- **Manual install**: Download `pkgm.lua` and run it directly

### Commands
- `pkgm install <url>` - Install package from pkgm.lua file URL
- `pkgm upgrade [pkg]` - Upgrade all packages or specific package
- `pkgm list` - List installed packages
- `pkgm remove <package>` - Remove installed package
- `pkgm path` - Update PATH to include pkgm binaries
- `pkgm help` - Show help information

### Package Structure
Packages are stored in `/pkgm/packages/` with URL-based directory structure:
- Domain-based organization (e.g., `/pkgm/packages/raw.githubusercontent.com/...`)
- Each package contains: `info.lua`, `pkgm.lua`, and program files
- Automatic binary symlink creation in `/pkgm/bin/`

### Package Definition Format
```lua
return {
  name = "package-name",
  version = "1.0.0",
  description = "Package description",
  author = "Author Name",
  main = "main.lua",  -- Entry point file
  files = {
    ["local-path"] = "url",  -- Simple format
    ["lib/utils.lua"] = "lib/utils.lua",  -- Relative URLs
    ["file.lua"] = "https://example.com/file.lua"  -- Absolute URLs
  }
}
```

## Key Implementation Details

### File Management
- Uses HTTP downloads for package files
- Supports both relative and absolute URLs in file mappings
- Creates directory structure automatically
- Maintains package metadata in `info.lua` files

### PATH Integration
- Automatically adds `/pkgm/bin` to shell PATH
- Creates startup script integration
- Symlinks allow direct command execution

### Legacy Support
- Supports older `install` function format
- Supports `run` function for custom execution logic
- Backward compatible with existing packages

## Testing Commands
Run these commands to test package manager functionality:
- `pkgm list` - Check installed packages
- `pkgm install https://raw.githubusercontent.com/Semior001/cclua/main/examples/hello-world/pkgm.lua`
- `hello-world --fancy Claude` - Test installed package
- `pkgm upgrade` - Test upgrade functionality

## Development Notes
- All code includes "Made with Claude Code" attribution
- Uses ComputerCraft's `fs`, `http`, and `shell` APIs
- Error handling for network failures and invalid packages
- Modular design supporting extensibility

## Repository Context
- Git repository with main branch
- Recent commits show turtle control program addition and package system refinements
- Active development with URL-based package structure implementation