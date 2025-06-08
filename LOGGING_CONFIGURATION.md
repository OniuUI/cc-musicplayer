# Logging Configuration Guide

Bognesferga Radio now includes configurable logging to help you manage disk space and customize logging behavior.

## Quick Start

### Disable Log File Saving (Save Disk Space)
If you're running out of disk space, you can disable log file saving:

1. Run `configure_logging` in your ComputerCraft terminal
2. Press `1` to toggle file saving to **DISABLED**
3. Press `S` to save the configuration
4. Restart Bognesferga Radio

When file saving is disabled:
- ✅ Logs still appear on the debug monitor (if you have one)
- ✅ Logs are kept in memory for viewing
- ✅ Critical errors still display on the main terminal
- ❌ No log files are written to disk
- ❌ No disk space is used for logs

### Quick Configuration Tool
Run the configuration utility:
```
configure_logging
```

This provides an easy-to-use interface for changing all logging settings.

## Configuration Options

### File Saving (`save_to_file`)
- **Default:** `true`
- **Purpose:** Controls whether logs are saved to files
- **Disk Impact:** When `false`, saves significant disk space

### Log Level (`level`)
- **Options:** `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`, `"FATAL"`
- **Default:** `"INFO"`
- **Purpose:** Controls which messages are logged
- **Recommendation:** Use `"ERROR"` to reduce log volume

### Buffer Size (`max_buffer_lines`)
- **Default:** `1000`
- **Range:** `100-5000`
- **Purpose:** How many log lines to keep in memory
- **Impact:** Higher values use more memory but keep more history

### Auto Cleanup (`auto_cleanup`)
- **Default:** `enabled: true`
- **Purpose:** Automatically removes old log files
- **Settings:**
  - `max_log_files`: Keep only the N most recent files (default: 5)
  - `max_file_age_days`: Delete files older than N days (default: 7)

## Manual Configuration

You can also edit `musicplayer/config.lua` directly:

```lua
config.logging = {
    -- Disable file saving to save disk space
    save_to_file = false,
    
    -- Only log errors and critical issues
    level = "ERROR",
    
    -- Smaller buffer to save memory
    max_buffer_lines = 500,
    
    -- File settings (ignored if save_to_file is false)
    session_log_file = "musicplayer/logs/session.log",
    emergency_log_file = "musicplayer/logs/emergency.log",
    
    -- Auto cleanup settings
    auto_cleanup = {
        enabled = true,
        max_log_files = 3,      -- Keep only 3 log files
        max_file_age_days = 3   -- Delete files older than 3 days
    }
}
```

## Disk Space Recommendations

### Minimal Disk Usage
```lua
config.logging = {
    save_to_file = false,           -- No files written
    level = "ERROR",                -- Only critical messages
    max_buffer_lines = 100,         -- Minimal memory usage
    auto_cleanup = { enabled = false }
}
```

### Balanced Configuration
```lua
config.logging = {
    save_to_file = true,            -- Keep some logs
    level = "WARN",                 -- Important messages only
    max_buffer_lines = 500,         -- Moderate memory usage
    auto_cleanup = {
        enabled = true,
        max_log_files = 3,          -- Keep 3 recent files
        max_file_age_days = 3       -- Delete after 3 days
    }
}
```

### Full Logging (Default)
```lua
config.logging = {
    save_to_file = true,            -- Full file logging
    level = "INFO",                 -- All normal messages
    max_buffer_lines = 1000,        -- Full history
    auto_cleanup = {
        enabled = true,
        max_log_files = 5,          -- Keep 5 recent files
        max_file_age_days = 7       -- Delete after 1 week
    }
}
```

## Log File Locations

When file saving is enabled, logs are stored in:
- `musicplayer/logs/session.log` - Current session logs
- `musicplayer/logs/emergency.log` - Critical errors only
- `musicplayer/logs/` - Auto-cleanup manages old files here

## Troubleshooting

### "Running out of space" Error
1. Run `configure_logging`
2. Set file saving to **DISABLED**
3. Save and restart

### Can't see any logs
- Check if you have a debug monitor attached
- Logs appear on the second monitor if available
- Critical errors always show on the main terminal

### Lost important logs
- Emergency logs are always saved (even when file saving is disabled for fatal errors)
- Check `musicplayer/logs/emergency.log`
- Increase buffer size to keep more logs in memory

### Configuration not working
- Make sure to restart Bognesferga Radio after changing settings
- Check that `musicplayer/config.lua` was saved correctly
- Use the `configure_logging` tool instead of manual editing

## Advanced Usage

### Temporary Debug Mode
To temporarily enable debug logging without changing the config:
1. Edit `musicplayer/config.lua`
2. Change `level = "DEBUG"`
3. Restart the application
4. Change back to `"INFO"` or `"ERROR"` when done

### Custom Log Locations
You can change where logs are saved by editing the file paths in the config:
```lua
session_log_file = "custom/path/session.log",
emergency_log_file = "custom/path/emergency.log",
```

### Monitor-Only Logging
For setups with a dedicated debug monitor but limited disk space:
```lua
config.logging = {
    save_to_file = false,     -- No disk usage
    level = "DEBUG",          -- Full debug info on monitor
    max_buffer_lines = 2000,  -- Large buffer for monitor display
}
```

This gives you full logging visibility without using any disk space. 