-- Logger module for Bognesferga Radio
-- Handles file logging and dual-screen display

local logger = {}

-- Log levels
logger.LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

-- Level names for display
logger.LEVEL_NAMES = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "FATAL"
}

-- Level colors for display
logger.LEVEL_COLORS = {
    [1] = colors.lightGray,
    [2] = colors.white,
    [3] = colors.yellow,
    [4] = colors.orange,
    [5] = colors.red
}

-- Initialize logger
function logger.init(logMonitor, logConfig)
    logger.logMonitor = logMonitor
    
    -- Use config object or fallback to old string/number format for backwards compatibility
    if type(logConfig) == "table" then
        -- New config format
        logger.config = logConfig
        logger.logLevel = logger.parseLogLevel(logConfig.level or "INFO")
        logger.maxLogLines = logConfig.max_buffer_lines or 1000
        logger.logFile = logConfig.session_log_file or "musicplayer/logs/session.log"
        logger.emergencyLogFile = logConfig.emergency_log_file or "musicplayer/logs/emergency.log"
        logger.saveToFile = logConfig.save_to_file ~= false -- Default to true
    else
        -- Backwards compatibility with old format
        logger.config = {
            save_to_file = true,
            level = logConfig or "INFO",
            max_buffer_lines = 1000,
            session_log_file = "musicplayer/logs/session.log",
            emergency_log_file = "musicplayer/logs/emergency.log",
            auto_cleanup = { enabled = false }
        }
        logger.logLevel = logger.parseLogLevel(logConfig or "INFO")
        logger.maxLogLines = 1000
        logger.logFile = "musicplayer/logs/session.log"
        logger.emergencyLogFile = "musicplayer/logs/emergency.log"
        logger.saveToFile = true
    end
    
    logger.logBuffer = {}
    
    -- Create logs directory if file saving is enabled
    if logger.saveToFile and not fs.exists("musicplayer/logs") then
        fs.makeDir("musicplayer/logs")
    end
    
    -- Perform log cleanup if enabled
    if logger.saveToFile and logger.config.auto_cleanup and logger.config.auto_cleanup.enabled then
        logger.performLogCleanup()
    end
    
    -- Initialize log file with session header (only if file saving is enabled)
    if logger.saveToFile then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        logger.writeToFile("=== NEW SESSION STARTED: " .. timestamp .. " ===")
    end
    
    -- Clear log monitor if available
    if logger.logMonitor then
        logger.logMonitor.clear()
        logger.logMonitor.setCursorPos(1, 1)
        logger.logMonitor.setTextColor(colors.cyan)
        logger.logMonitor.write("Bognesferga Radio - Debug Console")
        logger.logMonitor.setCursorPos(1, 2)
        logger.logMonitor.setTextColor(colors.lightGray)
        logger.logMonitor.write(string.rep("=", 40))
        logger.logMonitor.setCursorPos(1, 3)
    end
    
    local statusMsg = "Logging system initialized"
    if not logger.saveToFile then
        statusMsg = statusMsg .. " (file saving disabled)"
    end
    logger.log(logger.LEVELS.INFO, "Logger", statusMsg)
end

-- Parse log level from string or number
function logger.parseLogLevel(level)
    if type(level) == "string" then
        local stringToLevel = {
            DEBUG = logger.LEVELS.DEBUG,
            INFO = logger.LEVELS.INFO,
            WARN = logger.LEVELS.WARN,
            ERROR = logger.LEVELS.ERROR,
            FATAL = logger.LEVELS.FATAL
        }
        return stringToLevel[level:upper()] or logger.LEVELS.INFO
    else
        return level or logger.LEVELS.INFO
    end
end

-- Write to log file (only if file saving is enabled)
function logger.writeToFile(message)
    if not logger.saveToFile then
        return -- Skip file writing if disabled
    end
    
    local file = fs.open(logger.logFile, "a")
    if file then
        file.writeLine(message)
        file.close()
    end
end

