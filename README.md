# Bognesferga Radio - ComputerCraft Music Bot

A comprehensive music player system for ComputerCraft with YouTube integration, radio hosting, and network radio client capabilities.

## Features

- **YouTube Music Player**: Search and play music from YouTube
- **Network Radio**: Connect to shared radio stations
- **Radio Host**: Create your own radio station for others to join
- **Modern UI**: Beautiful themed interface with component system
- **Advanced Monitor Support**: Touch-enabled interface for Advanced Monitors

## Installation

1. Place the `musicplayer` folder in your ComputerCraft computer
2. Run `lua startup.lua` to start the application
3. Connect speakers to enable audio playback

## Requirements

- ComputerCraft: Tweaked
- At least one speaker peripheral
- Internet access for YouTube functionality
- Advanced Monitor (optional, for touch interface)

## Code Architecture Analysis

### Original Working Code vs Current Modular Version

#### **Key Differences Identified:**

**1. Action Menu Drawing Logic**
- **Original**: Action menu drawn inline within `drawSearch()` function
- **Current**: Action menu separated into `drawSongActionMenu()` with complex redraw logic
- **Issue**: Multiple redraw calls overwriting the action menu

**2. Event Handling**
- **Original**: Simple, direct event handling in single `uiLoop()` function
- **Current**: Complex layered event processing with parallel functions
- **Issue**: Event conflicts and timing issues

**3. State Management**
- **Original**: Simple global variables (`in_search_result`, `clicked_result`, etc.)
- **Current**: State object with nested properties
- **Issue**: State synchronization problems

**4. UI Redraw Timing**
- **Original**: Direct `redrawScreen()` calls with immediate effect
- **Current**: Component-based drawing with multiple redraw triggers
- **Issue**: Race conditions between UI updates

#### **Critical Fixes Needed:**

1. **Action Menu Coordinates**: Original uses y=6,8,10,13 vs current y=10,12,14,16
2. **Redraw Logic**: Original draws action menu inline, current separates it
3. **Event Flow**: Original has simple click→action flow, current has complex parallel processing
4. **State Checks**: Original checks `in_search_result` once, current checks multiple times

#### **Working Original Action Menu Logic:**
```lua
-- In drawSearch() function:
if in_search_result == true then
    term.setBackgroundColor(colors.black)
    term.clear()
    -- Draw song info at y=2,3
    -- Draw buttons at y=6,8,10,13
end

-- In event handler:
if y == 6 then -- Play now
if y == 8 then -- Play next  
if y == 10 then -- Add to queue
if y == 13 then -- Cancel
```

#### **Current Broken Logic:**
```lua
-- In redrawScreen():
if state.in_search_result then
    drawSongActionMenu() -- Draws at y=10,12,14,16
    return
end

-- In event handler:
if y == 10 then -- Play now (wrong coordinates)
```

## API Configuration

- **Base URL**: `https://ipod-2to6magyna-uc.a.run.app/`
- **Version**: `2.1`
- **Default Volume**: `1.5`
- **Max Volume**: `3.0`

## File Structure

```
musicplayer/
├── startup.lua              # Main entry point
├── app_manager.lua          # Application state management
├── config.lua               # Configuration settings
├── core/                    # Core system modules
├── features/                # Feature implementations
│   ├── menu/               # Main menu system
│   ├── youtube/            # YouTube player (BROKEN - needs original logic)
│   └── radio/              # Radio client/host
├── ui/                     # UI components and themes
│   ├── components.lua      # Reusable UI components
│   ├── themes.lua          # Theme system
│   └── layouts/            # Feature-specific layouts
└── utils/                  # Utility functions
```

## Known Issues

### YouTube Player Action Menu (CRITICAL)
- **Status**: BROKEN
- **Cause**: Modular architecture conflicts with original working logic
- **Symptoms**: Search results visible, clicks detected, but action menu doesn't appear
- **Fix Required**: Restore original inline action menu drawing logic

### Event Handling Race Conditions
- **Status**: UNSTABLE  
- **Cause**: Complex parallel event processing
- **Fix Required**: Simplify to original direct event handling

## Troubleshooting

### No Audio
- Ensure speakers are connected to the computer
- Check volume settings (use volume slider in Now Playing tab)

### Search Not Working
- Verify internet connection
- Check if HTTP requests are enabled in ComputerCraft config

### Touch Events Not Working
- Ensure you're using an Advanced Monitor (made with gold)
- Right-click the monitor to generate touch events
- Regular monitors (made with stone) don't support touch

### Action Menu Not Appearing
- **KNOWN BUG**: Currently broken due to modular architecture conflicts
- **Workaround**: Use original single-file version until fixed
- **Fix in Progress**: Restoring original action menu logic

## Development Notes

The current modular architecture, while cleaner and more maintainable, has introduced several regressions compared to the original working single-file version. The primary issue is that the component-based UI system conflicts with the original direct terminal manipulation approach that was proven to work.

**Priority fixes needed:**
1. Restore original action menu drawing logic
2. Simplify event handling to match original
3. Fix coordinate mismatches
4. Resolve redraw timing issues

## License

This project is licensed under the MIT License - see the LICENSE file for details.
