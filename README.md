# iPod-Style Music Player for ComputerCraft

A modern, feature-rich music player for ComputerCraft/CC Tweaked that brings YouTube streaming directly to your Minecraft computers.

## Features

- 🎵 **YouTube Search & Streaming** - Search and play any song from YouTube
- 📱 **Modern Touch Interface** - Intuitive click-based UI with tabs
- 🎧 **Queue Management** - Add songs to queue, play next, or play now
- 🔊 **Volume Controls** - Visual volume slider with real-time adjustment
- 🔄 **Loop Modes** - Loop off, loop queue, or loop single song
- 📋 **Playlist Support** - Automatically handles YouTube playlists
- 🎨 **Clean UI** - Two-tab interface: Now Playing and Search

## Installation

### Easy Installation (Recommended)

Run this command in any ComputerCraft computer:

```lua
pastebin get <YOUR_PASTEBIN_ID> install
install
```

### Manual Installation

1. Download `startup.lua` from this repository
2. Place it in your ComputerCraft computer
3. Run `startup` to begin

## Requirements

- ComputerCraft or CC Tweaked
- Connected speaker(s)
- Internet connection (HTTP enabled)

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

## Version

Current version: **2.1**

---

*This is a modern rewrite of the original cc-music-player with enhanced features and a completely new interface.*
