-- Application state management module for Bognesferga Radio
-- Handles app state initialization and management

local app_manager = {}

-- Initialize the application state with all necessary components
function app_manager.initAppState(systemInfo, capabilities, modules, telemetry, logger)
    logger.info("Startup", "Initializing application state...")
    
    -- Switch to application display if available
    telemetry.switchToAppDisplay()
    
    local width, height = term.getSize()
    logger.debug("Startup", "Display size: " .. width .. "x" .. height)
    
    local appState = {
        width = width,
        height = height,
        mode = "menu", -- menu, youtube, radio_client, radio_host
        menuState = nil,
        musicState = nil,
        radioState = nil,
        systemInfo = systemInfo,
        capabilities = capabilities,
        telemetry = telemetry,
        modules = modules
    }
    
    -- Initialize menu state
    if modules.menu then
        appState.menuState = modules.menu.init()
        logger.debug("Startup", "Menu state initialized")
    end
    
    logger.info("Startup", "Application state initialized")
    return appState
end

-- Main application loop with comprehensive error handling
function app_manager.runMainLoop(appState, logger, telemetry)
    local mode_handlers = require("musicplayer.mode_handlers")
    
    logger.info("Startup", "Bognesferga Radio fully initialized")
    
    -- Main application loop
    while true do
        telemetry.logPerformanceEvent("main_loop")
        
        -- Monitor system health periodically
        if math.random() < 0.01 then -- 1% chance per loop
            telemetry.monitorHealth()
        end
        
        local success, result = pcall(function()
            if appState.mode == "menu" then
                return mode_handlers.runMainMenu(appState, logger, telemetry)
            elseif appState.mode == "youtube" then
                mode_handlers.runYouTubePlayer(appState, logger, telemetry)
                return true
            elseif appState.mode == "radio_client" then
                mode_handlers.runRadioClient(appState, logger, telemetry)
                return true
            elseif appState.mode == "radio_host" then
                mode_handlers.runRadioHost(appState, logger, telemetry)
                return true
            end
            return true
        end)
        
        if not success then
            logger.error("Main", "Error in application loop: " .. tostring(result))
            appState.mode = "menu" -- Return to menu on error
        elseif result == false then
            break -- Exit requested
        end
    end
    
    logger.info("Startup", "Application shutting down")
end

-- Cleanup and shutdown procedures
function app_manager.cleanup(telemetry)
    -- Cleanup
    telemetry.cleanup()
    
    -- Final message
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    print("Thanks for using Bognesferga Radio!")
    
    -- Show performance summary
    local perfSummary = telemetry.getPerformanceSummary()
    if perfSummary then
        print("Session runtime: " .. string.format("%.2f", perfSummary.runtime) .. " seconds")
        
        -- Show event summary instead of memory usage
        local totalEvents = 0
        for _, count in pairs(perfSummary.eventCounts) do
            totalEvents = totalEvents + count
        end
        if totalEvents > 0 then
            print("Total events processed: " .. totalEvents)
        end
    end
end

return app_manager 