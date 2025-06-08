-- Configuration and constants for the radio player
local config = {}

config.api_base_url = "https://ipod-2to6magyna-uc.a.run.app/"
config.version = "2.1"
config.default_volume = 1.5
config.max_volume = 3.0
config.chunk_size = 16 * 1024 - 4
config.initial_read_size = 4

-- Logging Configuration
config.logging = {
    -- Enable/disable saving logs to files (set to false to save disk space)
    save_to_file = false,
    
    -- Log level: "DEBUG", "INFO", "WARN", "ERROR", "FATAL"
    level = "INFO",
    
    -- Maximum number of log lines to keep in memory
    max_buffer_lines = 1000,
    
    -- Log file settings (only used if save_to_file is true)
    session_log_file = "musicplayer/logs/session.log",
    emergency_log_file = "musicplayer/logs/emergency.log",
    
    -- Automatic log cleanup (only if save_to_file is true)
    auto_cleanup = {
        enabled = true,
        max_log_files = 5,  -- Keep only the 5 most recent log files
        max_file_age_days = 7  -- Delete log files older than 7 days
    }
}

-- Branding Configuration
config.branding = {
    title = "Bognesferga Radio",
    developer = "Developed by Forty",
    rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
}

-- UI Configuration
config.ui = {
    tabs = {" Now Playing ", " Search "},
    colors = {
        -- Main interface
        background = colors.black,
        header_bg = colors.blue,
        footer_bg = colors.gray,
        
        -- Tabs
        tab_active = colors.white,
        tab_inactive = colors.lightGray,
        tab_bg = colors.blue,
        
        -- Text colors
        text_primary = colors.white,
        text_secondary = colors.lightGray,
        text_disabled = colors.gray,
        text_accent = colors.yellow,
        text_success = colors.lime,
        text_error = colors.red,
        
        -- Interactive elements
        button = colors.lightBlue,
        button_active = colors.cyan,
        button_hover = colors.blue,
        search_box = colors.lightGray,
        
        -- Status colors
        playing = colors.lime,
        loading = colors.yellow,
        error = colors.red,
        
        -- Volume slider
        volume_bg = colors.gray,
        volume_fill = colors.cyan,
        volume_text = colors.white
    }
}

-- Audio processing configuration
config.audio = {
    -- Audio processing settings
    processing_enabled = true,  -- Enable/disable audio processing by default
    default_bass = 0,          -- Default bass level (-10 to +10)
    default_treble = 0,        -- Default treble level (-10 to +10)
    
    -- Audio quality settings
    enable_filters = true,     -- Enable bass/treble filtering
    filter_quality = "medium", -- "low", "medium", "high" (affects CPU usage)
    
    -- Volume settings
    normalize_volume = true,   -- Normalize volume across different audio sources
    dynamic_range = true       -- Preserve dynamic range in audio processing
}

-- Radio Synchronization Configuration (PRE-Buffer System)
config.radio_sync = {
    -- Buffer settings
    buffer_duration = 45,        -- Seconds of audio to buffer
    chunk_duration = 0.5,        -- Duration of each audio chunk
    safety_margin = 5,           -- Extra buffer time for safety
    
    -- Latency management
    max_client_latency = 2000,   -- Max allowed latency (ms)
    latency_samples = 10,        -- Number of samples for average
    ping_interval = 5,           -- Seconds between latency measurements
    
    -- Sync behavior
    sync_tolerance = 100,        -- Acceptable drift (ms)
    resync_threshold = 500,      -- Force resync if drift exceeds this
    slow_client_timeout = 30,    -- Remove clients that can't keep up
    
    -- Performance
    enable_compression = true,   -- Compress audio chunks
    adaptive_quality = true,     -- Reduce quality for slow clients
    predictive_buffering = true  -- Pre-load next song
}

return config 