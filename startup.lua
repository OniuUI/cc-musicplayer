-- Bognesferga Radio - Main Entry Point
-- A comprehensive music and radio system for ComputerCraft with advanced telemetry

-- Import the new core system
local system = require("musicplayer/core/system")
local app_manager = require("musicplayer/app_manager")
local config = require("musicplayer/config")

-- Main application entry point
local function main()
    -- Initialize the core system
    local systemState = system.init()
    if not systemState then
        print("FATAL ERROR: Failed to initialize core system")
        return
    end
    
    local logger = systemState.logger
    logger.info("Startup", "Core system initialized successfully")
    
    -- Initialize application state using the new system
    local appState = app_manager.initAppState(
        systemState.telemetry.getSystemInfo(),
        systemState.telemetry.getCapabilities(),
        {
            system = systemState,
            httpClient = systemState.httpClient,
            speakerManager = systemState.speakerManager,
            errorHandler = systemState.errorHandler
        },
        systemState.telemetry,
        logger
    )
    
    -- Run the main application loop
    app_manager.runMainLoop(appState, logger, systemState.telemetry)
    
    -- Cleanup and shutdown
    system.cleanup(systemState)
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
        if config.logging.save_to_file then
            print("Please check the log files in musicplayer/logs/")
        else
            print("Log file saving is disabled - check the debug monitor for details")
        end
        term.setTextColor(colors.white)
        
        -- Try to log the error if telemetry is available
        local telemetrySuccess, telemetry = pcall(require, "musicplayer/telemetry/telemetry")
        if telemetrySuccess and telemetry then
            -- Use emergency logging config for fatal errors
            local emergencyLogConfig = {
                save_to_file = true, -- Always save emergency logs
                level = "ERROR",
                max_buffer_lines = 100,
                session_log_file = config.logging.session_log_file,
                emergency_log_file = config.logging.emergency_log_file,
                auto_cleanup = { enabled = false } -- Don't cleanup during emergency
            }
            local telemetryInstance = telemetry.init(emergencyLogConfig)
            if telemetryInstance then
                telemetryInstance.emergency("Fatal", tostring(error))
            end
        end
    end
end

-- Start the application
safeMain() 