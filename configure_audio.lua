-- Audio Configuration Utility for Bognesferga Radio
-- Interactive tool to configure bass, treble, and audio processing settings

local config = require("musicplayer/config")

-- Configuration state
local audioConfig = {
    processing_enabled = config.audio.processing_enabled,
    default_bass = config.audio.default_bass,
    default_treble = config.audio.default_treble,
    enable_filters = config.audio.enable_filters,
    filter_quality = config.audio.filter_quality,
    normalize_volume = config.audio.normalize_volume,
    dynamic_range = config.audio.dynamic_range
}

-- UI state
local selectedOption = 1
local maxOptions = 7

-- Color scheme
local colors = {
    bg = colors.black,
    header = colors.yellow,
    text = colors.white,
    accent = colors.cyan,
    button = colors.lightBlue,
    buttonText = colors.black,
    enabled = colors.lime,
    disabled = colors.red,
    value = colors.orange
}

-- Clear screen and set up
local function setupScreen()
    term.setBackgroundColor(colors.bg)
    term.clear()
    term.setCursorPos(1, 1)
end

-- Draw header
local function drawHeader()
    term.setBackgroundColor(colors.bg)
    term.setTextColor(colors.header)
    term.setCursorPos(1, 1)
    term.clearLine()
    
    local title = "🎵 Audio Configuration Utility 🎵"
    local width, _ = term.getSize()
    local x = math.floor((width - #title) / 2) + 1
    term.setCursorPos(x, 1)
    term.write(title)
    
    term.setTextColor(colors.text)
    term.setCursorPos(1, 2)
    term.write(string.rep("=", width))
end

-- Draw current settings
local function drawSettings()
    term.setBackgroundColor(colors.bg)
    term.setTextColor(colors.text)
    
    -- Current settings header
    term.setCursorPos(2, 4)
    term.setTextColor(colors.header)
    term.write("Current Audio Settings:")
    
    local y = 6
    
    -- Audio processing enabled
    term.setCursorPos(4, y)
    term.setTextColor(colors.text)
    term.write("1. Audio Processing: ")
    term.setTextColor(audioConfig.processing_enabled and colors.enabled or colors.disabled)
    term.write(audioConfig.processing_enabled and "ENABLED" or "DISABLED")
    if selectedOption == 1 then
        term.setTextColor(colors.accent)
        term.write(" <--")
    end
    y = y + 1
    
    -- Bass level
    term.setCursorPos(4, y)
    term.setTextColor(colors.text)
    term.write("2. Bass Level: ")
    term.setTextColor(colors.value)
    local bassStr = audioConfig.default_bass > 0 and ("+" .. audioConfig.default_bass) or tostring(audioConfig.default_bass)
    term.write(bassStr)
    if selectedOption == 2 then
        term.setTextColor(colors.accent)
        term.write(" <--")
    end
    y = y + 1
    
    -- Treble level
    term.setCursorPos(4, y)
    term.setTextColor(colors.text)
    term.write("3. Treble Level: ")
    term.setTextColor(colors.value)
    local trebleStr = audioConfig.default_treble > 0 and ("+" .. audioConfig.default_treble) or tostring(audioConfig.default_treble)
    term.write(trebleStr)
    if selectedOption == 3 then
        term.setTextColor(colors.accent)
        term.write(" <--")
    end
    y = y + 1
    
    -- Enable filters
    term.setCursorPos(4, y)
    term.setTextColor(colors.text)
    term.write("4. Audio Filters: ")
    term.setTextColor(audioConfig.enable_filters and colors.enabled or colors.disabled)
    term.write(audioConfig.enable_filters and "ENABLED" or "DISABLED")
    if selectedOption == 4 then
        term.setTextColor(colors.accent)
        term.write(" <--")
    end
    y = y + 1
    
    -- Filter quality
    term.setCursorPos(4, y)
    term.setTextColor(colors.text)
    term.write("5. Filter Quality: ")
    term.setTextColor(colors.value)
    term.write(string.upper(audioConfig.filter_quality))
    if selectedOption == 5 then
        term.setTextColor(colors.accent)
        term.write(" <--")
    end
    y = y + 1
    
    -- Volume normalization
    term.setCursorPos(4, y)
    term.setTextColor(colors.text)
    term.write("6. Volume Normalization: ")
    term.setTextColor(audioConfig.normalize_volume and colors.enabled or colors.disabled)
    term.write(audioConfig.normalize_volume and "ENABLED" or "DISABLED")
    if selectedOption == 6 then
        term.setTextColor(colors.accent)
        term.write(" <--")
    end
    y = y + 1
    
    -- Dynamic range
    term.setCursorPos(4, y)
    term.setTextColor(colors.text)
    term.write("7. Dynamic Range: ")
    term.setTextColor(audioConfig.dynamic_range and colors.enabled or colors.disabled)
    term.write(audioConfig.dynamic_range and "ENABLED" or "DISABLED")
    if selectedOption == 7 then
        term.setTextColor(colors.accent)
        term.write(" <--")
    end
end

-- Draw controls
local function drawControls()
    local width, height = term.getSize()
    
    term.setBackgroundColor(colors.bg)
    term.setTextColor(colors.header)
    term.setCursorPos(2, height - 8)
    term.write("Controls:")
    
    term.setTextColor(colors.text)
    term.setCursorPos(4, height - 6)
    term.write("↑/↓ - Navigate options")
    term.setCursorPos(4, height - 5)
    term.write("←/→ - Adjust values")
    term.setCursorPos(4, height - 4)
    term.write("Enter - Toggle boolean options")
    term.setCursorPos(4, height - 3)
    term.write("S - Save configuration")
    term.setCursorPos(4, height - 2)
    term.write("Q - Quit without saving")
end

-- Draw the complete UI
local function drawUI()
    setupScreen()
    drawHeader()
    drawSettings()
    drawControls()
end

-- Handle input
local function handleInput()
    while true do
        drawUI()
        
        local event, key = os.pullEvent("key")
        
        if key == keys.up then
            selectedOption = selectedOption - 1
            if selectedOption < 1 then
                selectedOption = maxOptions
            end
        elseif key == keys.down then
            selectedOption = selectedOption + 1
            if selectedOption > maxOptions then
                selectedOption = 1
            end
        elseif key == keys.left then
            -- Decrease values
            if selectedOption == 2 then -- Bass
                audioConfig.default_bass = math.max(-10, audioConfig.default_bass - 1)
            elseif selectedOption == 3 then -- Treble
                audioConfig.default_treble = math.max(-10, audioConfig.default_treble - 1)
            elseif selectedOption == 5 then -- Filter quality
                local qualities = {"low", "medium", "high"}
                for i, quality in ipairs(qualities) do
                    if audioConfig.filter_quality == quality then
                        audioConfig.filter_quality = qualities[math.max(1, i - 1)]
                        break
                    end
                end
            end
        elseif key == keys.right then
            -- Increase values
            if selectedOption == 2 then -- Bass
                audioConfig.default_bass = math.min(10, audioConfig.default_bass + 1)
            elseif selectedOption == 3 then -- Treble
                audioConfig.default_treble = math.min(10, audioConfig.default_treble + 1)
            elseif selectedOption == 5 then -- Filter quality
                local qualities = {"low", "medium", "high"}
                for i, quality in ipairs(qualities) do
                    if audioConfig.filter_quality == quality then
                        audioConfig.filter_quality = qualities[math.min(#qualities, i + 1)]
                        break
                    end
                end
            end
        elseif key == keys.enter then
            -- Toggle boolean options
            if selectedOption == 1 then
                audioConfig.processing_enabled = not audioConfig.processing_enabled
            elseif selectedOption == 4 then
                audioConfig.enable_filters = not audioConfig.enable_filters
            elseif selectedOption == 6 then
                audioConfig.normalize_volume = not audioConfig.normalize_volume
            elseif selectedOption == 7 then
                audioConfig.dynamic_range = not audioConfig.dynamic_range
            end
        elseif key == keys.s then
            -- Save configuration
            return "save"
        elseif key == keys.q then
            -- Quit without saving
            return "quit"
        end
    end
end

-- Save configuration to file
local function saveConfiguration()
    -- Update the config
    config.audio.processing_enabled = audioConfig.processing_enabled
    config.audio.default_bass = audioConfig.default_bass
    config.audio.default_treble = audioConfig.default_treble
    config.audio.enable_filters = audioConfig.enable_filters
    config.audio.filter_quality = audioConfig.filter_quality
    config.audio.normalize_volume = audioConfig.normalize_volume
    config.audio.dynamic_range = audioConfig.dynamic_range
    
    -- Write updated config to file
    local configFile = fs.open("musicplayer/config.lua", "w")
    if configFile then
        configFile.write("-- Configuration file for Bognesferga Radio\n")
        configFile.write("-- This file contains all the settings for the music bot system\n\n")
        configFile.write("local config = {}\n\n")
        
        -- Write basic config
        configFile.write("-- Basic configuration\n")
        configFile.write("config.default_volume = " .. config.default_volume .. "\n")
        configFile.write("config.max_volume = " .. config.max_volume .. "\n")
        configFile.write("config.debug_mode = " .. tostring(config.debug_mode) .. "\n")
        configFile.write("config.auto_start = " .. tostring(config.auto_start) .. "\n\n")
        
        -- Write logging config
        configFile.write("-- Logging configuration\n")
        configFile.write("config.logging = {\n")
        configFile.write("    save_to_file = " .. tostring(config.logging.save_to_file) .. ",\n")
        configFile.write("    level = \"" .. config.logging.level .. "\",\n")
        configFile.write("    max_buffer_lines = " .. config.logging.max_buffer_lines .. ",\n")
        configFile.write("    session_log_path = \"" .. config.logging.session_log_path .. "\",\n")
        configFile.write("    emergency_log_path = \"" .. config.logging.emergency_log_path .. "\",\n")
        configFile.write("    auto_cleanup = {\n")
        configFile.write("        enabled = " .. tostring(config.logging.auto_cleanup.enabled) .. ",\n")
        configFile.write("        max_files = " .. config.logging.auto_cleanup.max_files .. ",\n")
        configFile.write("        max_age_days = " .. config.logging.auto_cleanup.max_age_days .. "\n")
        configFile.write("    }\n")
        configFile.write("}\n\n")
        
        -- Write audio config
        configFile.write("-- Audio processing configuration\n")
        configFile.write("config.audio = {\n")
        configFile.write("    -- Audio processing settings\n")
        configFile.write("    processing_enabled = " .. tostring(audioConfig.processing_enabled) .. ",\n")
        configFile.write("    default_bass = " .. audioConfig.default_bass .. ",\n")
        configFile.write("    default_treble = " .. audioConfig.default_treble .. ",\n")
        configFile.write("    \n")
        configFile.write("    -- Audio quality settings\n")
        configFile.write("    enable_filters = " .. tostring(audioConfig.enable_filters) .. ",\n")
        configFile.write("    filter_quality = \"" .. audioConfig.filter_quality .. "\",\n")
        configFile.write("    \n")
        configFile.write("    -- Volume settings\n")
        configFile.write("    normalize_volume = " .. tostring(audioConfig.normalize_volume) .. ",\n")
        configFile.write("    dynamic_range = " .. tostring(audioConfig.dynamic_range) .. "\n")
        configFile.write("}\n\n")
        
        configFile.write("return config\n")
        configFile.close()
        
        return true
    end
    
    return false
end

-- Main function
local function main()
    setupScreen()
    
    term.setTextColor(colors.header)
    term.setCursorPos(1, 1)
    print("🎵 Audio Configuration Utility 🎵")
    print()
    term.setTextColor(colors.text)
    print("This utility allows you to configure audio processing settings")
    print("for the Bognesferga Radio system.")
    print()
    print("Press any key to continue...")
    os.pullEvent("key")
    
    local result = handleInput()
    
    setupScreen()
    
    if result == "save" then
        term.setTextColor(colors.header)
        print("💾 Saving Configuration...")
        print()
        
        if saveConfiguration() then
            term.setTextColor(colors.enabled)
            print("✅ Configuration saved successfully!")
            print()
            term.setTextColor(colors.text)
            print("Audio settings have been updated:")
            print("• Processing: " .. (audioConfig.processing_enabled and "Enabled" or "Disabled"))
            print("• Bass: " .. (audioConfig.default_bass > 0 and ("+" .. audioConfig.default_bass) or tostring(audioConfig.default_bass)))
            print("• Treble: " .. (audioConfig.default_treble > 0 and ("+" .. audioConfig.default_treble) or tostring(audioConfig.default_treble)))
            print("• Filters: " .. (audioConfig.enable_filters and "Enabled" or "Disabled"))
            print("• Quality: " .. string.upper(audioConfig.filter_quality))
            print()
            print("Restart the music system for changes to take effect.")
        else
            term.setTextColor(colors.disabled)
            print("❌ Failed to save configuration!")
            print("Please check file permissions and try again.")
        end
    else
        term.setTextColor(colors.header)
        print("🚫 Configuration Not Saved")
        print()
        term.setTextColor(colors.text)
        print("No changes were made to the audio configuration.")
    end
    
    print()
    print("Press any key to exit...")
    os.pullEvent("key")
end

-- Run the utility
main() 