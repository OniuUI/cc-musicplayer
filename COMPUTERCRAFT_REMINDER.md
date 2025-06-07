# ⚠️ CRITICAL REMINDER: THIS IS COMPUTERCRAFT CODE ⚠️

## DO NOT TRY TO RUN AS REGULAR LUA!

This project is designed for **ComputerCraft** (Minecraft mod), NOT regular Lua.

### ❌ NEVER DO THIS:
- `lua startup.lua`
- `lua -c "dofile('file.lua')"`
- Any regular Lua commands

### ✅ HOW TO ACTUALLY TEST:
1. **In ComputerCraft (Minecraft):**
   - Place files in computer
   - Run: `startup` (not `lua startup.lua`)
   - Use ComputerCraft's built-in Lua environment

### 🔧 ComputerCraft-Specific APIs Used:
- `peripheral.wrap()` - for modems/speakers
- `os.pullEvent("modem_message")` - for radio communication
- `http.get()` - for YouTube API calls
- `term.setCursorPos()` - for UI drawing
- `colors.*` - for terminal colors
- `textutils.urlEncode()` - for URL encoding
- `require("cc.audio.dfpwm")` - for audio decoding

### 📁 Project Structure:
- `startup.lua` - Main entry point (run with `startup` in CC)
- `musicplayer/` - All modules and features
- Radio features are complete and ready for ComputerCraft testing

### 🎯 Current Status:
- ✅ YouTube Player - Working
- ✅ Radio Host - Complete (needs CC testing)
- ✅ Radio Client - Complete (needs CC testing)
- ✅ Network Protocol - Complete (needs CC testing)

**STOP TRYING TO RUN THIS IN REGULAR LUA!** 