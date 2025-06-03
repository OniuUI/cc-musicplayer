-- Main Telemetry module for Bognesferga Radio
-- Coordinates system detection, logging, and dual-screen management

local logger = require("musicplayer.telemetry.logger")
local detector = require("musicplayer.telemetry.system_detector")

local telemetry = {}

-- Initialize telemetry system
function telemetry.init(logLevel)
    telemetry.systemInfo = detector.init()
    telemetry.capabilities = detector.getCapabilitiesSummary(telemetry.systemInfo)
    telemetry.monitors = detector.chooseBestMonitors(telemetry.systemInfo)
    
    -- Initialize logger with chosen log monitor
    logger.init(telemetry.monitors.logMonitor and telemetry.monitors.logMonitor.peripheral, logLevel)
    
    -- Log system information
    logger.info("Telemetry", "System detection completed")
    logger.info("Telemetry", "Computer: " .. telemetry.systemInfo.computerType .. " (ID: " .. telemetry.systemInfo.computerID .. ")")
    logger.info("Telemetry", "Monitors: " .. #telemetry.systemInfo.monitors .. " detected")
    logger.info("Telemetry", "Speakers: " .. #telemetry.systemInfo.speakers .. " detected")
    logger.info("Telemetry", "Modems: " .. #telemetry.systemInfo.modems .. " detected")
    
    if telemetry.monitors.appMonitor then
        logger.info("Telemetry", "Application monitor: " .. telemetry.monitors.appMonitor.side .. " (" .. telemetry.monitors.appMonitor.width .. "x" .. telemetry.monitors.appMonitor.height .. ")")
    end
    
    if telemetry.monitors.logMonitor then
        logger.info("Telemetry", "Log monitor: " .. telemetry.monitors.logMonitor.side .. " (" .. telemetry.monitors.logMonitor.width .. "x" .. telemetry.monitors.logMonitor.height .. ")")
    end
    
    -- Generate and save system report
    telemetry.saveSystemReport()
    
    return telemetry
end

-- Get system information
function telemetry.getSystemInfo()
    return telemetry.systemInfo
end

-- Get capabilities
function telemetry.getCapabilities()
    return telemetry.capabilities
end

-- Get monitors
function telemetry.getMonitors()
    return telemetry.monitors
end

-- Get logger instance
function telemetry.getLogger()
    return logger
end

-- Check if dual screen is available
function telemetry.hasDualScreen()
    return telemetry.monitors.appMonitor ~= nil and telemetry.monitors.logMonitor ~= nil
end

-- Get application display (monitor or terminal)
function telemetry.getAppDisplay()
    if telemetry.monitors.appMonitor then
        return telemetry.monitors.appMonitor.peripheral
    else
        return term
    end
end

-- Get log display (monitor or nil)
function telemetry.getLogDisplay()
    if telemetry.monitors.logMonitor then
        return telemetry.monitors.logMonitor.peripheral
    else
        return nil
    end
end

-- Switch to application display
function telemetry.switchToAppDisplay()
    if telemetry.monitors.appMonitor then
        term.redirect(telemetry.monitors.appMonitor.peripheral)
        logger.debug("Telemetry", "Switched to application monitor: " .. telemetry.monitors.appMonitor.side)
    else
        logger.debug("Telemetry", "Using terminal for application display")
    end
end

-- Switch back to terminal
function telemetry.switchToTerminal()
    term.restore()
    logger.debug("Telemetry", "Switched back to terminal")
end

-- Save system report to file
function telemetry.saveSystemReport()
    local report = detector.generateSystemReport(telemetry.systemInfo)
    
    -- Create telemetry directory if it doesn't exist
    if not fs.exists("musicplayer/telemetry") then
        fs.makeDir("musicplayer/telemetry")
    end
    
    local filename = "musicplayer/telemetry/system_report.txt"
    local file = fs.open(filename, "w")
    
    if file then
        for _, line in ipairs(report) do
            file.writeLine(line)
        end
        file.close()
        logger.info("Telemetry", "System report saved to " .. filename)
    else
        logger.error("Telemetry", "Failed to save system report")
    end
end

-- Display system information on log monitor
function telemetry.displaySystemInfo()
    if not telemetry.monitors.logMonitor then
        logger.warn("Telemetry", "No log monitor available for system info display")
        return
    end
    
    local monitor = telemetry.monitors.logMonitor.peripheral
    local report = detector.generateSystemReport(telemetry.systemInfo)
    
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.cyan)
    monitor.write("SYSTEM INFORMATION")
    
    local y = 3
    for _, line in ipairs(report) do
        if y > telemetry.monitors.logMonitor.height then
            break
        end
        
        monitor.setCursorPos(1, y)
        if line:find("===") then
            monitor.setTextColor(colors.yellow)
        elseif line:find(":") then
            monitor.setTextColor(colors.white)
        else
            monitor.setTextColor(colors.lightGray)
        end
        
        -- Truncate line if too long
        if #line > telemetry.monitors.logMonitor.width then
            line = line:sub(1, telemetry.monitors.logMonitor.width - 3) .. "..."
        end
        
        monitor.write(line)
        y = y + 1
    end
    
    logger.info("Telemetry", "System information displayed on log monitor")
end

-- Monitor system health
function telemetry.monitorHealth()
    local health = {
        timestamp = os.clock(),
        memoryUsage = 0, -- Memory tracking not available in ComputerCraft
        uptime = os.clock(),
        peripheralStatus = {}
    }
    
    -- Check peripheral connectivity
    for _, speaker in ipairs(telemetry.systemInfo.speakers) do
        health.peripheralStatus[speaker.side] = peripheral.isPresent(speaker.side)
    end
    
    for _, monitor in ipairs(telemetry.systemInfo.monitors) do
        health.peripheralStatus[monitor.side] = peripheral.isPresent(monitor.side)
    end
    
    for _, modem in ipairs(telemetry.systemInfo.modems) do
        health.peripheralStatus[modem.side] = peripheral.isPresent(modem.side)
    end
    
    -- Log health information
    logger.debug("Telemetry", "System health check completed")
    logger.debug("Telemetry", "Uptime: " .. string.format("%.1f", health.uptime) .. " seconds")
    
    -- Check for disconnected peripherals
    for side, isPresent in pairs(health.peripheralStatus) do
        if not isPresent then
            logger.warn("Telemetry", "Peripheral disconnected: " .. side)
        end
    end
    
    return health
end

-- Performance monitoring
function telemetry.startPerformanceMonitoring()
    telemetry.performanceData = {
        startTime = os.clock(),
        eventCounts = {},
        lastCheck = os.clock()
    }
    
    logger.info("Telemetry", "Performance monitoring started")
end

-- Log performance event
function telemetry.logPerformanceEvent(eventType)
    if not telemetry.performanceData then
        return
    end
    
    telemetry.performanceData.eventCounts[eventType] = (telemetry.performanceData.eventCounts[eventType] or 0) + 1
    
    -- Log event counts periodically instead of memory usage
    local currentTime = os.clock()
    if currentTime - telemetry.performanceData.lastCheck > 30 then -- Log every 30 seconds
        local totalEvents = 0
        for _, count in pairs(telemetry.performanceData.eventCounts) do
            totalEvents = totalEvents + count
        end
        logger.debug("Performance", "Total events processed: " .. totalEvents)
        telemetry.performanceData.lastCheck = currentTime
    end
end

-- Get performance summary
function telemetry.getPerformanceSummary()
    if not telemetry.performanceData then
        return nil
    end
    
    local runtime = os.clock() - telemetry.performanceData.startTime
    local summary = {
        runtime = runtime,
        memoryUsage = 0, -- Memory tracking not available in ComputerCraft
        eventCounts = telemetry.performanceData.eventCounts,
        eventsPerSecond = {}
    }
    
    -- Calculate events per second
    for eventType, count in pairs(telemetry.performanceData.eventCounts) do
        summary.eventsPerSecond[eventType] = count / runtime
    end
    
    return summary
end

-- Emergency logging (always logs regardless of level)
function telemetry.emergency(module, message)
    logger.log(logger.LEVELS.FATAL, module, "EMERGENCY: " .. message)
    
    -- Also write to emergency log file
    local emergencyFile = fs.open("musicplayer/logs/emergency.log", "a")
    if emergencyFile then
        emergencyFile.writeLine(os.date("%Y-%m-%d %H:%M:%S") .. " [EMERGENCY] [" .. module .. "] " .. message)
        emergencyFile.close()
    end
    
    -- Display on terminal regardless of current display
    local currentTerm = term.current()
    term.restore()
    term.setTextColor(colors.red)
    print("[EMERGENCY] " .. module .. ": " .. message)
    term.setTextColor(colors.white)
    if currentTerm ~= term then
        term.redirect(currentTerm)
    end
end

-- Cleanup telemetry system
function telemetry.cleanup()
    logger.info("Telemetry", "Telemetry system shutting down")
    
    if telemetry.performanceData then
        local summary = telemetry.getPerformanceSummary()
        logger.info("Performance", "Final runtime: " .. string.format("%.2f", summary.runtime) .. " seconds")
        
        -- Log event summary instead of memory usage
        local totalEvents = 0
        for eventType, count in pairs(summary.eventCounts) do
            totalEvents = totalEvents + count
            logger.debug("Performance", eventType .. ": " .. count .. " events")
        end
        logger.info("Performance", "Total events processed: " .. totalEvents)
    end
    
    -- Export final logs
    logger.exportLogs()
    
    -- Restore terminal
    telemetry.switchToTerminal()
end

return telemetry 