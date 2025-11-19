# Metro Timetable System

A comprehensive train schedule tracking and display system for ComputerCraft metro networks.

Made with Claude Code

## Overview

This system provides real-time train arrival tracking and schedule estimation for multi-branch metro networks in ComputerCraft. It consists of three types of computers working together:

- **Station Computers**: Detect train arrivals via redstone signals
- **Master Computer**: Calculates arrival predictions and coordinates the system
- **Monitor Computers**: Display real-time schedules to players

## Features

- Automatic peripheral detection (ender modems, monitors, redstone)
- Multi-branch support (multiple metro lines)
- Circular and straight line topologies
- Smart ETA calculation based on historical travel times
- Real-time schedule updates across all monitors
- Adaptive learning (travel times improve with more data)

## Requirements

### All Computers
- Computer or Advanced Computer
- Ender Modem (wireless modem that works across dimensions)

### Station Computers
- Redstone input from train detector (any side)

### Monitor Computers
- Monitor (any size, any side)

## Installation

1. Download `timetable.lua` to each computer
2. Create a configuration file `timetable_config.lua` based on the examples
3. Run `timetable.lua`

## Configuration

### Station Mode

Create `timetable_config.lua` at each station:

```lua
return {
    mode = "station",
    stationName = "SpawnTown",
    branch = "ST-EF",
    protocol = "metro_timetable"
}
```

**Fields:**
- `mode`: Must be `"station"`
- `stationName`: Unique name for this station
- `branch`: Branch/line name this station belongs to
- `protocol`: Network protocol name (must match across all computers)

### Master Mode

Create `timetable_config.lua` on the master computer:

```lua
return {
    mode = "master",
    protocol = "metro_timetable",
    branches = {
        ["ST-EF"] = {
            stations = {"SpawnTown", "Novozavodsk", "EndFortress"},
            circular = true
        },
        ["Main-Line"] = {
            stations = {"Central", "North", "Northwest", "West"},
            circular = false
        }
    }
}
```

**Fields:**
- `mode`: Must be `"master"`
- `protocol`: Network protocol name
- `branches`: Table of branch configurations
  - Key: Branch name
  - `stations`: Array of station names in order
  - `circular`: `true` if train loops back, `false` if it terminates

### Monitor Mode

Create `timetable_config.lua` at each monitor:

```lua
return {
    mode = "monitor",
    branch = "ST-EF",
    protocol = "metro_timetable",
    stationOrder = {"SpawnTown", "Novozavodsk", "EndFortress"}
}
```

**Fields:**
- `mode`: Must be `"monitor"`
- `branch`: Which branch to display
- `protocol`: Network protocol name
- `stationOrder`: Optional array defining display order

## How It Works

### Station Detection

Station computers monitor all redstone sides for input. When a train arrives and activates redstone:
1. Station detects the rising edge (transition from off to on)
2. Station broadcasts arrival message with timestamp
3. Station waits for train to depart (falling edge)

### Schedule Calculation

The master computer:
1. Receives arrival notifications from stations
2. Records timestamps for each arrival
3. Calculates travel times between consecutive stations
4. Uses exponential moving average for smoothing (70% old, 30% new)
5. Predicts future arrivals based on current position and historical data
6. Broadcasts updated schedules every 5 seconds

### Display Updates

Monitor computers:
1. Listen for schedule broadcasts from master
2. Filter for their configured branch
3. Update display with arrival times
4. Show time format: "in Xs" (seconds) or "in Xm" (minutes)
5. Display last update timestamp at bottom

## Example Network Setup

### Simple Circular Line

```
    [SpawnTown] ---> [Novozavodsk] ---> [EndFortress]
          ^                                   |
          |___________________________________|
```

**Computers needed:**
- 3 station computers (one at each station)
- 1 master computer (can be anywhere)
- 1+ monitor computers (at stations where players wait)

### Multi-Branch System

```
Branch A:  [Central] <--> [East] <--> [Northeast]
Branch B:  [Central] <--> [West] <--> [Northwest]
```

**Configuration:**
- Master defines both branches
- Stations specify their branch name
- Monitors can display either branch

## Troubleshooting

### "No ender modem found!"
- Check that ender modem is attached to computer
- Ender modems are different from wireless modems
- Try breaking and re-placing the modem

### "No monitor found!" (Monitor mode)
- Attach a monitor to any side of the computer
- Monitors can be any size (1x1 to 8x6)

### "Station name not configured!" (Station mode)
- Check `timetable_config.lua` has `stationName` field
- Ensure name matches exactly with master configuration

### Stations not appearing on monitor
- Verify station `branch` matches monitor `branch`
- Check master has correct branch configuration
- Ensure protocol names match across all computers
- Verify ender modems are all on same frequency

### ETAs are inaccurate
- System needs time to learn travel times
- Accuracy improves after 2-3 complete circuits
- Check that stations are in correct order in master config
- Verify trains run regularly

### Monitor shows "updated: never"
- Master computer may not be running
- Check protocol names match
- Verify ender modems are working
- Check master has branch configuration

## Advanced Usage

### Multiple Monitors
You can run multiple monitors for the same branch at different locations. Each monitor independently receives updates from the master.

### Branch Naming
Use descriptive branch names like:
- "Red-Line"
- "ST-EF" (station abbreviations)
- "Circle-Route"
- "Express-1"

### Station Naming
Station names should be:
- Unique across the entire network
- Descriptive and readable
- Consistent between station computers and master config

### Circular vs. Straight Lines

**Circular (`circular = true`):**
- Train returns to first station
- All stations always shown with ETAs
- Used for loop routes

**Straight (`circular = false`):**
- Train terminates at last station
- Only shows stations ahead of current position
- Used for shuttle routes

## Performance Notes

- System uses minimal resources
- Master broadcasts every 5 seconds
- Stations check redstone every 0.1 seconds
- Monitors update display every 0.5 seconds
- No database or file I/O required

## Compatibility

- ComputerCraft 1.8+
- Works in single-player and multi-player
- Compatible with other rednet programs (uses custom protocol)
- No conflicts with other mods

## License

Made with Claude Code
Free to use and modify
