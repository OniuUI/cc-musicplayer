-- Error handling middleware for Bognesferga Radio
-- Provides comprehensive error catching, logging, and recovery mechanisms

local common = require("musicplayer/utils/common")

local errorHandler = {}

-- Initialize error handler with telemetry system
function errorHandler.init(telemetry)
    errorHandler.telemetry = telemetry
    errorHandler.logger = telemetry and telemetry.getLogger()
    errorHandler.errorCount = 0
    errorHandler.lastErrors = {}
    errorHandler.maxStoredErrors = 10
    
    -- Set up global error handler
    errorHandler.setupGlobalHandler()
    
    if errorHandler.logger then
        errorHandler.logger.info("ErrorHandler", "Error handling middleware initialized")
    end
    
    return errorHandler
end

-- Set up global error handler for unhandled errors
function errorHandler.setupGlobalHandler()
    -- Store original error function
    errorHandler.originalError = error
    
    -- Override global error function
    _G.error = function(message, level)
        level = level or 1
        errorHandler.handleError("Global", message, level + 1)
        errorHandler.originalError(message, level + 1)
    end
end

-- Restore original error function
function errorHandler.restoreGlobalHandler()
    if errorHandler.originalError then
        _G.error = errorHandler.originalError
    end
end

-- Main error handling function
function errorHandler.handleError(context, errorMsg, level, additionalData)
    level = level or 1
    context = context or "Unknown"
    
    -- Increment error counter
    errorHandler.errorCount = errorHandler.errorCount + 1
    
    -- Create error record
    local errorRecord = {
        id = errorHandler.errorCount,
        timestamp = common.getTimestamp(),
        context = context,
        message = tostring(errorMsg),
        level = level,
        additionalData = additionalData,
        stackTrace = debug and debug.traceback() or "Stack trace not available"
    }
    
    -- Store error in recent errors list
    table.insert(errorHandler.lastErrors, 1, errorRecord)
    if #errorHandler.lastErrors > errorHandler.maxStoredErrors then
        table.remove(errorHandler.lastErrors)
    end
    
    -- Log the error
    errorHandler.logError(errorRecord)
    
    -- Display error if appropriate
    errorHandler.displayError(errorRecord)
    
    return errorRecord
end

-- Log error to telemetry system
function errorHandler.logError(errorRecord)
    if not errorHandler.logger then
        -- Fallback to print if no logger available
        print("ERROR [" .. errorRecord.context .. "]: " .. errorRecord.message)
        return
    end
    
    -- Choose appropriate log level
    if errorRecord.level >= 3 then
        errorHandler.logger.fatal(errorRecord.context, errorRecord.message)
    elseif errorRecord.level >= 2 then
        errorHandler.logger.error(errorRecord.context, errorRecord.message)
    else
        errorHandler.logger.warn(errorRecord.context, errorRecord.message)
    end
    
    -- Log additional details at debug level
    if errorRecord.additionalData then
        errorHandler.logger.debug(errorRecord.context, "Additional data: " .. textutils.serialise(errorRecord.additionalData))
    end
    
    if errorRecord.stackTrace then
        errorHandler.logger.debug(errorRecord.context, "Stack trace: " .. errorRecord.stackTrace)
    end
end

-- Display error on screen if appropriate
function errorHandler.displayError(errorRecord)
    -- Only display critical errors on main screen
    if errorRecord.level >= 3 then
        if errorHandler.telemetry then
            errorHandler.telemetry.switchToTerminal()
        end
        
        term.setTextColor(colors.red)
        print("CRITICAL ERROR in " .. errorRecord.context .. ":")
        print(errorRecord.message)
        term.setTextColor(colors.white)
        
        if errorHandler.telemetry then
            errorHandler.telemetry.switchToAppDisplay()
        end
    end
end

-- Wrap a function with error handling
function errorHandler.wrap(func, context, onError)
    context = context or "WrappedFunction"
    
    return function(...)
        local success, result = pcall(func, ...)
        
        if success then
            return result
        else
            local errorRecord = errorHandler.handleError(context, result, 2)
            
            if onError then
                return onError(errorRecord, ...)
            else
                return nil
            end
        end
    end
end

-- Safe execution with error handling
function errorHandler.safeExecute(func, context, defaultReturn, ...)
    context = context or "SafeExecution"
    
    local success, result = pcall(func, ...)
    
    if success then
        return true, result
    else
        errorHandler.handleError(context, result, 1)
        return false, defaultReturn
    end
end

-- Async error handling for coroutines
function errorHandler.safeCoroutine(func, context)
    context = context or "Coroutine"
    
    return coroutine.create(function(...)
        local success, result = pcall(func, ...)
        
        if not success then
            errorHandler.handleError(context, result, 2)
        end
        
        return result
    end)
end

-- Network request error handling
function errorHandler.handleNetworkError(url, context, additionalData)
    context = context or "Network"
    
    local errorMsg = "Network request failed for URL: " .. tostring(url)
    
    return errorHandler.handleError(context, errorMsg, 1, {
        url = url,
        additionalData = additionalData
    })
end

-- Audio error handling
function errorHandler.handleAudioError(errorMsg, context, additionalData)
    context = context or "Audio"
    
    return errorHandler.handleError(context, errorMsg, 2, additionalData)
end

-- UI error handling
function errorHandler.handleUIError(errorMsg, context, additionalData)
    context = context or "UI"
    
    return errorHandler.handleError(context, errorMsg, 1, additionalData)
end

-- Get error statistics
function errorHandler.getStats()
    return {
        totalErrors = errorHandler.errorCount,
        recentErrors = #errorHandler.lastErrors,
        lastError = errorHandler.lastErrors[1]
    }
end

-- Get recent errors
function errorHandler.getRecentErrors(count)
    count = count or errorHandler.maxStoredErrors
    local result = {}
    
    for i = 1, math.min(count, #errorHandler.lastErrors) do
        table.insert(result, errorHandler.lastErrors[i])
    end
    
    return result
end

-- Clear error history
function errorHandler.clearHistory()
    errorHandler.lastErrors = {}
    if errorHandler.logger then
        errorHandler.logger.info("ErrorHandler", "Error history cleared")
    end
end

-- Emergency shutdown with error logging
function errorHandler.emergencyShutdown(reason, context)
    context = context or "System"
    reason = reason or "Unknown emergency condition"
    
    -- Log emergency
    if errorHandler.telemetry then
        errorHandler.telemetry.emergency(context, "Emergency shutdown: " .. reason)
    end
    
    -- Switch to terminal for final message
    if errorHandler.telemetry then
        errorHandler.telemetry.switchToTerminal()
    end
    
    term.setTextColor(colors.red)
    print("EMERGENCY SHUTDOWN")
    print("Reason: " .. reason)
    print("Context: " .. context)
    print("Check logs for details.")
    term.setTextColor(colors.white)
    
    -- Restore error handler
    errorHandler.restoreGlobalHandler()
    
    -- Force exit
    error("Emergency shutdown: " .. reason, 0)
end

-- Cleanup function
function errorHandler.cleanup()
    errorHandler.restoreGlobalHandler()
    
    if errorHandler.logger then
        errorHandler.logger.info("ErrorHandler", "Error handler cleanup completed")
    end
end

return errorHandler 