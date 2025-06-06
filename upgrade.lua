-- Bognesferga Radio Force Upgrade System
-- Simple, clean upgrade that wipes everything and pulls fresh from GitHub

local baseUri = "https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/"

-- Upgrade configuration
local CURRENT_VERSION_FILE = "version.txt"
local BACKUP_DIR = "backups"
local LOG_FILE = "musicplayer/logs/upgrade.log"

-- Utility functions
local function trim(str)
    return str:match("^%s*(.-)%s*$")
end

local function colorPrint(text, color)
    term.setTextColor(color or colors.white)
    print(text)
end

local function drawBanner()
    term.clear()
    term.setCursorPos(1, 1)
    
    term.setBackgroundColor(colors.orange)
    term.setTextColor(colors.white)
    term.clearLine()
    local w, h = term.getSize()
    
    local bannerText = "  Bognesferga Radio Force Upgrader  "
    local startX = math.floor((w - #bannerText) / 2) + 1
    term.setCursorPos(startX, 1)
    term.write(bannerText)
    
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 3)
    
    term.setTextColor(colors.yellow)
    local devText = "Clean Install by Forty"
    local centerX = math.floor((w - #devText) / 2) + 1
    term.setCursorPos(centerX, 3)
    term.write(devText)
    
    term.setCursorPos(1, 5)
    term.setTextColor(colors.lightGray)
    local line = string.rep("=", w)
    term.write(line)
    
    term.setCursorPos(1, 7)
end

local function logMessage(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    if not fs.exists("musicplayer") then
        fs.makeDir("musicplayer")
    end
    if not fs.exists("musicplayer/logs") then
        fs.makeDir("musicplayer/logs")
    end
    
    local file = fs.open(LOG_FILE, "a")
    if file then
        file.writeLine("[" .. timestamp .. "] " .. message)
        file.close()
    end
end

-- Get current version for backup naming
local function getCurrentVersion()
    if fs.exists(CURRENT_VERSION_FILE) then
        local file = fs.open(CURRENT_VERSION_FILE, "r")
        if file then
            local version = trim(file.readAll())
            file.close()
            return version
        end
    end
    return "unknown"
end

-- Create backup before wiping
local function createBackup()
    local currentVersion = getCurrentVersion()
    local backupPath = BACKUP_DIR .. "/v" .. currentVersion .. "_" .. os.date("%Y%m%d_%H%M%S")
    
    colorPrint("Creating backup in " .. backupPath .. "...", colors.yellow)
    
    if not fs.exists(BACKUP_DIR) then
        fs.makeDir(BACKUP_DIR)
    end
    fs.makeDir(backupPath)
    
    -- Files to backup
    local criticalFiles = {
        "startup.lua",
        "version.txt",
        "musicplayer"
    }
    
    local backedUpCount = 0
    for _, item in ipairs(criticalFiles) do
        if fs.exists(item) then
            fs.copy(item, backupPath .. "/" .. item)
            colorPrint("✓ Backed up: " .. item, colors.lime)
            backedUpCount = backedUpCount + 1
        end
    end
    
    logMessage("Created backup: " .. backupPath .. " (" .. backedUpCount .. " items)")
    return backupPath
end

-- Wipe all existing files
local function wipeFiles()
    colorPrint("Wiping existing installation...", colors.red)
    
    local filesToWipe = {
        "startup.lua",
        "version.txt", 
        "musicplayer",
        "install.lua",
        "uninstall.lua"
    }
    
    for _, item in ipairs(filesToWipe) do
        if fs.exists(item) then
            fs.delete(item)
            colorPrint("✗ Deleted: " .. item, colors.red)
        end
    end
    
    logMessage("Wiped existing installation")
end

-- Complete file list for fresh install
local function getFileList()
    return {
        -- Core files
        {name = "startup.lua", url = baseUri .. "startup.lua", path = "startup.lua"},
        {name = "version.txt", url = baseUri .. "version.txt", path = "version.txt"},
        {name = "install.lua", url = baseUri .. "install.lua", path = "install.lua"},
        {name = "uninstall.lua", url = baseUri .. "uninstall.lua", path = "uninstall.lua"},
        {name = "upgrade.lua", url = baseUri .. "upgrade.lua", path = "upgrade.lua"},
        
        -- Core system modules
        {name = "system.lua", url = baseUri .. "musicplayer/core/system.lua", path = "musicplayer/core/system.lua"},
        
        -- UI modules
        {name = "themes.lua", url = baseUri .. "musicplayer/ui/themes.lua", path = "musicplayer/ui/themes.lua"},
        {name = "components.lua", url = baseUri .. "musicplayer/ui/components.lua", path = "musicplayer/ui/components.lua"},
        {name = "youtube.lua", url = baseUri .. "musicplayer/ui/layouts/youtube.lua", path = "musicplayer/ui/layouts/youtube.lua"},
        {name = "radio.lua", url = baseUri .. "musicplayer/ui/layouts/radio.lua", path = "musicplayer/ui/layouts/radio.lua"},
        
        -- Audio modules
        {name = "speaker_manager.lua", url = baseUri .. "musicplayer/audio/speaker_manager.lua", path = "musicplayer/audio/speaker_manager.lua"},
        
        -- Network modules
        {name = "http_client.lua", url = baseUri .. "musicplayer/network/http_client.lua", path = "musicplayer/network/http_client.lua"},
        {name = "radio_protocol.lua", url = baseUri .. "musicplayer/network/radio_protocol.lua", path = "musicplayer/network/radio_protocol.lua"},
        
        -- Utilities
        {name = "common.lua", url = baseUri .. "musicplayer/utils/common.lua", path = "musicplayer/utils/common.lua"},
        
        -- Middleware
        {name = "error_handler.lua", url = baseUri .. "musicplayer/middleware/error_handler.lua", path = "musicplayer/middleware/error_handler.lua"},
        
        -- Feature modules
        {name = "main_menu.lua", url = baseUri .. "musicplayer/features/menu/main_menu.lua", path = "musicplayer/features/menu/main_menu.lua"},
        {name = "youtube_player.lua", url = baseUri .. "musicplayer/features/youtube/youtube_player.lua", path = "musicplayer/features/youtube/youtube_player.lua"},
        {name = "radio_client.lua", url = baseUri .. "musicplayer/features/radio/radio_client.lua", path = "musicplayer/features/radio/radio_client.lua"},
        {name = "radio_host.lua", url = baseUri .. "musicplayer/features/radio/radio_host.lua", path = "musicplayer/features/radio/radio_host.lua"},
        
        -- Application management
        {name = "app_manager.lua", url = baseUri .. "musicplayer/app_manager.lua", path = "musicplayer/app_manager.lua"},
        
        -- Telemetry modules
        {name = "telemetry.lua", url = baseUri .. "musicplayer/telemetry/telemetry.lua", path = "musicplayer/telemetry/telemetry.lua"},
        {name = "logger.lua", url = baseUri .. "musicplayer/telemetry/logger.lua", path = "musicplayer/telemetry/logger.lua"},
        {name = "system_detector.lua", url = baseUri .. "musicplayer/telemetry/system_detector.lua", path = "musicplayer/telemetry/system_detector.lua"}
    }
end

-- Download a single file
local function downloadFile(file)
    local response = http.get(file.url)
    if response then
        local content = response.readAll()
        if content and content ~= "" then
            -- Create directory if it doesn't exist
            local dir = fs.getDir(file.path)
            if dir ~= "" and not fs.exists(dir) then
                fs.makeDir(dir)
            end
            
            local fileInstance = fs.open(file.path, "w")
            fileInstance.write(content)
            fileInstance.close()
            response.close()
            return true, string.len(content)
        else
            if response then response.close() end
            return false, "Empty content"
        end
    else
        return false, "Download failed"
    end
end

-- Download all files fresh from GitHub
local function downloadAllFiles()
    colorPrint("Downloading fresh files from GitHub...", colors.cyan)
    
    local files = getFileList()
    local successCount = 0
    local failCount = 0
    
    for i, file in ipairs(files) do
        term.setTextColor(colors.white)
        term.write("Downloading " .. file.name .. "... ")
        
        local success, result = downloadFile(file)
        if success then
            colorPrint("✓ (" .. result .. " bytes)", colors.lime)
            logMessage("Downloaded: " .. file.path)
            successCount = successCount + 1
        else
            colorPrint("✗ " .. result, colors.red)
            logMessage("Failed to download: " .. file.path .. " - " .. result)
            failCount = failCount + 1
        end
        
        sleep(0.05) -- Small delay to show progress
    end
    
    return successCount, failCount
end

-- Main force upgrade function
local function forceUpgrade()
    drawBanner()
    
    -- Test connectivity first
    colorPrint("Testing connection to GitHub...", colors.cyan)
    local testResponse = http.get(baseUri .. "version.txt")
    if not testResponse then
        colorPrint("ERROR: Cannot connect to GitHub", colors.red)
        colorPrint("Please check your internet connection and try again.", colors.yellow)
        return
    end
    testResponse.close()
    colorPrint("✓ Connection OK", colors.lime)
    
    -- Single confirmation
    colorPrint("This will completely wipe and reinstall Bognesferga Radio.", colors.yellow)
    colorPrint("All current files will be backed up first.", colors.yellow)
    print()
    term.setTextColor(colors.white)
    term.write("Continue with force upgrade? (y/n): ")
    local input = read():lower()
    
    if input ~= "y" and input ~= "yes" then
        colorPrint("Upgrade cancelled.", colors.lightGray)
        return
    end
    
    -- Create backup
    local backupPath = createBackup()
    print()
    
    -- Wipe existing files
    wipeFiles()
    print()
    
    -- Download fresh files
    local successCount, failCount = downloadAllFiles()
    print()
    
    -- Show results
    colorPrint("Force Upgrade Complete!", colors.lime)
    colorPrint("✓ Successfully downloaded: " .. successCount .. " files", colors.lime)
    if failCount > 0 then
        colorPrint("✗ Failed to download: " .. failCount .. " files", colors.red)
        colorPrint("Check the logs for details.", colors.yellow)
    end
    
    colorPrint("Backup saved in: " .. backupPath, colors.lightGray)
    colorPrint("Type 'startup' to run the fresh installation.", colors.cyan)
    
    logMessage("Force upgrade completed: " .. successCount .. " files downloaded, " .. failCount .. " failed")
end

-- Start the force upgrade
forceUpgrade() 