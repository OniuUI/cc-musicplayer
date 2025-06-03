-- Bognesferga Radio - Main Entry Point
-- A comprehensive music and radio system for ComputerCraft with advanced telemetry

-- Import our modular components
local system_init = require("musicplayer.system_init")
local app_manager = require("musicplayer.app_manager")

-- Main application entry point
local function main()
    -- Initialize telemetry and system
    local success, telemetry, systemInfo, capabilities = pcall(system_init.initializeSystem)
    if not success then
        print("FATAL ERROR: Failed to initialize telemetry system")
        print("Error: " .. tostring(telemetry))
        return
    end
    
    local logger = telemetry.getLogger()
    
    -- Load all application modules
    local modules = system_init.loadModules(logger, telemetry)
    if not modules then
        telemetry.emergency("Startup", "Failed to load required modules")
        return
    end
    
    -- Check system requirements
    if not system_init.checkRequirements(capabilities, logger) then
        logger.fatal("Startup", "System requirements not met")
        return
    end
    
    -- Initialize application state
    local appState = app_manager.initAppState(systemInfo, capabilities, modules, telemetry, logger)
    
    -- Run the main application loop
    app_manager.runMainLoop(appState, logger, telemetry)
    
    -- Cleanup and shutdown
    app_manager.cleanup(telemetry)
end

-- Start the application with global error handling
local function safeMain()
    local success, error = pcall(main)
    if not success then
        term.restore() -- Ensure we're back on terminal
        term.setTextColor(colors.red)
        print("FATAL ERROR in Bognesferga Radio:")
        print(tostring(error))
        print()
        print("Please check the log files in musicplayer/logs/")
        term.setTextColor(colors.white)
        
        -- Try to log the error if telemetry is available
        local telemetry = require("musicplayer.telemetry.telemetry")
        if telemetry then
            telemetry.emergency("Fatal", tostring(error))
        end
    end
end

-- Start the application
safeMain() 