# Timetable System - ComputerCraft Train Scheduling

## Overview
This is a sophisticated train timetable tracking system for ComputerCraft that provides real-time arrival predictions, statistical analysis, and centralized coordination across multiple railway branches. The system uses a distributed architecture with three node types working together via wireless communication.

## System Architecture

### Three Node Types
1. **Master Node** - Central coordinator that stores data and manages the system
2. **Monitor Node** - Visual display of timetables on ComputerCraft monitors
3. **Station Node** - Detects train arrivals via redstone signals

### Key Features
- **Branch Separation**: Multiple railway lines can operate independently
- **Persistent Storage**: All data saved to disk with branch-specific files
- **Predictive Analytics**: Uses historical data to predict future arrivals
- **Rolling Window Storage**: Maintains last 30 arrivals per station to prevent memory issues
- **Linear Route Intelligence**: Advanced prediction algorithm that considers train direction and route layout
- **Wireless Communication**: Uses rednet protocol for seamless node coordination

## File Structure
- `timetable.lua` (841 lines) - Main program with all three node implementations
- `pkgm.lua` - Package manager definition for installation
- `README.md` - Comprehensive user documentation
- `CLAUDE.md` - This technical documentation

## Core Implementation Details

### Master Node (`master` module, lines 87-470)
- **Configuration Management**: Branch-specific station lists stored in `master_config_<branch>.lua`
- **Data Persistence**: Historical arrivals stored in `timetable_data_<branch>.lua`
- **Statistical Engine**: Calculates average intervals, confidence metrics, and arrival patterns
- **Advanced Prediction Algorithm** (lines 169-324):
  - Determines train direction based on recent arrivals
  - Handles linear back-and-forth routes intelligently
  - Calculates predictions based on current position and route topology
  - Provides confidence scoring based on data quality
- **Rolling Window Storage**: Maintains exactly 30 most recent arrivals per station
- **Broadcasting**: Sends timetable updates every 5 seconds to monitor nodes

### Monitor Node (`monitor_node` module, lines 472-661)
- **Scalable Display**: Configurable text scale for different monitor sizes
- **Real-time Updates**: Refreshes display every second with current predictions
- **Confidence Indicators**: Visual cues showing prediction reliability
- **Time Formatting**: Smart formatting for seconds, minutes, and hours
- **Status Tracking**: Shows data age and connection status

### Station Node (`station_node` module, lines 663-812)
- **Multi-side Detection**: Monitors redstone signals on all 6 sides simultaneously
- **Edge Detection**: Only triggers on rising edge (off → on) to prevent duplicate reports
- **Test Mode**: Special mode for verifying redstone setup during installation
- **Real-time Status**: Shows current signal state on all sides with color coding
- **Automatic Reporting**: Broadcasts arrival data immediately to master node

### Networking Protocol
- **Protocol**: Uses "timetable" rednet protocol
- **Message Types**:
  - `train_arrival`: Station → Master (reports detected trains)
  - `timetable_update`: Master → Monitors (broadcasts current predictions)
- **Automatic Modem Detection**: Finds wireless modems on any side automatically

## Data Structures

### Arrival Data Storage
```lua
timetable_data = {
    arrivals = {
        ["Station_Name"] = {timestamp1, timestamp2, ...}, -- Max 30 entries
    },
    statistics = {
        ["Station_Name"] = {
            total_arrivals = number,
            average_interval = seconds,
            last_arrival = timestamp
        }
    }
}
```

### Prediction Algorithm
The system implements a sophisticated linear route prediction algorithm that:
1. Identifies the most recent train arrival across all stations
2. Determines train direction by comparing the two most recent arrivals
3. Handles edge cases at route endpoints (turnaround points)
4. Calculates steps required to reach each station based on current position and direction
5. Uses average travel time between stations for timing predictions
6. Provides confidence scoring based on historical data quality

### Configuration Format
```lua
master.config = {
    branch_name = "Main_Line",
    stations = {"Station_A", "Station_B", "Station_C"}, -- In route order
    broadcast_interval = 5 -- seconds
}
```

## Usage Patterns

### Installation Commands
- `timetable master <branch>` - Start master coordinator
- `timetable monitor <branch> [scale]` - Start display node
- `timetable station <branch> <station>` - Start detection node

### Command Line Interface
- Supports both positional and named argument formats
- Built-in help system with comprehensive usage examples
- Special commands: `reset`, `reconfig`, `test`

### Runtime Controls
- **Master**: Press 'q' to quit, 'r' to reset data, 'c' to reconfigure
- **Monitor**: Ctrl+T to exit
- **Station**: Press 'q' to quit

## Technical Considerations

### Error Handling
- Validates wireless modem availability before operation
- Handles missing peripheral gracefully with clear error messages
- File I/O protected with existence checks and fallback defaults

### Performance Optimization
- Rolling window prevents unlimited memory growth
- Efficient redstone polling with edge detection
- Minimal network traffic with structured update intervals

### Data Integrity
- Atomic file operations for configuration and data storage
- Graceful handling of corrupted or missing data files
- Automatic modem detection prevents connection issues

## Testing Strategy
The system includes comprehensive testing capabilities:
- **Station Test Mode**: Verify redstone detection setup
- **Master Reset**: Clear historical data for fresh starts
- **Configuration Reset**: Reconfigure station lists
- **Real-time Status**: All nodes show current operational state

## Development Notes
- **ComputerCraft APIs Used**: `fs`, `rednet`, `peripheral`, `redstone`, `os`, `term`
- **Lua Version**: Compatible with ComputerCraft's Lua 5.1 environment
- **Error Recovery**: Robust handling of network failures and peripheral disconnections
- **Scalability**: Designed to handle multiple branches simultaneously
- **Maintainability**: Modular design with clear separation of concerns

This system represents a complete solution for railway timetable management in ComputerCraft, combining real-time detection, statistical analysis, and user-friendly interfaces in a robust, distributed architecture.