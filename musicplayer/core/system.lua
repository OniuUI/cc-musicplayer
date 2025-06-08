-- Core System Module for Bognesferga Radio
-- Initializes and coordinates all system components

local config = require("musicplayer/config")
local common = require("musicplayer/utils/common")

-- Core modules
local errorHandler = require("musicplayer/middleware/error_handler")

-- Telemetry and logging
local telemetry = require("musicplayer/telemetry/telemetry")

-- Network and audio
local httpClient = require("musicplayer/network/http_client")
local speakerManager = require("musicplayer/audio/speaker_manager")

-- UI components
local components = require("musicplayer/ui/components")

local system = {}

-- Initialize the entire system
function system.init()
    print("DEBUG: Starting system initialization...")
    
    local systemState = {
        initialized = false,
        telemetry = nil,
        errorHandler = nil,
        httpClient = nil,
        speakerManager = nil,
        logger = nil,
        startTime = os.clock()
    }
    
    -- Step 1: Initialize telemetry system with logging config
    print("DEBUG: Step 1 - Initializing telemetry...")
    local success, telemetryInstance = pcall(telemetry.init, config.logging)
    if not success then
        print("FATAL: Failed to initialize telemetry system")
        print("Error: " .. tostring(telemetryInstance))
        return nil
    end
    print("DEBUG: Telemetry initialized successfully")
    
    systemState.telemetry = telemetryInstance
    systemState.logger = telemetryInstance.getLogger()
    
    systemState.logger.info("System", "Starting Bognesferga Radio v" .. config.version)
    
    -- Log configuration status
    if systemState.logger.isFileSavingEnabled() then
        systemState.logger.info("System", "Log file saving enabled")
    else
        systemState.logger.info("System", "Log file saving disabled - logs only in memory and on monitor")
    end
    
    -- Step 2: Initialize error handler
    print("DEBUG: Step 2 - Initializing error handler...")
    systemState.errorHandler = errorHandler.init(systemState.telemetry)
    systemState.logger.info("System", "Error handling middleware initialized")
    print("DEBUG: Error handler initialized successfully")
    
    -- Step 3: Initialize HTTP client
    print("DEBUG: Step 3 - Initializing HTTP client...")
    systemState.httpClient = httpClient.init(systemState.errorHandler)
    systemState.logger.info("System", "HTTP client initialized")
    print("DEBUG: HTTP client initialized successfully")
    
    -- Step 4: Initialize speaker manager
    print("DEBUG: Step 4 - Initializing speaker manager...")
    systemState.speakerManager = speakerManager.init(systemState.errorHandler, systemState.telemetry)
    print("DEBUG: Speaker manager initialized successfully")
    
    -- Step 5: Check system requirements
    print("DEBUG: Step 5 - Checking system requirements...")
    local requirementsOk = system.checkRequirements(systemState)
    if not requirementsOk then
        systemState.logger.fatal("System", "System requirements not met")
        return nil
    end
    print("DEBUG: System requirements check passed")
    
    -- Step 6: Test connectivity
    print("DEBUG: Step 6 - Testing connectivity...")
    system.testConnectivity(systemState)
    print("DEBUG: Connectivity test completed")
    
    systemState.initialized = true
    systemState.logger.info("System", "System initialization completed successfully")
    print("DEBUG: System initialization completed successfully")
    
    return systemState
end

-- Check system requirements
function system.checkRequirements(systemState)
    local logger = systemState.logger
    local requirements = {
        speakers = true,
        http = true,
        monitors = false -- Optional
    }
    
    -- Check speakers
    if systemState.speakerManager.getSpeakerCount() == 0 then
        logger.error("System", "No speakers detected - audio playback will not work")
        requirements.speakers = false
    else
        logger.info("System", "Found " .. systemState.speakerManager.getSpeakerCount() .. " speakers")
    end
    
    -- Check HTTP connectivity
    if not http then
        logger.fatal("System", "HTTP API not available")
        requirements.http = false
    else
        logger.info("System", "HTTP API available")
    end
    
    -- Check monitors (optional)
    local capabilities = systemState.telemetry.getCapabilities()
    if capabilities.hasDualScreen then
        logger.info("System", "Dual-screen setup detected")
        requirements.monitors = true
    else
        logger.info("System", "Single-screen setup (terminal only)")
    end
    
    -- Determine if requirements are met
    local allRequired = requirements.speakers and requirements.http
    
    if allRequired then
        logger.info("System", "All system requirements met")
    else
        logger.error("System", "Critical system requirements not met")
    end
    
    return allRequired
end

-- Test network connectivity
function system.testConnectivity(systemState)
    local logger = systemState.logger
    
    logger.info("System", "Testing network connectivity...")
    
    local success, result = systemState.httpClient.checkConnectivity()
    
    if success then
        logger.info("System", "Network connectivity test passed")
    else
        logger.warn("System", "Network connectivity test failed: " .. tostring(result))
        logger.warn("System", "Some features may not work properly")
    end
