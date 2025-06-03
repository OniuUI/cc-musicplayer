# Bognesferga Radio

A comprehensive music and radio system for ComputerCraft that combines YouTube music streaming with network radio functionality for synchronized playback across multiple computers. Now featuring advanced telemetry and logging capabilities.

## Features

### 🎵 YouTube Music Player
- **YouTube Integration**: Search and stream music directly from YouTube
- **Modern Touch Interface**: Intuitive click-based UI with visual feedback
- **Queue Management**: Play now, play next, or add to queue
- **Loop Modes**: Off, queue loop, or single song loop
- **Visual Volume Control**: Interactive slider with real-time adjustment
- **Multi-Speaker Support**: Automatic detection and use of all connected speakers

### 📻 Network Radio System
- **Radio Stations**: Host your own radio station or connect to others on the server
- **Synchronized Playback**: All listeners hear the same song at the same time
- **Station Discovery**: Scan for available radio stations on the network
- **Playlist Management**: Build and manage playlists for your radio station
- **Real-time Listener Count**: See how many people are tuned in
- **Seamless Integration**: Use YouTube search to add songs to radio playlists

### 📊 Advanced Telemetry & Logging
- **Comprehensive System Detection**: Automatic detection of computer type, peripherals, and capabilities
- **Dual-Screen Support**: Separate application and debug console displays
- **Real-time Performance Monitoring**: Memory usage, event tracking, and system health
- **Detailed Logging**: Session logs, error tracking, and emergency logging
- **System Health Monitoring**: Peripheral connectivity and performance metrics
- **Automatic Log Management**: File-based logging with rotation and export capabilities

### 🎨 Enhanced User Experience
- **Main Menu System**: Choose between YouTube player and network radio
- **Colorful Interface**: Professional design with cyan/lime accents and rainbow elements
- **Animated Branding**: "Developed by Forty" rainbow footer
- **Status Indicators**: Visual feedback for all system states
- **Responsive Design**: Adapts to different screen sizes
- **Error Recovery**: Graceful error handling with automatic recovery

## Installation

### Quick Install (Recommended)
```lua
pastebin get YzZzdRrm download
```

### Manual Installation
```lua
wget https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/install.lua
install
```

## Requirements

- **ComputerCraft**: CC: Tweaked for Minecraft 1.18.2+
- **Speaker**: At least one speaker peripheral attached to the computer
- **Internet Access**: HTTP requests must be enabled in ComputerCraft configuration
- **Optional**: Monitor(s) for dual-screen telemetry display
- **Optional**: Wireless modem for network radio functionality

### Recommended Setup
- **Advanced Computer**: For color support and enhanced features
- **Multiple Monitors**: Primary display for application, secondary for debug console
- **Multiple Speakers**: For enhanced audio experience
- **Wireless Modem**: For network radio features

## Usage

### Getting Started
1. Run `startup` to launch Bognesferga Radio
2. Choose from the main menu:
   - **YouTube Music Player**: Search and play music
   - **Network Radio**: Connect to shared stations
   - **Host Radio Station**: Create your own station
   - **Exit**: Close the application

### YouTube Music Player
1. Select "YouTube Music Player" from the main menu
2. Click the "Search" tab to find music
3. Type your search query and press Enter
4. Click on search results to add to queue or play immediately
5. Use the "Now Playing" tab to control playback
6. Adjust volume with the interactive slider
7. Use loop controls for repeat functionality

### Network Radio
#### Connecting to a Station
1. Select "Network Radio" from the main menu
2. Click "Scan for Stations" to find available stations
3. Select a station from the list
4. Click "Connect to Selected" to join

#### Hosting a Station
1. Select "Host Radio Station" from the main menu
2. Enter a name for your station
3. Click "Add Songs" to build your playlist
4. Click "Start Broadcast" to begin streaming
5. Manage your playlist and control playback