-- Write to emergency log file (always enabled for critical errors)
function logger.writeToEmergencyFile(message)
    if not logger.saveToFile then
        return -- Even emergency logs respect the file saving setting
    end
    
    local file = fs.open(logger.emergencyLogFile, "a")
    if file then
        file.writeLine(message)
        file.close()
    end
end

-- Perform automatic log cleanup
function logger.performLogCleanup()
    if not logger.config.auto_cleanup or not logger.config.auto_cleanup.enabled then
        return
    end
    
    local logsDir = "musicplayer/logs"
    if not fs.exists(logsDir) then
        return
    end
    
    local logFiles = {}
    local files = fs.list(logsDir)
    
    -- Collect log files with their modification times
    for _, filename in ipairs(files) do
        if filename:match("%.log$") then
            local filepath = fs.combine(logsDir, filename)
            local attributes = fs.attributes(filepath)
            if attributes then
                table.insert(logFiles, {
                    name = filename,
                    path = filepath,
                    modified = attributes.modified or 0
                })
            end
        end
    end
    
    -- Sort by modification time (newest first)
    table.sort(logFiles, function(a, b) return a.modified > b.modified end)
    
    local maxFiles = logger.config.auto_cleanup.max_log_files or 5
    local maxAge = (logger.config.auto_cleanup.max_file_age_days or 7) * 24 * 60 * 60 * 1000 -- Convert days to milliseconds
    local currentTime = os.epoch("utc")
    local deletedCount = 0
    
    -- Delete old files beyond the maximum count
    for i = maxFiles + 1, #logFiles do
        fs.delete(logFiles[i].path)
        deletedCount = deletedCount + 1
    end
    
    -- Delete files older than max age
    for i = 1, math.min(maxFiles, #logFiles) do
        local fileAge = currentTime - logFiles[i].modified
        if fileAge > maxAge then
            fs.delete(logFiles[i].path)
            deletedCount = deletedCount + 1
        end
    end
    
    if deletedCount > 0 then
        logger.log(logger.LEVELS.INFO, "Logger", "Cleaned up " .. deletedCount .. " old log files")
    end
end

-- Format log message
function logger.formatMessage(level, module, message)
    local timestamp = os.date("%H:%M:%S")
    local levelName = logger.LEVEL_NAMES[level] or "UNKNOWN"
    return string.format("[%s] [%s] [%s] %s", timestamp, levelName, module, message)
end

-- Main logging function
function logger.log(level, module, message)
    if level < logger.logLevel then
        return
    end
    
    local formattedMessage = logger.formatMessage(level, module, message)
    
    -- Write to file (only if enabled)
    if logger.saveToFile then
        logger.writeToFile(formattedMessage)
    end
    
    -- Add to buffer
    table.insert(logger.logBuffer, {
        level = level,
        module = module,
        message = message,
        formatted = formattedMessage,
        timestamp = os.clock()
    })
    
    -- Trim buffer if too large
    if #logger.logBuffer > logger.maxLogLines then
        table.remove(logger.logBuffer, 1)
    end
    
    -- Display on log monitor if available
    if logger.logMonitor then
        logger.displayOnMonitor(level, formattedMessage)
    end
    
    -- Also print to main terminal for critical errors
    if level >= logger.LEVELS.ERROR then
        term.setTextColor(logger.LEVEL_COLORS[level])
        print("[ERROR] " .. module .. ": " .. message)
        term.setTextColor(colors.white)
    end
end

-- Display message on log monitor
function logger.displayOnMonitor(level, formattedMessage)
    if not logger.logMonitor then return end
    
    local width, height = logger.logMonitor.getSize()
    local x, y = logger.logMonitor.getCursorPos()
    
    -- Scroll if at bottom
    if y >= height then
        logger.logMonitor.scroll(1)
        y = height
    end
    
    -- Set color based on log level
    logger.logMonitor.setTextColor(logger.LEVEL_COLORS[level])
    
    -- Wrap long messages
    local lines = logger.wrapText(formattedMessage, width)
    for _, line in ipairs(lines) do
        logger.logMonitor.setCursorPos(1, y)
        logger.logMonitor.clearLine()
        logger.logMonitor.write(line)
        y = y + 1
        if y > height then
            logger.logMonitor.scroll(1)
            y = height
        end
    end
    
    logger.logMonitor.setCursorPos(1, y)
end

-- Wrap text to fit monitor width
function logger.wrapText(text, width)
    local lines = {}
    local currentLine = ""
    
    for word in text:gmatch("%S+") do
        if #currentLine + #word + 1 <= width then
            if #currentLine > 0 then
                currentLine = currentLine .. " " .. word
            else
                currentLine = word
            end
        else
            if #currentLine > 0 then
                table.insert(lines, currentLine)
            end
            currentLine = word
        end
    end
    
    if #currentLine > 0 then
        table.insert(lines, currentLine)
    end
    
    return lines
end

-- Convenience functions for different log levels
function logger.debug(module, message)
    logger.log(logger.LEVELS.DEBUG, module, message)
end

function logger.info(module, message)
    logger.log(logger.LEVELS.INFO, module, message)
end

function logger.warn(module, message)
    logger.log(logger.LEVELS.WARN, module, message)
end

function logger.error(module, message)
    logger.log(logger.LEVELS.ERROR, module, message)
end

function logger.fatal(module, message)
    logger.log(logger.LEVELS.FATAL, module, message)
end

-- Get recent logs for display
function logger.getRecentLogs(count)
    count = count or 50
    local startIndex = math.max(1, #logger.logBuffer - count + 1)
    local recentLogs = {}
    
    for i = startIndex, #logger.logBuffer do
        table.insert(recentLogs, logger.logBuffer[i])
    end
    
    return recentLogs
end

-- Clear logs
function logger.clearLogs()
    logger.logBuffer = {}
    if logger.logMonitor then
        logger.logMonitor.clear()
        logger.logMonitor.setCursorPos(1, 1)
    end
    logger.info("Logger", "Logs cleared")
end

-- Export logs to file
function logger.exportLogs(filename)
    filename = filename or ("musicplayer/logs/export_" .. os.date("%Y%m%d_%H%M%S") .. ".log")
    
    local file = fs.open(filename, "w")
    if file then
        for _, logEntry in ipairs(logger.logBuffer) do
            file.writeLine(logEntry.formatted)
        end
        file.close()
        logger.info("Logger", "Logs exported to " .. filename)
        return true
    else
        logger.error("Logger", "Failed to export logs to " .. filename)
        return false
    end
end

-- Get current log level
function logger.getLevel()
    return logger.logLevel
end

-- Get logging configuration
function logger.getConfig()
    return logger.config
end

-- Check if file saving is enabled
function logger.isFileSavingEnabled()
    return logger.saveToFile
end

-- Emergency logging (always logs regardless of level, and always tries to save to emergency file)
function logger.emergency(module, message)
    local formattedMessage = logger.formatMessage(logger.LEVELS.FATAL, module, "EMERGENCY: " .. message)
    
    -- Always log to buffer regardless of level
    table.insert(logger.logBuffer, {
        level = logger.LEVELS.FATAL,
        module = module,
        message = "EMERGENCY: " .. message,
        formatted = formattedMessage,
        timestamp = os.clock()
    })
    
    -- Write to emergency log file if file saving is enabled
    if logger.saveToFile then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        logger.writeToEmergencyFile(timestamp .. " " .. formattedMessage)
    end
    
    -- Display on log monitor if available
    if logger.logMonitor then
        logger.displayOnMonitor(logger.LEVELS.FATAL, formattedMessage)
    end
    
    -- Always display on terminal for emergencies
    term.setTextColor(colors.red)
    print("[EMERGENCY] " .. module .. ": " .. message)
    term.setTextColor(colors.white)
end

return logger 