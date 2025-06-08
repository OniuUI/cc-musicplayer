-- Bognesferga Radio Logging Configuration Utility
-- Simple tool to configure logging settings

local config = require("musicplayer/config")

local function drawHeader()
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Header
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.clearLine()
    local w, h = term.getSize()
    local title = "Bognesferga Radio - Logging Configuration"
    local startX = math.floor((w - #title) / 2) + 1
    term.setCursorPos(startX, 1)
    term.write(title)
    
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 3)
end

local function showCurrentConfig()
    term.setTextColor(colors.yellow)
    term.write("Current Logging Configuration:")
    term.setCursorPos(1, 5)
    
    term.setTextColor(colors.white)
    term.write("1. Save logs to files: ")
    term.setTextColor(config.logging.save_to_file and colors.lime or colors.red)
    term.write(config.logging.save_to_file and "ENABLED" or "DISABLED")
    
    term.setCursorPos(1, 6)
    term.setTextColor(colors.white)
    term.write("2. Log level: ")
    term.setTextColor(colors.cyan)
    term.write(config.logging.level)
    
    term.setCursorPos(1, 7)
    term.setTextColor(colors.white)
    term.write("3. Max buffer lines: ")
    term.setTextColor(colors.cyan)
    term.write(tostring(config.logging.max_buffer_lines))
    
    term.setCursorPos(1, 8)
    term.setTextColor(colors.white)
    term.write("4. Auto cleanup: ")
    term.setTextColor(config.logging.auto_cleanup.enabled and colors.lime or colors.red)
    term.write(config.logging.auto_cleanup.enabled and "ENABLED" or "DISABLED")
    
    if config.logging.auto_cleanup.enabled then
        term.setCursorPos(1, 9)
        term.setTextColor(colors.lightGray)
        term.write("   - Max log files: " .. config.logging.auto_cleanup.max_log_files)
        term.setCursorPos(1, 10)
        term.write("   - Max age (days): " .. config.logging.auto_cleanup.max_file_age_days)
    end
end

local function showMenu()
    local startY = config.logging.auto_cleanup.enabled and 12 or 10
    
    term.setCursorPos(1, startY)
    term.setTextColor(colors.yellow)
    term.write("Configuration Options:")
    
    term.setCursorPos(1, startY + 2)
    term.setTextColor(colors.white)
    term.write("[1] Toggle file saving (save disk space)")
    
    term.setCursorPos(1, startY + 3)
    term.write("[2] Change log level")
    
    term.setCursorPos(1, startY + 4)
    term.write("[3] Change buffer size")
    
    term.setCursorPos(1, startY + 5)
    term.write("[4] Toggle auto cleanup")
    
    term.setCursorPos(1, startY + 6)
    term.write("[5] Configure cleanup settings")
    
    term.setCursorPos(1, startY + 8)
    term.setTextColor(colors.lime)
    term.write("[S] Save configuration")
    
    term.setCursorPos(1, startY + 9)
    term.setTextColor(colors.red)
    term.write("[Q] Quit without saving")
    
    term.setCursorPos(1, startY + 11)
    term.setTextColor(colors.white)
    term.write("Choice: ")
end

local function saveConfig()
    -- Create a backup of the current config
    local configContent = {}
    
    table.insert(configContent, "-- Configuration and constants for the radio player")
    table.insert(configContent, "local config = {}")
    table.insert(configContent, "")
    table.insert(configContent, 'config.api_base_url = "' .. config.api_base_url .. '"')
    table.insert(configContent, 'config.version = "' .. config.version .. '"')
    table.insert(configContent, "config.default_volume = " .. config.default_volume)
    table.insert(configContent, "config.max_volume = " .. config.max_volume)
    table.insert(configContent, "config.chunk_size = " .. config.chunk_size)
    table.insert(configContent, "config.initial_read_size = " .. config.initial_read_size)
    table.insert(configContent, "")
    table.insert(configContent, "-- Logging Configuration")
    table.insert(configContent, "config.logging = {")
    table.insert(configContent, "    -- Enable/disable saving logs to files (set to false to save disk space)")
    table.insert(configContent, "    save_to_file = " .. tostring(config.logging.save_to_file) .. ",")
    table.insert(configContent, "    ")
    table.insert(configContent, '    -- Log level: "DEBUG", "INFO", "WARN", "ERROR", "FATAL"')
    table.insert(configContent, '    level = "' .. config.logging.level .. '",')
    table.insert(configContent, "    ")
    table.insert(configContent, "    -- Maximum number of log lines to keep in memory")
    table.insert(configContent, "    max_buffer_lines = " .. config.logging.max_buffer_lines .. ",")
    table.insert(configContent, "    ")
    table.insert(configContent, "    -- Log file settings (only used if save_to_file is true)")
    table.insert(configContent, '    session_log_file = "' .. config.logging.session_log_file .. '",')
    table.insert(configContent, '    emergency_log_file = "' .. config.logging.emergency_log_file .. '",')
    table.insert(configContent, "    ")
    table.insert(configContent, "    -- Automatic log cleanup (only if save_to_file is true)")
    table.insert(configContent, "    auto_cleanup = {")
    table.insert(configContent, "        enabled = " .. tostring(config.logging.auto_cleanup.enabled) .. ",")
    table.insert(configContent, "        max_log_files = " .. config.logging.auto_cleanup.max_log_files .. ",  -- Keep only the " .. config.logging.auto_cleanup.max_log_files .. " most recent log files")
    table.insert(configContent, "        max_file_age_days = " .. config.logging.auto_cleanup.max_file_age_days .. "  -- Delete log files older than " .. config.logging.auto_cleanup.max_file_age_days .. " days")
    table.insert(configContent, "    }")
    table.insert(configContent, "}")
    
    -- Add the rest of the config (branding and UI)
    table.insert(configContent, "")
    table.insert(configContent, "-- Branding Configuration")
    table.insert(configContent, "config.branding = {")
    table.insert(configContent, '    title = "' .. config.branding.title .. '",')
    table.insert(configContent, '    developer = "' .. config.branding.developer .. '",')
    table.insert(configContent, "    rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}")
    table.insert(configContent, "}")
    table.insert(configContent, "")
    table.insert(configContent, "-- UI Configuration")
    table.insert(configContent, "config.ui = {")
    table.insert(configContent, '    tabs = {" Now Playing ", " Search "},')
    table.insert(configContent, "    colors = {")
    table.insert(configContent, "        -- Main interface")
    table.insert(configContent, "        background = colors.black,")
    table.insert(configContent, "        header_bg = colors.blue,")
    table.insert(configContent, "        footer_bg = colors.gray,")
    table.insert(configContent, "        ")
    table.insert(configContent, "        -- Tabs")
    table.insert(configContent, "        tab_active = colors.white,")
    table.insert(configContent, "        tab_inactive = colors.lightGray,")
    table.insert(configContent, "        tab_bg = colors.blue,")
    table.insert(configContent, "        ")
    table.insert(configContent, "        -- Text colors")
    table.insert(configContent, "        text_primary = colors.white,")
    table.insert(configContent, "        text_secondary = colors.lightGray,")
    table.insert(configContent, "        text_disabled = colors.gray,")
    table.insert(configContent, "        text_accent = colors.yellow,")
    table.insert(configContent, "        text_success = colors.lime,")
    table.insert(configContent, "        text_error = colors.red,")
    table.insert(configContent, "        ")
    table.insert(configContent, "        -- Interactive elements")
    table.insert(configContent, "        button = colors.lightBlue,")
    table.insert(configContent, "        button_active = colors.cyan,")
    table.insert(configContent, "        button_hover = colors.blue,")
    table.insert(configContent, "        search_box = colors.lightGray,")
    table.insert(configContent, "        ")
    table.insert(configContent, "        -- Status colors")
    table.insert(configContent, "        playing = colors.lime,")
    table.insert(configContent, "        loading = colors.yellow,")
    table.insert(configContent, "        error = colors.red,")
    table.insert(configContent, "        ")
    table.insert(configContent, "        -- Volume slider")
    table.insert(configContent, "        volume_bg = colors.gray,")
    table.insert(configContent, "        volume_fill = colors.cyan,")
    table.insert(configContent, "        volume_text = colors.white")
    table.insert(configContent, "    }")
    table.insert(configContent, "}")
    table.insert(configContent, "")
    table.insert(configContent, "return config")
    
    -- Write to file
    local file = fs.open("musicplayer/config.lua", "w")
    if file then
        for _, line in ipairs(configContent) do
            file.writeLine(line)
        end
        file.close()
        return true
    else
        return false
    end
end

local function main()
    local modified = false
    
    while true do
        drawHeader()
        showCurrentConfig()
        showMenu()
        
        local input = read()
        
        if input == "1" then
            config.logging.save_to_file = not config.logging.save_to_file
            modified = true
        elseif input == "2" then
            term.setCursorPos(1, term.getCursorPos() + 1)
            term.setTextColor(colors.yellow)
            term.write("Log levels: DEBUG, INFO, WARN, ERROR, FATAL")
            term.setCursorPos(1, term.getCursorPos() + 1)
            term.setTextColor(colors.white)
            term.write("Enter new log level: ")
            local newLevel = read():upper()
            if newLevel == "DEBUG" or newLevel == "INFO" or newLevel == "WARN" or newLevel == "ERROR" or newLevel == "FATAL" then
                config.logging.level = newLevel
                modified = true
            else
                term.setTextColor(colors.red)
                term.write("Invalid log level! Press any key...")
                os.pullEvent("key")
            end
        elseif input == "3" then
            term.setCursorPos(1, term.getCursorPos() + 1)
            term.setTextColor(colors.white)
            term.write("Enter new buffer size (100-5000): ")
            local newSize = tonumber(read())
            if newSize and newSize >= 100 and newSize <= 5000 then
                config.logging.max_buffer_lines = newSize
                modified = true
            else
                term.setTextColor(colors.red)
                term.write("Invalid buffer size! Press any key...")
                os.pullEvent("key")
            end
        elseif input == "4" then
            config.logging.auto_cleanup.enabled = not config.logging.auto_cleanup.enabled
            modified = true
        elseif input == "5" then
            if config.logging.auto_cleanup.enabled then
                term.setCursorPos(1, term.getCursorPos() + 1)
                term.setTextColor(colors.white)
                term.write("Max log files to keep (1-20): ")
                local maxFiles = tonumber(read())
                if maxFiles and maxFiles >= 1 and maxFiles <= 20 then
                    config.logging.auto_cleanup.max_log_files = maxFiles
                    
                    term.setCursorPos(1, term.getCursorPos() + 1)
                    term.write("Max age in days (1-30): ")
                    local maxAge = tonumber(read())
                    if maxAge and maxAge >= 1 and maxAge <= 30 then
                        config.logging.auto_cleanup.max_file_age_days = maxAge
                        modified = true
                    else
                        term.setTextColor(colors.red)
                        term.write("Invalid age! Press any key...")
                        os.pullEvent("key")
                    end
                else
                    term.setTextColor(colors.red)
                    term.write("Invalid file count! Press any key...")
                    os.pullEvent("key")
                end
            else
                term.setTextColor(colors.red)
                term.write("Auto cleanup is disabled! Enable it first. Press any key...")
                os.pullEvent("key")
            end
        elseif input:upper() == "S" then
            if modified then
                term.setCursorPos(1, term.getCursorPos() + 1)
                term.setTextColor(colors.yellow)
                term.write("Saving configuration...")
                
                if saveConfig() then
                    term.setTextColor(colors.lime)
                    term.write(" SUCCESS!")
                    term.setCursorPos(1, term.getCursorPos() + 1)
                    term.setTextColor(colors.white)
                    term.write("Configuration saved. Restart Bognesferga Radio to apply changes.")
                else
                    term.setTextColor(colors.red)
                    term.write(" FAILED!")
                    term.setCursorPos(1, term.getCursorPos() + 1)
                    term.setTextColor(colors.white)
                    term.write("Could not save configuration file.")
                end
                
                term.setCursorPos(1, term.getCursorPos() + 1)
                term.write("Press any key to exit...")
                os.pullEvent("key")
                break
            else
                term.setCursorPos(1, term.getCursorPos() + 1)
                term.setTextColor(colors.yellow)
                term.write("No changes to save. Press any key...")
                os.pullEvent("key")
            end
        elseif input:upper() == "Q" then
            if modified then
                term.setCursorPos(1, term.getCursorPos() + 1)
                term.setTextColor(colors.red)
                term.write("You have unsaved changes! Are you sure? (y/N): ")
                local confirm = read()
                if confirm:upper() == "Y" then
                    break
                end
            else
                break
            end
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    print("Logging configuration utility closed.")
end

main() 