### Telemetry Features
- **System Information**: View detailed hardware and peripheral information
- **Performance Monitoring**: Track memory usage and system performance
- **Log Files**: Access detailed logs in `musicplayer/logs/`
- **Dual-Screen Mode**: Use separate monitors for application and debugging
- **Health Monitoring**: Real-time peripheral connectivity status

## Network Radio Setup

### Requirements for Network Radio
- **Wireless Modem**: Attached to the computer (any side)
- **Network Range**: All computers must be within wireless range
- **Compatibility**: Works with both wireless and ender modems

### Setting Up a Radio Network
1. Ensure all computers have wireless modems attached
2. All computers should be within wireless range of each other
3. One computer hosts a station, others can connect as clients
4. Multiple stations can operate simultaneously on the same network

## Architecture

The system is built with a modular architecture featuring comprehensive telemetry:

```
startup.lua          # Main entry point with telemetry integration
musicplayer/
├── config.lua       # Configuration and constants
├── state.lua        # Global state management
├── ui.lua           # YouTube player UI rendering
├── input.lua        # Mouse/keyboard input handling
├── audio.lua        # Audio streaming and playback
├── network.lua      # HTTP request/response handling
├── main.lua         # YouTube player coordination
├── menu.lua         # Main menu system
├── radio.lua        # Network radio logic
├── radio_ui.lua     # Radio interface rendering
└── telemetry/       # Advanced telemetry system
    ├── telemetry.lua      # Main telemetry coordinator
    ├── logger.lua         # File and monitor logging
    └── system_detector.lua # Hardware detection
```

## Troubleshooting

### No Speakers Found
- Attach at least one speaker peripheral to any side of the computer
- For pocket computers, equip a speaker upgrade
- Check telemetry logs for peripheral detection issues

### Network Radio Issues
- Ensure wireless modem is attached and functioning
- Check that computers are within wireless range
- Verify HTTP is enabled in ComputerCraft configuration
- Try restarting both host and client computers
- Check telemetry logs for network connectivity issues

### Audio Playback Problems
- Check internet connectivity
- Verify the YouTube API is accessible
- Ensure speakers have adequate power (if using mods that require it)
- Review audio logs in the telemetry system

### Installation Failures
- Confirm HTTP requests are enabled in server configuration
- Check that GitHub is accessible from your server
- Try the pastebin installation method as an alternative
- Review installation logs for specific error details

### Telemetry Issues
- Check `musicplayer/logs/` directory for detailed error logs
- Verify monitor connections for dual-screen functionality
- Review system report in `musicplayer/telemetry/system_report.txt`
- Check emergency logs for critical system issues

## Version History

- **v3.1**: Restored complete functionality with integrated telemetry system
- **v3.0**: Added comprehensive telemetry, logging, and dual-screen support
- **v2.1**: Added main menu system and network radio functionality
- **v2.0**: Complete rewrite with iPod-style interface and API integration
- **v1.x**: Original music streaming player

## Advanced Features

### Telemetry System
- **System Detection**: Automatic identification of computer type and capabilities
- **Performance Metrics**: Real-time monitoring of memory usage and event processing
- **Health Monitoring**: Continuous peripheral connectivity checks
- **Dual-Screen Support**: Separate application and debug displays
- **Comprehensive Logging**: Multiple log levels with file rotation

### Error Handling
- **Graceful Recovery**: Automatic error recovery with menu fallback
- **Emergency Logging**: Critical error capture and reporting
- **Resource Cleanup**: Proper cleanup of audio streams and network connections
- **User Feedback**: Clear error messages with troubleshooting guidance

### Performance Optimization
- **Modular Architecture**: Efficient loading and memory management
- **Parallel Processing**: Concurrent audio, UI, and network handling
- **Resource Monitoring**: Automatic garbage collection and memory tracking
- **Event Optimization**: Efficient event handling and processing

## Support

For issues, feature requests, or contributions, please check the telemetry logs first for detailed error information. The system provides comprehensive logging to help diagnose and resolve issues quickly.

## License

This project is open source and available under the MIT License.

---

*Enjoy your music and radio experience in ComputerCraft!* 🎵📻
