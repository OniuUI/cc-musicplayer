-- Bognesferga Radio Uninstaller
-- Removes all files and folders related to the radio system

-- Animation and color functions
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
    
    -- Animated banner with colors
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.clearLine()
    local w, h = term.getSize()
    
    -- Center the banner text
    local bannerText = "  Bognesferga Radio Uninstaller  "
    local startX = math.floor((w - #bannerText) / 2) + 1
    term.setCursorPos(startX, 1)
    animateText(bannerText, colors.white, 0.03)
    
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 3)
    
    -- Animated "Developed by Forty" banner
    term.setTextColor(colors.yellow)
    local devText = "Developed by "
    local nameText = "Forty"
    local centerX = math.floor((w - (#devText + #nameText)) / 2) + 1
    
    term.setCursorPos(centerX, 3)
    animateText(devText, colors.yellow, 0.04)
    
    -- Animate "Forty" with rainbow effect
    local rainbowColors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
    for i = 1, #nameText do
        local colorIndex = ((i - 1) % #rainbowColors) + 1
        term.setTextColor(rainbowColors[colorIndex])
        term.write(nameText:sub(i, i))
        sleep(0.1)
    end
    
    -- Decorative line
    term.setCursorPos(1, 5)
    term.setTextColor(colors.lightGray)
    local line = string.rep("=", w)
    animateText(line, colors.lightGray, 0.01)
    
    term.setCursorPos(1, 7)
end

local function confirmUninstall()
    colorPrint("This will remove ALL Bognesferga Radio files:", colors.yellow)
    colorPrint("", colors.white)
    
    -- List files that will be removed - UPDATED for new modular structure
    local filesToRemove = {
        "startup.lua",
        "uninstall.lua",
        "install.lua",
        "download",
        "version.txt",
        "musicplayer/ (entire folder)",
        "  ├── Core system:",
        "  │   └── core/system.lua",
        "  ├── UI components:",
        "  │   ├── ui/themes.lua",
        "  │   ├── ui/components.lua",
        "  │   └── ui/layouts/",
        "  ├── Audio system:",
        "  │   └── audio/speaker_manager.lua",
        "  ├── Network system:",
        "  │   └── network/http_client.lua",
        "  ├── Utilities:",
        "  │   └── utils/common.lua",
        "  ├── Middleware:",
        "  │   └── middleware/error_handler.lua",
        "  ├── Feature modules:",
        "  │   ├── features/menu/main_menu.lua",
        "  │   └── features/youtube/youtube_player.lua",
        "  ├── Configuration:",
        "  │   └── config.lua",
        "  ├── Application management:",
        "  │   └── app_manager.lua",
        "  ├── Telemetry system:",
        "  │   ├── telemetry/telemetry.lua",
        "  │   ├── telemetry/logger.lua",
        "  │   └── telemetry/system_detector.lua",
        "  └── Log files:",
        "      ├── logs/session.log",
        "      ├── logs/emergency.log",
        "      └── logs/export_*.log"
    }
    
    for _, file in ipairs(filesToRemove) do
        colorPrint(file, colors.lightGray)
        sleep(0.05)
    end
    
    colorPrint("", colors.white)
    colorPrint("Are you sure you want to continue? (y/N): ", colors.red)
    
    local input = read()
    return input:lower() == "y" or input:lower() == "yes"
end

local function removeFiles()
    -- Files to remove - UPDATED to include radio modules
    local files = {
        -- Core files
        "startup.lua",
        "version.txt",

        -- Install files
        "install.lua",
        "download",
        
        -- Configuration
        "musicplayer/config.lua",
        "musicplayer/app_manager.lua",
        
        -- New modular files
        "musicplayer/core/system.lua",
        "musicplayer/utils/common.lua",
        "musicplayer/middleware/error_handler.lua",
        "musicplayer/network/http_client.lua",
        "musicplayer/network/radio_protocol.lua",
        "musicplayer/audio/speaker_manager.lua",
        "musicplayer/ui/themes.lua",
        "musicplayer/ui/components.lua",
        "musicplayer/ui/layouts/youtube.lua",
        "musicplayer/ui/layouts/radio.lua",
        "musicplayer/features/menu/main_menu.lua",
        "musicplayer/features/youtube/youtube_player.lua",
        "musicplayer/features/radio/radio_client.lua",
        "musicplayer/features/radio/radio_host.lua",
        "musicplayer/telemetry/telemetry.lua",
        "musicplayer/telemetry/logger.lua",
        "musicplayer/telemetry/system_detector.lua"
    }
    
    local removedCount = 0
    local totalFiles = #files + 8 -- +8 for directories, +1 for uninstall.lua (self-delete)
    
    colorPrint("Removing files...", colors.cyan)
    sleep(0.5)
    
    -- Remove individual files
    for i, file in ipairs(files) do
        term.setTextColor(colors.white)
        term.write("Removing " .. file .. "... ")
        
        if fs.exists(file) then
            fs.delete(file)
            colorPrint("✓ Removed", colors.lime)
            removedCount = removedCount + 1
        else
            colorPrint("✗ Not found", colors.yellow)
        end
        
        sleep(0.1)
    end
    
    -- Directories to remove (in reverse order - deepest first)
    local directories = {
        "musicplayer/logs",
        "musicplayer/features/radio",
        "musicplayer/features/youtube", 
        "musicplayer/features/menu",
        "musicplayer/features",
        "musicplayer/ui/layouts",
        "musicplayer/ui",
        "musicplayer/telemetry",
        "musicplayer/middleware",
        "musicplayer/utils",
        "musicplayer/network",
        "musicplayer/audio",
        "musicplayer/core",
        "musicplayer"
    }
    
    for _, dir in ipairs(directories) do
        term.setTextColor(colors.white)
        term.write("Removing " .. dir .. " directory... ")
        
        if fs.exists(dir) then
            fs.delete(dir)
            colorPrint("✓ Removed", colors.lime)
            removedCount = removedCount + 1
        else
            colorPrint("✗ Not found", colors.yellow)
        end
        
        sleep(0.1)
    end
    
    -- Remove the uninstaller itself (last step)
    term.setTextColor(colors.white)
    term.write("Removing uninstaller... ")
    
    if fs.exists("uninstall.lua") then
        -- Schedule self-deletion after the script finishes
        colorPrint("✓ Will be removed", colors.lime)
        removedCount = removedCount + 1
    else
        colorPrint("✗ Not found", colors.yellow)
    end
    
    return removedCount, totalFiles
end

-- Main uninstaller
local function main()
    drawBanner()
    
    colorPrint("Welcome to the Bognesferga Radio Uninstaller!", colors.cyan)
    colorPrint("", colors.white)
    
    -- Check if any files exist
    local hasFiles = fs.exists("startup.lua") or fs.exists("musicplayer") or fs.exists("version.txt") or fs.exists("install.lua") or fs.exists("download")
    
    if not hasFiles then
        colorPrint("No Bognesferga Radio files found to remove.", colors.yellow)
        colorPrint("The system appears to already be uninstalled.", colors.lightGray)
        colorPrint("", colors.white)
        colorPrint("Press any key to exit...", colors.white)
        os.pullEvent("key")
        return
    end
    
    -- Show what will be removed
    colorPrint("Enhanced modular system detected with:", colors.cyan)
    if fs.exists("musicplayer/core") then
        colorPrint("• Core system architecture", colors.lightGray)
    end
    if fs.exists("musicplayer/middleware") then
        colorPrint("• Error handling middleware", colors.lightGray)
    end
    if fs.exists("musicplayer/utils") then
        colorPrint("• Utility functions", colors.lightGray)
    end
    if fs.exists("musicplayer/telemetry") then
        colorPrint("• Telemetry and logging system", colors.lightGray)
    end
    if fs.exists("musicplayer/logs") then
        colorPrint("• Log files and session data", colors.lightGray)
    end
    colorPrint("• Audio and network modules", colors.lightGray)
    colorPrint("• UI components and legacy modules", colors.lightGray)
    colorPrint("", colors.white)
    
    -- Confirm uninstallation
    if not confirmUninstall() then
        colorPrint("", colors.white)
        colorPrint("Uninstallation cancelled.", colors.yellow)
        colorPrint("Press any key to exit...", colors.white)
        os.pullEvent("key")
        return
    end
    
    colorPrint("", colors.white)
    
    -- Remove files
    local removedCount, totalFiles = removeFiles()
    
    sleep(0.5)
    
    -- Success message
    colorPrint("", colors.white)
    if removedCount > 0 then
        colorPrint("Uninstallation complete!", colors.lime)
        colorPrint("Removed " .. removedCount .. " out of " .. totalFiles .. " items.", colors.cyan)
        
        if removedCount < totalFiles then
            colorPrint("Some files were not found (may have been already removed).", colors.yellow)
        end
        
        colorPrint("", colors.white)
        colorPrint("Bognesferga Radio has been successfully uninstalled.", colors.lime)
        colorPrint("All modular components and data have been removed.", colors.cyan)
        colorPrint("Thank you for using our enhanced music system!", colors.cyan)
    else
        colorPrint("No files were removed.", colors.yellow)
        colorPrint("The system may have been already uninstalled.", colors.lightGray)
    end
    
    -- Final message with animation
    colorPrint("", colors.white)
    term.setTextColor(colors.magenta)
    term.write("Goodbye! ")
    
    -- Animated farewell
    local farewell = "♪ Thanks for the modular music experience! ♪"
    for i = 1, #farewell do
        local colors_list = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.blue, colors.purple}
        local colorIndex = ((i - 1) % #colors_list) + 1
        term.setTextColor(colors_list[colorIndex])
        term.write(farewell:sub(i, i))
        sleep(0.05)
    end
    
    term.setTextColor(colors.white)
    print()
    print()
    
    -- Self-delete the uninstaller as the final step
    if fs.exists("uninstall.lua") then
        fs.delete("uninstall.lua")
    end
end

-- Run the uninstaller
main() 