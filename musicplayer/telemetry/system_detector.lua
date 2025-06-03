-- System Detector module for Bognesferga Radio
-- Detects computer type, peripherals, and monitors

local detector = {}

-- Computer types
detector.COMPUTER_TYPES = {
    COMPUTER = "computer",
    TURTLE = "turtle",
    POCKET = "pocket",
    UNKNOWN = "unknown"
}

-- Initialize system detection
function detector.init()
    local systemInfo = {
        computerType = detector.detectComputerType(),
        computerID = os.getComputerID(),
        computerLabel = os.getComputerLabel() or "Unnamed",
        monitors = detector.detectMonitors(),
        speakers = detector.detectSpeakers(),
        modems = detector.detectModems(),
        diskDrives = detector.detectDiskDrives(),
        otherPeripherals = detector.detectOtherPeripherals(),
        terminalSize = {term.getSize()},
        ccVersion = _HOST or "Unknown",
        hasAdvancedComputer = term.isColor and term.isColor() or false
    }
    
    -- Add turtle-specific information
    if systemInfo.computerType == detector.COMPUTER_TYPES.TURTLE then
        systemInfo.turtleInfo = detector.getTurtleInfo()
    end
    
    return systemInfo
end

-- Detect computer type
function detector.detectComputerType()
    -- Check if turtle API is available
    if turtle then
        return detector.COMPUTER_TYPES.TURTLE
    end
    
    -- Check if pocket API is available
    if pocket then
        return detector.COMPUTER_TYPES.POCKET
    end
    
    -- Check terminal size to distinguish between computer and advanced computer
    local width, height = term.getSize()
    if width == 51 and height == 19 then
        return detector.COMPUTER_TYPES.COMPUTER
    elseif width == 39 and height == 13 then
        return detector.COMPUTER_TYPES.POCKET
    else
        return detector.COMPUTER_TYPES.COMPUTER -- Default assumption
    end
end

-- Detect all monitors
function detector.detectMonitors()
    local monitors = {}
    local monitorNames = {peripheral.find("monitor")}
    
    for i, monitor in ipairs(monitorNames) do
        local side = peripheral.getName(monitor)
        local width, height = monitor.getSize()
        local isColor = monitor.isColor and monitor.isColor() or false
        
        table.insert(monitors, {
            peripheral = monitor,
            side = side,
            width = width,
            height = height,
            isColor = isColor,
            scale = monitor.getTextScale and monitor.getTextScale() or 1
        })
    end
    
    return monitors
end

-- Detect speakers
function detector.detectSpeakers()
    local speakers = {}
    local speakerPeripherals = {peripheral.find("speaker")}
    
    for i, speaker in ipairs(speakerPeripherals) do
        local side = peripheral.getName(speaker)
        table.insert(speakers, {
            peripheral = speaker,
            side = side
        })
    end
    
    return speakers
end

-- Detect modems
function detector.detectModems()
    local modems = {}
    local modemPeripherals = {peripheral.find("modem")}
    
    for i, modem in ipairs(modemPeripherals) do
        local side = peripheral.getName(modem)
        local isWireless = modem.isWireless and modem.isWireless() or false
        
        table.insert(modems, {
            peripheral = modem,
            side = side,
            isWireless = isWireless
        })
    end
    
    return modems
end

-- Detect disk drives
function detector.detectDiskDrives()
    local drives = {}
    local drivePeripherals = {peripheral.find("drive")}
    
    for i, drive in ipairs(drivePeripherals) do
        local side = peripheral.getName(drive)
        local hasMedia = drive.hasData and drive.hasData() or false
        local mediaLabel = hasMedia and drive.getDiskLabel and drive.getDiskLabel() or nil
        
        table.insert(drives, {
            peripheral = drive,
            side = side,
            hasMedia = hasMedia,
            mediaLabel = mediaLabel
        })
    end
    
    return drives
end

-- Detect other peripherals
function detector.detectOtherPeripherals()
    local others = {}
    local allPeripherals = peripheral.getNames()
    
    for _, side in ipairs(allPeripherals) do
        local pType = peripheral.getType(side)
        
        -- Skip already detected peripherals
        if pType ~= "monitor" and pType ~= "speaker" and pType ~= "modem" and pType ~= "drive" then
            table.insert(others, {
                side = side,
                type = pType,
                peripheral = peripheral.wrap(side)
            })
        end
    end
    
    return others
end

-- Get turtle-specific information
function detector.getTurtleInfo()
    if not turtle then
        return nil
    end
    
    local turtleInfo = {
        fuelLevel = turtle.getFuelLevel(),
        fuelLimit = turtle.getFuelLimit(),
        selectedSlot = turtle.getSelectedSlot(),
        inventory = {}
    }
    
    -- Get inventory information
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            turtleInfo.inventory[slot] = {
                name = item.name,
                count = item.count,
                damage = item.damage
            }
        end
    end
    
    return turtleInfo
end

