-- Bognesferga Radio Upgrade System
-- Handles version upgrades without requiring full uninstall/reinstall
-- Preserves user data and configurations

local baseUri = "https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/"

-- Upgrade configuration
local CURRENT_VERSION_FILE = "version.txt"
local BACKUP_DIR = "backups"
local LOG_FILE = "musicplayer/logs/upgrade.log"

-- Utility functions
local function trim(str)
    return str:match("^%s*(.-)%s*$")
end

-- Animation and UI functions
local function animateText(text, color, delay)
    term.setTextColor(color)
    for i = 1, #text do
        term.write(text:sub(i, i))
        sleep(delay or 0.05)
    end
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
    
    local bannerText = "  Bognesferga Radio Upgrader  "
    local startX = math.floor((w - #bannerText) / 2) + 1
    term.setCursorPos(startX, 1)
    animateText(bannerText, colors.white, 0.03)
    
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 3)
    
    term.setTextColor(colors.yellow)
    local devText = "Smart Version Management by Forty"
    local centerX = math.floor((w - #devText) / 2) + 1
    term.setCursorPos(centerX, 3)
    animateText(devText, colors.yellow, 0.04)
    
    term.setCursorPos(1, 5)
    term.setTextColor(colors.lightGray)
    local line = string.rep("=", w)
    animateText(line, colors.lightGray, 0.01)
    
    term.setCursorPos(1, 7)
end

local function animatedProgress(current, total, color)
    local w = term.getSize()
    local barWidth = w - 20
    local progress = math.floor((current / total) * barWidth)
    
    term.setTextColor(colors.white)
    term.write("[")
    
    term.setTextColor(color or colors.lime)
    for i = 1, progress do
        term.write("=")
    end
    
    term.setTextColor(colors.gray)
    for i = progress + 1, barWidth do
        term.write("-")
    end
    
    term.setTextColor(colors.white)
    term.write("] ")
    
    term.setTextColor(colors.yellow)
    term.write(math.floor((current / total) * 100) .. "%")
end

local function logMessage(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    if not fs.exists("musicplayer/logs") then
        fs.makeDir("musicplayer/logs")
    end
    
    local file = fs.open(LOG_FILE, "a")
    if file then
        file.writeLine("[" .. timestamp .. "] " .. message)
        file.close()
    end
end

-- Version management functions
local function parseVersion(versionStr)
    local major, minor = versionStr:match("(%d+)%.(%d+)")
    return tonumber(major) or 0, tonumber(minor) or 0
end

local function compareVersions(v1, v2)
    local major1, minor1 = parseVersion(v1)
    local major2, minor2 = parseVersion(v2)
    
    if major1 > major2 then return 1
    elseif major1 < major2 then return -1
    elseif minor1 > minor2 then return 1
    elseif minor1 < minor2 then return -1
    else return 0 end
end

local function getCurrentVersion()
    if fs.exists(CURRENT_VERSION_FILE) then
        local file = fs.open(CURRENT_VERSION_FILE, "r")
        if file then
            local version = trim(file.readAll())
            file.close()
            return version
        end
    end
    return "0.0"
end

local function getLatestVersion()
    colorPrint("Checking for latest version...", colors.cyan)
    local response = http.get(baseUri .. "version.txt")
    if response then
        local version = trim(response.readAll())
        response.close()
        return version
    end
    return nil
end

-- Backup functions
local function createBackup(currentVersion)
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
            if fs.isDir(item) then
                fs.copy(item, backupPath .. "/" .. item)
                colorPrint("✓ Backed up directory: " .. item, colors.lime)
            else
                fs.copy(item, backupPath .. "/" .. item)
                colorPrint("✓ Backed up file: " .. item, colors.lime)
            end
            backedUpCount = backedUpCount + 1
        end
    end
    
    logMessage("Created backup: " .. backupPath .. " (" .. backedUpCount .. " items)")
    return backupPath
end

local function listBackups()
    if not fs.exists(BACKUP_DIR) then
        return {}
    end
    
    local backups = {}
    for _, item in ipairs(fs.list(BACKUP_DIR)) do
        if fs.isDir(BACKUP_DIR .. "/" .. item) then
            table.insert(backups, item)
        end
    end
    
    table.sort(backups, function(a, b) return a > b end) -- Sort newest first
    return backups
end

-- File management functions
local function getFileList()
    return {
        -- Core files
        {name = "startup.lua", url = baseUri .. "startup.lua", path = "startup.lua", critical = true},
        {name = "config.lua", url = baseUri .. "musicplayer/config.lua", path = "musicplayer/config.lua", critical = false},
        
        -- Core system modules
        {name = "system.lua", url = baseUri .. "musicplayer/core/system.lua", path = "musicplayer/core/system.lua", critical = true},
        
        -- UI modules
        {name = "themes.lua", url = baseUri .. "musicplayer/ui/themes.lua", path = "musicplayer/ui/themes.lua", critical = false},
        {name = "components.lua", url = baseUri .. "musicplayer/ui/components.lua", path = "musicplayer/ui/components.lua", critical = true},
        {name = "youtube.lua", url = baseUri .. "musicplayer/ui/layouts/youtube.lua", path = "musicplayer/ui/layouts/youtube.lua", critical = true},
        {name = "radio.lua", url = baseUri .. "musicplayer/ui/layouts/radio.lua", path = "musicplayer/ui/layouts/radio.lua", critical = true},
        
        -- Audio modules
        {name = "speaker_manager.lua", url = baseUri .. "musicplayer/audio/speaker_manager.lua", path = "musicplayer/audio/speaker_manager.lua", critical = true},
        
        -- Network modules
        {name = "http_client.lua", url = baseUri .. "musicplayer/network/http_client.lua", path = "musicplayer/network/http_client.lua", critical = true},
        {name = "radio_protocol.lua", url = baseUri .. "musicplayer/network/radio_protocol.lua", path = "musicplayer/network/radio_protocol.lua", critical = true},
        
        -- Utilities
        {name = "common.lua", url = baseUri .. "musicplayer/utils/common.lua", path = "musicplayer/utils/common.lua", critical = true},
        
        -- Middleware
        {name = "error_handler.lua", url = baseUri .. "musicplayer/middleware/error_handler.lua", path = "musicplayer/middleware/error_handler.lua", critical = true},
        
        -- Feature modules
        {name = "main_menu.lua", url = baseUri .. "musicplayer/features/menu/main_menu.lua", path = "musicplayer/features/menu/main_menu.lua", critical = true},
        {name = "youtube_player.lua", url = baseUri .. "musicplayer/features/youtube/youtube_player.lua", path = "musicplayer/features/youtube/youtube_player.lua", critical = true},
        {name = "radio_client.lua", url = baseUri .. "musicplayer/features/radio/radio_client.lua", path = "musicplayer/features/radio/radio_client.lua", critical = true},
        {name = "radio_host.lua", url = baseUri .. "musicplayer/features/radio/radio_host.lua", path = "musicplayer/features/radio/radio_host.lua", critical = true},
        
        -- Application management
        {name = "app_manager.lua", url = baseUri .. "musicplayer/app_manager.lua", path = "musicplayer/app_manager.lua", critical = true},
        
        -- Telemetry modules
        {name = "telemetry.lua", url = baseUri .. "musicplayer/telemetry/telemetry.lua", path = "musicplayer/telemetry/telemetry.lua", critical = false},
        {name = "logger.lua", url = baseUri .. "musicplayer/telemetry/logger.lua", path = "musicplayer/telemetry/logger.lua", critical = false},
        {name = "system_detector.lua", url = baseUri .. "musicplayer/telemetry/system_detector.lua", path = "musicplayer/telemetry/system_detector.lua", critical = false}
    }
end

local function updateFile(file)
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

-- Main upgrade functions
local function performUpgrade(fromVersion, toVersion, selectedFiles)
    colorPrint("Upgrading from v" .. fromVersion .. " to v" .. toVersion .. "...", colors.cyan)
    
    local successCount = 0
    local failCount = 0
    local skippedCount = 0
    
    for i, file in ipairs(selectedFiles) do
        term.setTextColor(colors.white)
        term.write("Updating " .. file.name .. "... ")
        
        -- Show progress
        local x, y = term.getCursorPos()
        term.setCursorPos(1, y + 1)
        animatedProgress(i - 1, #selectedFiles, colors.orange)
        term.setCursorPos(x, y)
        
        local success, result = updateFile(file)
        if success then
            colorPrint("✓ (" .. result .. " bytes)", colors.lime)
            logMessage("Updated: " .. file.path)
            successCount = successCount + 1
        else
            colorPrint("✗ " .. result, colors.red)
            logMessage("Failed to update: " .. file.path .. " - " .. result)
            failCount = failCount + 1
            
            if file.critical then
                colorPrint("CRITICAL FILE FAILED! Upgrade may be unstable.", colors.red)
            end
        end
        
        sleep(0.1)
    end
    
    -- Final progress
    local _, currentY = term.getCursorPos()
    term.setCursorPos(1, currentY)
    animatedProgress(#selectedFiles, #selectedFiles, colors.lime)
    print()
    
    -- Update version file
    local versionFile = fs.open(CURRENT_VERSION_FILE, "w")
    versionFile.write(toVersion)
    versionFile.close()
    
    return successCount, failCount, skippedCount
end

local function rollback(backupPath)
    colorPrint("Rolling back from backup: " .. backupPath, colors.yellow)
    
    if not fs.exists(backupPath) then
        colorPrint("Backup not found!", colors.red)
        return false
    end
    
    -- Remove current files
    if fs.exists("musicplayer") then
        fs.delete("musicplayer")
    end
    if fs.exists("startup.lua") then
        fs.delete("startup.lua")
    end
    
    -- Restore from backup
    for _, item in ipairs(fs.list(backupPath)) do
        fs.copy(backupPath .. "/" .. item, item)
        colorPrint("✓ Restored: " .. item, colors.lime)
    end
    
    logMessage("Rollback completed from: " .. backupPath)
    return true
end

-- Interactive menu functions
local function selectFiles(files)
    local selected = {}
    
    for _, file in ipairs(files) do
        if file.critical then
            table.insert(selected, file) -- Always include critical files
        end
    end
    
    colorPrint("Critical files will be updated automatically.", colors.yellow)
    colorPrint("Select additional files to update (optional):", colors.cyan)
    
    for _, file in ipairs(files) do
        if not file.critical then
            term.setTextColor(colors.white)
            term.write("Update " .. file.name .. "? (y/n): ")
            local input = read():lower()
            if input == "y" or input == "yes" then
                table.insert(selected, file)
                colorPrint("✓ Will update " .. file.name, colors.lime)
            else
                colorPrint("- Skipping " .. file.name, colors.lightGray)
            end
        end
    end
    
    return selected
end

-- Main upgrade process
local function mainUpgrade()
    drawBanner()
    
    -- Test connectivity
    colorPrint("Testing connection to update server...", colors.cyan)
    local testResponse = http.get(baseUri .. "version.txt")
    if not testResponse then
        colorPrint("ERROR: Cannot connect to update server", colors.red)
        colorPrint("Please check your internet connection and try again.", colors.yellow)
        return
    end
    testResponse.close()
    colorPrint("✓ Connection OK", colors.lime)
    
    -- Get versions
    local currentVersion = getCurrentVersion()
    local latestVersion = getLatestVersion()
    
    if not latestVersion then
        colorPrint("ERROR: Could not fetch latest version", colors.red)
        return
    end
    
    colorPrint("Current version: v" .. currentVersion, colors.white)
    colorPrint("Latest version: v" .. latestVersion, colors.white)
    
    local versionComparison = compareVersions(currentVersion, latestVersion)
    
    if versionComparison == 0 then
        colorPrint("You're already running the latest version!", colors.lime)
        
        term.setTextColor(colors.yellow)
        term.write("Force update anyway? (y/n): ")
        local input = read():lower()
        if input ~= "y" and input ~= "yes" then
            colorPrint("Upgrade cancelled.", colors.lightGray)
            return
        end
    elseif versionComparison > 0 then
        colorPrint("You're running a newer version than available!", colors.orange)
        colorPrint("This might be a development version.", colors.yellow)
        
        term.setTextColor(colors.yellow)
        term.write("Downgrade to stable version? (y/n): ")
        local input = read():lower()
        if input ~= "y" and input ~= "yes" then
            colorPrint("Upgrade cancelled.", colors.lightGray)
            return
        end
    else
        colorPrint("Update available!", colors.lime)
    end
    
    -- Create backup
    local backupPath = createBackup(currentVersion)
    
    -- Select files to update
    local files = getFileList()
    local selectedFiles = selectFiles(files)
    
    colorPrint("Selected " .. #selectedFiles .. " files for update.", colors.cyan)
    
    term.setTextColor(colors.yellow)
    term.write("Proceed with upgrade? (y/n): ")
    local proceed = read():lower()
    
    if proceed ~= "y" and proceed ~= "yes" then
        colorPrint("Upgrade cancelled.", colors.lightGray)
        return
    end
    
    -- Perform upgrade
    local successCount, failCount, skippedCount = performUpgrade(currentVersion, latestVersion, selectedFiles)
    
    -- Show results
    sleep(0.5)
    colorPrint("Upgrade Summary:", colors.cyan)
    colorPrint("✓ Successfully updated: " .. successCount .. " files", colors.lime)
    if failCount > 0 then
        colorPrint("✗ Failed to update: " .. failCount .. " files", colors.red)
    end
    if skippedCount > 0 then
        colorPrint("- Skipped: " .. skippedCount .. " files", colors.lightGray)
    end
    
    if failCount > 0 then
        colorPrint("Some files failed to update. Check the logs for details.", colors.yellow)
        term.setTextColor(colors.red)
        term.write("Rollback to previous version? (y/n): ")
        local rollbackChoice = read():lower()
        if rollbackChoice == "y" or rollbackChoice == "yes" then
            rollback(backupPath)
            colorPrint("Rollback completed.", colors.lime)
            return
        end
    end
    
    colorPrint("Upgrade completed successfully!", colors.lime)
    colorPrint("Backup saved in: " .. backupPath, colors.lightGray)
    colorPrint("Type 'startup' to run the updated version.", colors.cyan)
    
    logMessage("Upgrade completed: v" .. currentVersion .. " -> v" .. latestVersion)
end

-- Backup management menu
local function backupMenu()
    drawBanner()
    colorPrint("Backup Management", colors.cyan)
    
    local backups = listBackups()
    if #backups == 0 then
        colorPrint("No backups found.", colors.lightGray)
        return
    end
    
    colorPrint("Available backups:", colors.white)
    for i, backup in ipairs(backups) do
        colorPrint(i .. ". " .. backup, colors.yellow)
    end
    
    term.setTextColor(colors.white)
    term.write("Select backup to restore (number) or 'q' to quit: ")
    local input = read()
    
    if input:lower() == "q" then
        return
    end
    
    local selection = tonumber(input)
    if selection and selection >= 1 and selection <= #backups then
        local selectedBackup = backups[selection]
        colorPrint("Selected: " .. selectedBackup, colors.yellow)
        
        term.setTextColor(colors.red)
        term.write("This will overwrite your current installation! Continue? (y/n): ")
        local confirm = read():lower()
        
        if confirm == "y" or confirm == "yes" then
            if rollback(BACKUP_DIR .. "/" .. selectedBackup) then
                colorPrint("Rollback completed successfully!", colors.lime)
            else
                colorPrint("Rollback failed!", colors.red)
            end
        else
            colorPrint("Rollback cancelled.", colors.lightGray)
        end
    else
        colorPrint("Invalid selection.", colors.red)
    end
end

-- Main menu
local function showMainMenu()
    drawBanner()
    
    colorPrint("Bognesferga Radio Upgrade System", colors.cyan)
    colorPrint("Current version: v" .. getCurrentVersion(), colors.white)
    print()
    
    colorPrint("1. Check for updates and upgrade", colors.yellow)
    colorPrint("2. Manage backups and rollback", colors.yellow)
    colorPrint("3. View upgrade logs", colors.yellow)
    colorPrint("4. Exit", colors.yellow)
    print()
    
    term.setTextColor(colors.white)
    term.write("Select option (1-4): ")
    local choice = read()
    
    if choice == "1" then
        mainUpgrade()
    elseif choice == "2" then
        backupMenu()
    elseif choice == "3" then
        if fs.exists(LOG_FILE) then
            term.clear()
            term.setCursorPos(1, 1)
            colorPrint("Upgrade Logs:", colors.cyan)
            print()
            
            local file = fs.open(LOG_FILE, "r")
            if file then
                local content = file.readAll()
                file.close()
                
                term.setTextColor(colors.lightGray)
                print(content)
            end
            
            colorPrint("Press any key to continue...", colors.yellow)
            os.pullEvent("key")
        else
            colorPrint("No upgrade logs found.", colors.lightGray)
            sleep(2)
        end
        showMainMenu()
    elseif choice == "4" then
        colorPrint("Goodbye!", colors.lime)
        return
    else
        colorPrint("Invalid option. Please try again.", colors.red)
        sleep(1)
        showMainMenu()
    end
end

-- Start the upgrade system
showMainMenu() 