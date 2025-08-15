# Timetable System for ComputerCraft

A comprehensive train timetable tracking system designed for ComputerCraft, featuring master coordination, station monitoring, and real-time display capabilities.

## System Overview

The timetable system consists of three types of nodes that work together to track and display train arrival information:

### Master Node (`master.lua`)
- **Purpose**: Central coordinator that stores all timetable data and manages the system
- **Features**:
  - Persistent data storage on disk
  - Statistical analysis of train arrival patterns
  - Predictive scheduling based on historical data
  - Broadcasting timetable updates to monitor nodes
  - Configuration management for branches and stations

### Monitor Node (`monitor.lua`)
- **Purpose**: Display timetable information on ComputerCraft monitors
- **Features**:
  - Scalable font size for different monitor setups
  - Real-time arrival predictions
  - Statistical information display
  - Automatic updates from master node

### Station Node (`station.lua`)
- **Purpose**: Detect train arrivals via redstone signals and report to master
- **Features**:
  - Multi-side redstone signal monitoring
  - Real-time signal detection
  - Automatic reporting to master node
  - Test mode for setup verification

## Setup Instructions

### 1. Master Node Setup
```bash
# Run the timetable program in master mode for a specific branch
timetable master <branch_name>

# First-time setup will prompt for:
# - Station names (comma-separated, in order)

# Optional commands:
timetable master <branch_name> reset     # Reset all timetable data
timetable master <branch_name> reconfig  # Reconfigure stations

# Alternative syntax:
timetable --mode=master --branch=<branch_name>

# Examples:
timetable master Main_Line
timetable master North_Line reset
```

### 2. Monitor Node Setup
```bash
# Requires a monitor peripheral connected
timetable monitor <branch_name> [scale]

# Example with 2x scale:
timetable monitor Main_Line 2

# Alternative syntax:
timetable --mode=monitor --branch=<branch_name> --scale=2

# Examples:
timetable monitor Main_Line
timetable monitor North_Line 3
```

### 3. Station Node Setup
```bash
# Run at each station location
timetable station <branch_name> <station_name>

# Example:
timetable station Main_Line Central_Station

# Test mode to verify redstone detection:
timetable station Main_Line Central_Station test

# Alternative syntax:
timetable --mode=station --branch=<branch_name> --station=<station_name>
timetable --mode=station --branch=<branch_name> --station=<station_name> test

# Examples:
timetable station Main_Line Central_Station
timetable station North_Line North_Station test
```

## Network Protocol

The system uses ComputerCraft's `rednet` protocol with the identifier `"timetable"`.

### Message Types

#### Train Arrival Report (Station → Master)
```lua
{
    type = "train_arrival",
    branch = "Branch_Name",
    station = "Station_Name",
    timestamp = 1234567890,
    side = "front"
}
```

#### Timetable Update (Master → Monitors)
```lua
{
    type = "timetable_update",
    branch = "Main_Line",
    stations = {"Station_A", "Station_B", "Station_C"},
    statistics = {
        ["Station_A"] = {
            total_arrivals = 15,
            average_interval = 300,
            last_arrival = 1234567890
        }
    },
    predictions = {
        ["Station_A"] = {
            next_arrival = 1234568190,
            confidence = 0.85
        }
    },
    timestamp = 1234567890
}
```

## Data Storage

### Master Node Files
- `master_config_<branch>.lua` - Branch-specific station configuration
- `timetable_data_<branch>.lua` - Branch-specific historical arrival data and statistics

## Features

### Statistical Analysis
- **Arrival Tracking**: Records all train arrivals with timestamps
- **Interval Calculation**: Computes average time between trains
- **Confidence Metrics**: Provides reliability indicators for predictions

### Predictive Scheduling
- **Next Arrival Estimation**: Predicts when trains will arrive based on patterns
- **Confidence Scoring**: Shows prediction reliability (0-100%)
- **Real-time Updates**: Continuously refines predictions with new data

### Monitor Display Features
- **Scalable Text**: Adjustable font size for different monitor sizes
- **Real-time Countdown**: Shows time until next predicted arrival
- **Status Indicators**: Visual cues for prediction confidence
- **Update Timestamps**: Shows when data was last refreshed

## Usage Examples

### Basic Setup for a 3-Station Branch
1. **Master Node** (Central computer):
   ```bash
   timetable master Main_Line
   # Enter stations: "North_Station, Central_Station, South_Station"
   ```

2. **Station Nodes** (At each station):
   ```bash
   # At North Station:
   timetable station Main_Line North_Station
   
   # At Central Station:
   timetable station Main_Line Central_Station
   
   # At South Station:
   timetable station Main_Line South_Station
   ```

3. **Monitor Node** (Display area):
   ```bash
   timetable monitor Main_Line 2  # 2x scale for larger text
   ```

### Redstone Signal Setup
Connect redstone to any side of the station computer:
- **Track sensors**: Redstone torch + detector rail
- **Pressure plates**: On platform areas
- **Manual switches**: For testing or manual operation

## Troubleshooting

### Common Issues
1. **No monitor found**: Ensure monitor is properly connected as peripheral
2. **No wireless modem found**: Attach a wireless modem to any side of the computer
3. **No redstone signal**: Check wiring and test with `timetable station <branch> <name> test`
4. **No network communication**: Verify rednet is working and computers are in range
5. **Data not persisting**: Check file system permissions and disk space

### Testing Commands
```bash
# Test station detection:
timetable station Test_Branch Test_Station test

# Reset master data:
timetable master Test_Branch reset

# Reconfigure master:
timetable master Test_Branch reconfig

# Show help:
timetable help
```

## System Requirements
- ComputerCraft computers with wireless modems (automatically detected on any side)
- Monitor peripherals for display nodes
- Redstone connectivity for station detection
- File system access for data persistence

---
*Made with Claude Code*