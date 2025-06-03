# Bognesferga Radio

A comprehensive music and radio system for ComputerCraft that combines YouTube music streaming with network radio functionality for synchronized playback across multiple computers.

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

### 🎨 Enhanced User Experience
- **Main Menu System**: Choose between YouTube player and network radio
- **Colorful Interface**: Professional design with cyan/lime accents and rainbow elements
- **Animated Branding**: "Developed by Forty" rainbow footer
- **Status Indicators**: Visual feedback for all system states
- **Responsive Design**: Adapts to different screen sizes

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
- **Wireless Modem**: Required for network radio features
- **Internet Access**: HTTP requests must be enabled in ComputerCraft config

## How to Use

### Starting the System
1. Run the installer using one of the methods above
2. The system will automatically start with the main menu
3. Choose your desired experience:
   - **YouTube Music Player**: Traditional music streaming
   - **Network Radio**: Connect to shared radio stations
   - **Host Radio Station**: Create your own radio station

### YouTube Music Player
1. Select "YouTube Music Player" from the main menu
2. Click the "Search" tab to find music
3. Type your search query and press Enter
4. Click on any result to see playback options:
   - **Play now**: Start playing immediately
   - **Play next**: Add to front of queue
   - **Add to queue**: Add to end of queue
5. Use the volume slider to adjust audio level
6. Press ESC to return to the main menu

### Network Radio - Client
1. Select "Network Radio" from the main menu
2. Press 'S' to scan for available radio stations
3. Use UP/DOWN arrows to select a station
4. Press ENTER to connect to the selected station
5. Enjoy synchronized music with other listeners!
6. Press 'D' to disconnect or ESC to return to menu

### Network Radio - Host
1. Select "Host Radio Station" from the main menu
2. Enter a name for your radio station
3. Press 'A' to add songs to your playlist using YouTube search
4. Press SPACE to start/stop broadcasting
5. Press 'N' to skip to the next track
6. Monitor listener count in real-time
7. Press ESC to stop the station and return to menu

## Network Radio Technical Details

The network radio system uses ComputerCraft's rednet API for communication:

- **Protocol**: `bognesferga_radio` for messages, `radio_station` for discovery
- **Synchronization**: Automatic time offset calculation for synchronized playback
- **Range**: Standard wireless modem range (64+ blocks, more at higher altitudes)
- **Compatibility**: Works with both wireless and ender modems

### Setting Up a Radio Network
1. Ensure all computers have wireless modems attached
2. All computers should be within wireless range of each other
3. One computer hosts a station, others can connect as clients
4. Multiple stations can operate simultaneously on the same network

## Architecture

The system is built with a modular architecture:

```
startup.lua          # Main entry point and menu system
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
└── radio_ui.lua     # Radio interface rendering
```

## Troubleshooting

### No Speakers Found
- Attach at least one speaker peripheral to any side of the computer
- For pocket computers, equip a speaker upgrade

### Network Radio Issues
- Ensure wireless modem is attached and functioning
- Check that computers are within wireless range
- Verify HTTP is enabled in ComputerCraft configuration
- Try restarting both host and client computers

### Audio Playback Problems
- Check internet connectivity
- Verify the YouTube API is accessible
- Ensure speakers have adequate power (if using mods that require it)

### Installation Failures
- Confirm HTTP requests are enabled in server configuration
- Check that GitHub is accessible from your server
- Try the pastebin installation method as an alternative

## Version History

- **v2.1**: Added main menu system and network radio functionality
- **v2.0**: Complete rewrite with modular architecture and enhanced UI
- **v1.x**: Original file-based music player system

## Credits

**Developed by Forty**

- Original concept inspired by iPod-style music players
- Built for the ComputerCraft community
- Uses CC: Tweaked's speaker and rednet APIs
- YouTube integration via custom API endpoint

## License

This project is open source and available under the MIT License. Feel free to modify and distribute according to your needs.

---

*Enjoy your music and radio experience in ComputerCraft!* 🎵📻
