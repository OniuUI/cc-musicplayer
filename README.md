# iPod-Style Music Player for ComputerCraft

A modern, feature-rich music player for ComputerCraft/CC Tweaked that brings YouTube streaming directly to your Minecraft computers. Built with a clean, modular architecture for easy maintenance and extensibility.

## Features

- 🎵 **YouTube Search & Streaming** - Search and play any song from YouTube
- 📱 **Modern Touch Interface** - Intuitive click-based UI with tabs
- 🎧 **Queue Management** - Add songs to queue, play next, or play now
- 🔊 **Volume Controls** - Visual volume slider with real-time adjustment
- 🔄 **Loop Modes** - Loop off, loop queue, or loop single song
- 📋 **Playlist Support** - Automatically handles YouTube playlists
- 🎨 **Clean UI** - Two-tab interface: Now Playing and Search
- 🏗️ **Modular Architecture** - Clean separation of concerns for easy maintenance

## Installation

### Easy Installation (Recommended)

Run this command in any ComputerCraft computer:

```lua
pastebin get <YOUR_PASTEBIN_ID> install
install
```

### Manual Installation

1. Download all files from this repository
2. Create a `musicplayer` folder in your ComputerCraft computer
3. Place the module files in the `musicplayer` folder
4. Place `startup.lua` in the root directory
5. Run `startup` to begin

## Requirements

- ComputerCraft or CC Tweaked
- Connected speaker(s)
- Internet connection (HTTP enabled)

## Architecture

The music player is built with a modular architecture:

### File Structure
```
/
├── startup.lua          # Main entry point
├── install.lua          # Installation script
├── version.txt          # Version information
└── musicplayer/         # Module directory
    ├── config.lua       # Configuration and constants
    ├── state.lua        # State management
    ├── ui.lua           # User interface rendering
    ├── input.lua        # Input handling (mouse, keyboard)
    ├── audio.lua        # Audio streaming and playback
    ├── network.lua      # HTTP requests and responses
    └── main.lua         # Main UI loop coordination
```

### Module Responsibilities

- **config.lua** - Centralized configuration, API URLs, UI colors, and constants
- **state.lua** - Global state initialization and management
- **ui.lua** - All rendering functions for tabs, buttons, sliders, and displays
- **input.lua** - Mouse click/drag handling and user interaction logic
- **audio.lua** - DFPWM audio streaming, speaker management, and playback control
- **network.lua** - HTTP request handling for search and audio downloads
- **main.lua** - UI event loop coordination and parallel processing

## How to Use

1. **Start the Player**: Run `startup` 
2. **Search for Music**: Click the "Search" tab and enter a song name or YouTube URL
3. **Play Music**: Click on search results to see playback options
4. **Control Playback**: Use the Now Playing tab for play/stop, skip, loop, and volume controls
5. **Manage Queue**: Add songs to queue or play them immediately

## Controls

### Now Playing Tab
- **Play/Stop Button** - Start or stop current playback
- **Skip Button** - Skip to next song in queue
- **Loop Button** - Cycle through loop modes (Off → Queue → Song)
- **Volume Slider** - Click and drag to adjust volume (0-100%)

### Search Tab
- **Search Box** - Enter song names or paste YouTube URLs
- **Search Results** - Click any result to see options:
  - **Play Now** - Immediately play and clear queue
  - **Play Next** - Add to front of queue
  - **Add to Queue** - Add to end of queue

## Technical Details

- Streams DFPWM audio directly from API
- Supports multiple speakers automatically
- Handles playlists by queueing all tracks
- Real-time volume adjustment
- Efficient parallel processing for smooth UI
- Modular design allows easy feature additions and maintenance

## Development

The modular architecture makes it easy to:
- Add new features by extending existing modules
- Modify UI elements without affecting audio logic
- Change network protocols without touching the interface
- Debug specific components in isolation
- Maintain clean separation of concerns

## Version

Current version: **2.1**

---

*This is a modern rewrite of the original cc-music-player with enhanced features, a completely new interface, and clean modular architecture.*