-- Choose best monitors for application and logging
function detector.chooseBestMonitors(systemInfo)
    local monitors = systemInfo.monitors
    local result = {
        appMonitor = nil,
        logMonitor = nil
    }
    
    if #monitors == 0 then
        -- No external monitors, use terminal
        return result
    elseif #monitors == 1 then
        -- One monitor, use it for the application
        result.appMonitor = monitors[1]
        return result
    else
        -- Multiple monitors, choose best for each purpose
        
        -- Sort monitors by size (larger for app, smaller for logs)
        table.sort(monitors, function(a, b)
            return (a.width * a.height) > (b.width * b.height)
        end)
        
        -- Largest monitor for application
        result.appMonitor = monitors[1]
        
        -- Second monitor for logging (or smallest if more than 2)
        if #monitors >= 2 then
            result.logMonitor = monitors[2]
        end
        
        return result
    end
end

-- Get system capabilities summary
function detector.getCapabilitiesSummary(systemInfo)
    local summary = {
        canPlayAudio = #systemInfo.speakers > 0,
        canUseNetwork = #systemInfo.modems > 0,
        hasExternalDisplay = #systemInfo.monitors > 0,
        canUseDualScreen = #systemInfo.monitors >= 2,
        isMobile = systemInfo.computerType == detector.COMPUTER_TYPES.TURTLE,
        hasAdvancedFeatures = systemInfo.hasAdvancedComputer,
        storageDevices = #systemInfo.diskDrives
    }
    
    return summary
end

-- Generate system report
function detector.generateSystemReport(systemInfo)
    local report = {}
    
    table.insert(report, "=== SYSTEM INFORMATION ===")
    table.insert(report, "Computer Type: " .. systemInfo.computerType)
    table.insert(report, "Computer ID: " .. systemInfo.computerID)
    table.insert(report, "Computer Label: " .. systemInfo.computerLabel)
    table.insert(report, "CC Version: " .. systemInfo.ccVersion)
    table.insert(report, "Advanced Computer: " .. (systemInfo.hasAdvancedComputer and "Yes" or "No"))
    table.insert(report, "Terminal Size: " .. systemInfo.terminalSize[1] .. "x" .. systemInfo.terminalSize[2])
    table.insert(report, "")
    
    table.insert(report, "=== PERIPHERALS ===")
    table.insert(report, "Monitors: " .. #systemInfo.monitors)
    for i, monitor in ipairs(systemInfo.monitors) do
        table.insert(report, "  " .. i .. ". " .. monitor.side .. " (" .. monitor.width .. "x" .. monitor.height .. ", " .. (monitor.isColor and "Color" or "Mono") .. ")")
    end
    
    table.insert(report, "Speakers: " .. #systemInfo.speakers)
    for i, speaker in ipairs(systemInfo.speakers) do
        table.insert(report, "  " .. i .. ". " .. speaker.side)
    end
    
    table.insert(report, "Modems: " .. #systemInfo.modems)
    for i, modem in ipairs(systemInfo.modems) do
        table.insert(report, "  " .. i .. ". " .. modem.side .. " (" .. (modem.isWireless and "Wireless" or "Wired") .. ")")
    end
    
    table.insert(report, "Disk Drives: " .. #systemInfo.diskDrives)
    for i, drive in ipairs(systemInfo.diskDrives) do
        local mediaInfo = drive.hasMedia and (" - " .. (drive.mediaLabel or "Unlabeled")) or " - Empty"
        table.insert(report, "  " .. i .. ". " .. drive.side .. mediaInfo)
    end
    
    if #systemInfo.otherPeripherals > 0 then
        table.insert(report, "Other Peripherals: " .. #systemInfo.otherPeripherals)
        for i, peripheral in ipairs(systemInfo.otherPeripherals) do
            table.insert(report, "  " .. i .. ". " .. peripheral.side .. " (" .. peripheral.type .. ")")
        end
    end
    
    if systemInfo.turtleInfo then
        table.insert(report, "")
        table.insert(report, "=== TURTLE INFORMATION ===")
        table.insert(report, "Fuel Level: " .. systemInfo.turtleInfo.fuelLevel .. "/" .. systemInfo.turtleInfo.fuelLimit)
        table.insert(report, "Selected Slot: " .. systemInfo.turtleInfo.selectedSlot)
        
        local itemCount = 0
        for slot, item in pairs(systemInfo.turtleInfo.inventory) do
            itemCount = itemCount + 1
        end
        table.insert(report, "Inventory Items: " .. itemCount .. "/16")
    end
    
    local capabilities = detector.getCapabilitiesSummary(systemInfo)
    table.insert(report, "")
    table.insert(report, "=== CAPABILITIES ===")
    table.insert(report, "Audio Playback: " .. (capabilities.canPlayAudio and "Yes" or "No"))
    table.insert(report, "Network Access: " .. (capabilities.canUseNetwork and "Yes" or "No"))
    table.insert(report, "External Display: " .. (capabilities.hasExternalDisplay and "Yes" or "No"))
    table.insert(report, "Dual Screen: " .. (capabilities.canUseDualScreen and "Yes" or "No"))
    table.insert(report, "Mobile Platform: " .. (capabilities.isMobile and "Yes" or "No"))
    table.insert(report, "Advanced Features: " .. (capabilities.hasAdvancedFeatures and "Yes" or "No"))
    
    return report
end

return detector 