end

-- Get system status
function system.getStatus(systemState)
    if not systemState or not systemState.initialized then
        return {
            initialized = false,
            uptime = 0,
            error = "System not initialized"
        }
    end
    
    local uptime = os.clock() - systemState.startTime
    local speakerStatus = systemState.speakerManager.getStatus()
    local httpStats = systemState.httpClient.getStats()
    local errorStats = systemState.errorHandler.getStats()
    
    return {
        initialized = true,
        uptime = uptime,
        version = config.version,
        speakers = speakerStatus,
        network = httpStats,
        errors = errorStats,
        telemetry = {
            hasDualScreen = systemState.telemetry.hasDualScreen(),
            logLevel = systemState.logger.getLevel()
        }
    }
end

-- Perform system health check
function system.healthCheck(systemState)
    if not systemState or not systemState.initialized then
        return {
            healthy = false,
            issues = {"System not initialized"}
        }
    end
    
    local issues = {}
    local warnings = {}
    
    -- Check speakers
    local speakerHealth = systemState.speakerManager.checkSpeakerHealth()
    if speakerHealth.activeSpeakers == 0 then
        table.insert(issues, "No active speakers")
    elseif speakerHealth.disconnectedSpeakers > 0 then
        table.insert(warnings, speakerHealth.disconnectedSpeakers .. " speakers disconnected")
    end
    
    -- Check error rate
    local errorStats = systemState.errorHandler.getStats()
    if errorStats.totalErrors > 10 then
        table.insert(warnings, "High error count: " .. errorStats.totalErrors)
    end
    
    -- Check network connectivity
    local networkOk, networkError = systemState.httpClient.checkConnectivity()
    if not networkOk then
        table.insert(issues, "Network connectivity lost: " .. tostring(networkError))
    end
    
    local healthy = #issues == 0
    
    return {
        healthy = healthy,
        issues = issues,
        warnings = warnings,
        speakerHealth = speakerHealth
    }
end

-- Cleanup system resources
function system.cleanup(systemState)
    if not systemState then
        return
    end
    
    if systemState.logger then
        systemState.logger.info("System", "Starting system cleanup")
    end
    
    -- Stop audio playback
    if systemState.speakerManager then
        systemState.speakerManager.stopAll()
    end
    
    -- Cancel network requests
    if systemState.httpClient then
        systemState.httpClient.cancelAllRequests()
    end
    
    -- Cleanup error handler
    if systemState.errorHandler then
        systemState.errorHandler.cleanup()
    end
    
    -- Switch back to terminal
    if systemState.telemetry then
        systemState.telemetry.switchToTerminal()
    end
    
    if systemState.logger then
        systemState.logger.info("System", "System cleanup completed")
    end
end

-- Emergency shutdown
function system.emergencyShutdown(systemState, reason)
    reason = reason or "Unknown emergency"
    
    if systemState and systemState.errorHandler then
        systemState.errorHandler.emergencyShutdown(reason, "System")
    else
        -- Fallback emergency shutdown
        term.restore()
        term.setTextColor(colors.red)
        print("EMERGENCY SHUTDOWN: " .. reason)
        term.setTextColor(colors.white)
        error("Emergency shutdown: " .. reason, 0)
    end
end

-- Restart system components
function system.restart(systemState)
    if not systemState or not systemState.initialized then
        return false, "System not initialized"
    end
    
    systemState.logger.info("System", "Restarting system components")
    
    -- Restart speaker manager
    local speakerCount = systemState.speakerManager.detectSpeakers()
    local reactivated = systemState.speakerManager.reactivateSpeakers()
    
    systemState.logger.info("System", "Detected " .. speakerCount .. " speakers, reactivated " .. reactivated)
    
    -- Test connectivity again
    system.testConnectivity(systemState)
    
    systemState.logger.info("System", "System restart completed")
    
    return true
end

-- Get system information for display
function system.getSystemInfo(systemState)
    if not systemState or not systemState.initialized then
        return {}
    end
    
    local status = system.getStatus(systemState)
    local health = system.healthCheck(systemState)
    
    return {
        version = config.version,
        uptime = common.formatTime(status.uptime),
        speakers = {
            total = status.speakers.health.totalSpeakers,
            active = status.speakers.health.activeSpeakers,
            volume = status.speakers.volume
        },
        network = {
            timeout = status.network.timeout,
            retries = status.network.maxRetries
        },
        errors = {
            total = status.errors.totalErrors,
            recent = status.errors.recentErrors
        },
        health = {
            status = health.healthy and "Healthy" or "Issues Detected",
            issues = health.issues,
            warnings = health.warnings
        },
        telemetry = status.telemetry
    }
end

return system 