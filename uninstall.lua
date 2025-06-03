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
    
    -- List files that will be removed
    local filesToRemove = {
        "startup.lua",
        "uninstall.lua",
        "install.lua",
        "download",
        "version.txt",
        "musicplayer/ (entire folder)",
        "  ├── config.lua",
        "  ├── state.lua", 
        "  ├── ui.lua",
        "  ├── input.lua",
        "  ├── audio.lua",
        "  ├── network.lua",
        "  ├── main.lua",
        "  ├── menu.lua",
        "  ├── radio.lua",
        "  └── radio_ui.lua"
    }
    
    for _, file in ipairs(filesToRemove) do
        colorPrint(file, colors.lightGray)
        sleep(0.1)
    end
    
    colorPrint("", colors.white)
    colorPrint("Are you sure you want to continue? (y/N): ", colors.red)
    
    local input = read()
    return input:lower() == "y" or input:lower() == "yes"
end

local function removeFiles()
    local filesToRemove = {
        {path = "startup.lua", name = "Main startup file"},
        {path = "install.lua", name = "Installer script"},
        {path = "download", name = "Download script"},
        {path = "version.txt", name = "Version file"},
        {path = "musicplayer/config.lua", name = "Configuration module"},
        {path = "musicplayer/state.lua", name = "State management module"},
        {path = "musicplayer/ui.lua", name = "UI rendering module"},
        {path = "musicplayer/input.lua", name = "Input handling module"},
        {path = "musicplayer/audio.lua", name = "Audio processing module"},
        {path = "musicplayer/network.lua", name = "Network handling module"},
        {path = "musicplayer/main.lua", name = "Main coordination module"},
        {path = "musicplayer/menu.lua", name = "Menu system module"},
        {path = "musicplayer/radio.lua", name = "Radio functionality module"},
        {path = "musicplayer/radio_ui.lua", name = "Radio UI module"}
    }
    
    local removedCount = 0
    local totalFiles = #filesToRemove + 2 -- +1 for the folder itself, +1 for uninstall.lua (self-delete)
    
    colorPrint("Removing files...", colors.cyan)
    sleep(0.5)
    
    -- Remove individual files
    for i, file in ipairs(filesToRemove) do
        term.setTextColor(colors.white)
        term.write("Removing " .. file.name .. "... ")
        
        if fs.exists(file.path) then
            fs.delete(file.path)
            colorPrint("✓ Removed", colors.lime)
            removedCount = removedCount + 1
        else
            colorPrint("✗ Not found", colors.yellow)
        end
        
        sleep(0.2)
    end
    
    -- Remove the musicplayer directory if it's empty or force remove it
    term.setTextColor(colors.white)
    term.write("Removing musicplayer directory... ")
    
    if fs.exists("musicplayer") then
        fs.delete("musicplayer")
        colorPrint("✓ Removed", colors.lime)
        removedCount = removedCount + 1
    else
        colorPrint("✗ Not found", colors.yellow)
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
        colorPrint("Thank you for using our music system!", colors.cyan)
    else
        colorPrint("No files were removed.", colors.yellow)
        colorPrint("The system may have been already uninstalled.", colors.lightGray)
    end
    
    -- Final message with animation
    colorPrint("", colors.white)
    term.setTextColor(colors.magenta)
    term.write("Goodbye! ")
    
    -- Animated farewell
    local farewell = "♪ Thanks for the music! ♪"
    for i = 1, #farewell do
        local colors_list = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.blue, colors.purple}
        local colorIndex = ((i - 1) % #colors_list) + 1
        term.setTextColor(colors_list[colorIndex])
        term.write(farewell:sub(i, i))
        sleep(0.1)
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