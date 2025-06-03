# Bognesferga Radio for ComputerCraft

A modern, feature-rich radio player for ComputerCraft/CC Tweaked that brings YouTube streaming directly to your Minecraft computers. Built with a clean, modular architecture for easy maintenance and extensibility.

## Features

- **YouTube Integration**: Search and stream music directly from YouTube
- **Modern Touch Interface**: Clean, intuitive UI with two main tabs
- **Queue Management**: Add songs to play now, next, or at the end of queue
- **Volume Control**: Visual slider with real-time adjustment
- **Loop Modes**: Off, queue loop, or single song loop
- **Playlist Support**: Paste YouTube playlist links for automatic queueing
- **Multi-Speaker Support**: Automatically detects and uses connected speakers
- **DFPWM Audio Streaming**: High-quality audio playback
- **Modular Architecture**: Clean code separation for easy maintenance

## Installation

Run this command on any ComputerCraft computer:

```lua
pastebin get YzZzdRrm download
```

## Usage

After installation, simply run:
```lua
startup
```

### Interface

The radio player features a modern two-tab interface:

1. **Now Playing Tab**: Shows current song, playback controls, volume slider, and queue
2. **Search Tab**: YouTube search functionality and results

### Controls

- **Play/Stop**: Start or stop playback
- **Skip**: Skip to next song in queue
- **Loop**: Cycle through loop modes (Off → Queue → Song)
- **Volume Slider**: Click to adjust volume (0-100%)
- **Search**: Type to search YouTube or paste video/playlist URLs

## Architecture

The radio player is built with a modular architecture:

- **startup.lua**: Main entry point and module loader
- **musicplayer/config.lua**: Configuration and constants
- **musicplayer/state.lua**: Global state management  
- **musicplayer/ui.lua**: All rendering and drawing functions
- **musicplayer/input.lua**: Mouse/keyboard input handling
- **musicplayer/audio.lua**: Audio streaming and playback logic
- **musicplayer/network.lua**: HTTP request/response handling
- **musicplayer/main.lua**: UI loop coordination

This modular design makes the codebase:
- **Easy to maintain**: Each module has a single responsibility
- **Simple to debug**: Issues can be isolated to specific modules
- **Extensible**: New features can be added without touching existing code
- **Readable**: Clean separation makes the code self-documenting

## Requirements

- ComputerCraft or CC: Tweaked
- Internet connection for YouTube streaming
- Speaker peripheral (automatically detected)
- Advanced Computer (for color display)

## API

The radio player uses a custom API endpoint for YouTube integration. The modular design allows easy switching to different backends if needed.

## Development

To contribute or modify:

1. Each module is self-contained with clear interfaces
2. State management is centralized in `state.lua`
3. UI rendering is separated from logic
4. Network operations are isolated for easy testing
5. Configuration is externalized for easy customization

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

- Original concept inspired by music streaming applications
- Built for the ComputerCraft/CC: Tweaked community
- Developed by Forty
