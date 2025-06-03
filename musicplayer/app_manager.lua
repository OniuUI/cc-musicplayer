-- Application Manager for Bognesferga Radio
-- Updated to use new modular architecture with feature-based organization

local mainMenu = require("musicplayer.features.menu.main_menu")
local youtubePlayer = require("musicplayer.features.youtube.youtube_player")
local radioClient = require("musicplayer.features.radio.radio_client")
local radioHost = require("musicplayer.features.radio.radio_host")

local app_manager = {}

function app_manager.initAppState(systemInfo, capabilities, systemModules, telemetry, logger)
    logger.info("AppManager", "Initializing application state...")
    
    -- Switch to application display if available
    telemetry.switchToAppDisplay()
    
    local width, height = term.getSize()
    logger.debug("AppManager", "Display size: " .. width .. "x" .. height)
    
    local state = {
        -- System information
        system_info = systemInfo,
        capabilities = capabilities,
        
        -- System modules
        system = systemModules.system,
        httpClient = systemModules.httpClient,
        speakerManager = systemModules.speakerManager,
        errorHandler = systemModules.errorHandler,
        
        -- Telemetry and logging
        telemetry = telemetry,
        logger = logger,
        
        -- Application state
        current_mode = "menu",
        running = true,
        
        -- Screen dimensions
        width = width,
        height = height,
        
        -- Feature states (initialized when needed)
        menuState = nil,
        youtubeState = nil,
        radioClientState = nil,
        radioHostState = nil
    }
    
    -- Initialize menu state
    state.menuState = mainMenu.init()
    logger.debug("AppManager", "Menu state initialized")
    
    logger.info("AppManager", "Application state initialized")
    return state
end

function app_manager.runMainLoop(appState, logger, telemetry)
    logger.info("AppManager", "Starting main application loop")
    logger.info("AppManager", "Bognesferga Radio fully initialized")
    
    while appState.running do
        -- Monitor system health periodically
        if math.random() < 0.01 then -- 1% chance per loop
            telemetry.monitorHealth()
        end
        
        telemetry.logPerformanceEvent("main_loop")
        
        local success, result = pcall(function()
            if appState.current_mode == "menu" then
                return app_manager.runMenu(appState)
            elseif appState.current_mode == "youtube" then
                return app_manager.runYouTube(appState)
            elseif appState.current_mode == "radio_client" then
                return app_manager.runRadioClient(appState)
            elseif appState.current_mode == "radio_host" then
                return app_manager.runRadioHost(appState)
            else
                logger.error("AppManager", "Unknown mode: " .. tostring(appState.current_mode))
                return "menu"
            end
        end)
        
        if success then
            if result == "exit" then
                appState.running = false
                logger.info("AppManager", "Application exit requested")
            elseif result then
                appState.current_mode = result
                logger.debug("AppManager", "Mode changed to: " .. result)
            end
        else
            -- Handle errors gracefully
            logger.error("AppManager", "Error in main loop: " .. tostring(result))
            appState.errorHandler.handleUIError(result, "Main application loop")
            
            -- Return to menu on error
            appState.current_mode = "menu"
            
            -- Show error message briefly
            term.setBackgroundColor(colors.red)
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1, 1)
            print("An error occurred. Returning to menu...")
            print("Error: " .. tostring(result))
            print("Press any key to continue...")
            os.pullEvent("key")
        end
    end
    
    logger.info("AppManager", "Main application loop ended")
end

function app_manager.runMenu(appState)
    -- Update screen dimensions
    appState.width, appState.height = term.getSize()
    
    while true do
        mainMenu.drawMenu(appState, appState.menuState)
        
        local action = mainMenu.handleInput(appState.menuState)
        
        if action == "youtube" then
            return "youtube"
        elseif action == "radio_client" then
            return "radio_client"
        elseif action == "radio_host" then
            return "radio_host"
        elseif action == "exit" then
            return "exit"
        elseif action == "redraw" then
            -- Continue loop to redraw
        end
    end
end

function app_manager.runYouTube(appState)
    -- Initialize YouTube state if not already done
    if not appState.youtubeState then
        appState.youtubeState = youtubePlayer.init(appState.system)
        appState.logger.info("AppManager", "YouTube player initialized")
    end
    
    -- Update screen dimensions
    appState.youtubeState.width, appState.youtubeState.height = term.getSize()
    
    -- Run YouTube player
    local result = youtubePlayer.run(appState.youtubeState)
    
    appState.logger.info("AppManager", "YouTube player exited")
    return result or "menu"
end

function app_manager.runRadioClient(appState)
    -- Initialize radio client state if not already done
    if not appState.radioClientState then
        local systemModules = {
            system = appState.system,
            httpClient = appState.httpClient,
            speakerManager = appState.speakerManager,
            errorHandler = appState.errorHandler,
            logger = appState.logger
        }
        appState.radioClientState = radioClient.init(systemModules)
        appState.logger.info("AppManager", "Radio client initialized")
    end
    
    -- Run radio client
    local result = radioClient.run(appState.radioClientState)
    
    appState.logger.info("AppManager", "Radio client exited")
    return result or "menu"
end

function app_manager.runRadioHost(appState)
    -- Initialize radio host state if not already done
    if not appState.radioHostState then
        local systemModules = {
            system = appState.system,
            httpClient = appState.httpClient,
            speakerManager = appState.speakerManager,
            errorHandler = appState.errorHandler,
            logger = appState.logger
        }
        appState.radioHostState = radioHost.init(systemModules)
        appState.logger.info("AppManager", "Radio host initialized")
    end
    
    -- Run radio host
    local result = radioHost.run(appState.radioHostState)
    
    appState.logger.info("AppManager", "Radio host exited")
    return result or "menu"
end

-- Cleanup and shutdown procedures
function app_manager.cleanup(appState)
    local logger = appState.logger
    local telemetry = appState.telemetry
    
    logger.info("AppManager", "Starting application cleanup")
    
    -- Cleanup feature states
    if appState.youtubeState then
        youtubePlayer.cleanup(appState.youtubeState)
        logger.debug("AppManager", "YouTube state cleaned up")
    end
    
    if appState.radioClientState then
        radioClient.cleanup(appState.radioClientState)
        logger.debug("AppManager", "Radio client state cleaned up")
    end
    
    if appState.radioHostState then
        radioHost.cleanup(appState.radioHostState)
        logger.debug("AppManager", "Radio host state cleaned up")
    end
    
    -- Final telemetry
    telemetry.logEvent("app_shutdown", {
        uptime = os.clock(),
        mode = appState.current_mode
    })
    
    -- Reset terminal
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    term.setCursorBlink(false)
    
    -- Final message
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
    
    logger.info("AppManager", "Application cleanup complete")
end

return app_manager 