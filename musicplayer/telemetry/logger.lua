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
function logger.init(logMonitor, logLevel)
    logger.logMonitor = logMonitor
    logger.logLevel = logLevel or logger.LEVELS.INFO
    logger.logFile = "musicplayer/logs/session.log"
    logger.maxLogLines = 1000
    logger.logBuffer = {}
    
    -- Create logs directory if it doesn't exist
    if not fs.exists("musicplayer/logs") then
        fs.makeDir("musicplayer/logs")
    end
    
    -- Initialize log file with session header
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    logger.writeToFile("=== NEW SESSION STARTED: " .. timestamp .. " ===")
    
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
    
    logger.log(logger.LEVELS.INFO, "Logger", "Logging system initialized")
end

-- Write to log file
function logger.writeToFile(message)
    local file = fs.open(logger.logFile, "a")
    if file then
        file.writeLine(message)
        file.close()
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
    
    -- Write to file
    logger.writeToFile(formattedMessage)
    
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

return logger 