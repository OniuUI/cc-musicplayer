-- System initialization module for Bognesferga Radio
-- Handles telemetry setup, module loading, and requirements checking

local system_init = {}

-- Initialize telemetry system
function system_init.initializeSystem()
    local telemetry = require("musicplayer.telemetry.telemetry")
    
    -- Initialize telemetry with INFO level logging
    telemetry.init(telemetry.getLogger().LEVELS.INFO)
    local logger = telemetry.getLogger()
    
    logger.info("Startup", "Bognesferga Radio starting up...")
    logger.info("Startup", "System capabilities detected")
    
    -- Start performance monitoring
    telemetry.startPerformanceMonitoring()
    
    -- Display system info on log monitor if available
    if telemetry.hasDualScreen() then
        logger.info("Startup", "Dual screen setup detected - using separate displays")
        telemetry.displaySystemInfo()
    else
        logger.info("Startup", "Single screen setup - using terminal")
    end
    
    return telemetry, telemetry.getSystemInfo(), telemetry.getCapabilities()
end

-- Load all application modules with error handling
function system_init.loadModules(logger, telemetry)
    logger.info("Startup", "Loading application modules...")
    
    local modules = {}
    local moduleList = {
        "config", "state", "ui", "input", "audio", "network", 
        "main", "menu", "radio", "radio_ui"
    }
    
    for _, moduleName in ipairs(moduleList) do
        local success, module = pcall(require, "musicplayer." .. moduleName)
        if success then
            modules[moduleName] = module
            logger.debug("Startup", "Loaded module: " .. moduleName)
        else
            logger.error("Startup", "Failed to load module " .. moduleName .. ": " .. tostring(module))
            telemetry.emergency("Startup", "Critical module load failure: " .. moduleName)
            return nil
        end
    end
    
    logger.info("Startup", "All modules loaded successfully")
    return modules
end

-- Check system requirements and display warnings/errors
function system_init.checkRequirements(capabilities, logger)
    logger.info("Startup", "Checking system requirements...")
    
    local warnings = {}
    local errors = {}
    
    if not capabilities.canPlayAudio then
        table.insert(warnings, "No speakers detected - audio playback unavailable")
        logger.warn("Requirements", "No speakers found")
    end
    
    if not capabilities.canUseNetwork then
        table.insert(warnings, "No modems detected - network features unavailable")
        logger.warn("Requirements", "No modems found")
    end
    
    if capabilities.hasExternalDisplay then
        logger.info("Requirements", "External display available")
    end
    
    if capabilities.canUseDualScreen then
        logger.info("Requirements", "Dual screen setup available")
    end
    
    -- Display warnings to user
    if #warnings > 0 then
        term.setTextColor(colors.yellow)
        print("Warnings:")
        for _, warning in ipairs(warnings) do
            print("• " .. warning)
        end
        term.setTextColor(colors.white)
        print()
    end
    
    if #errors > 0 then
        term.setTextColor(colors.red)
        print("Errors:")
        for _, error in ipairs(errors) do
            print("• " .. error)
        end
        term.setTextColor(colors.white)
        return false
    end
    
    logger.info("Requirements", "System requirements check completed")
    return true
end

return system_init 