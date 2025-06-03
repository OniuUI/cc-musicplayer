-- YouTube Music Player Feature
-- Consolidated YouTube player functionality with improved organization

local youtubeUI = require("musicplayer.ui.layouts.youtube")
local httpClient = require("musicplayer.network.http_client")
local speakerManager = require("musicplayer.audio.speaker_manager")
local errorHandler = require("musicplayer.middleware.error_handler")

local youtubePlayer = {}

function youtubePlayer.init(systemState)
    return {
        -- UI state
        tab = 1,
        width = 0,
        height = 0,
        
        -- Playback state
        playing = false,
        volume = 1.0,
        looping = 0, -- 0 = off, 1 = all, 2 = one
        
        -- Current content
        now_playing = nil,
        queue = {},
        
        -- Search state
        search_results = nil,
        search_error = false,
        last_search = nil,
        selected_result = 1,
        
        -- Loading states
        is_loading = false,
        is_error = false,
        waiting_for_input = false,
        
        -- System references
        system = systemState,
        httpClient = systemState.httpClient,
        speakerManager = systemState.speakerManager,
        errorHandler = systemState.errorHandler,
        logger = systemState.logger
    }
end

function youtubePlayer.run(state)
    -- Initialize screen dimensions
    state.width, state.height = term.getSize()
    
    -- Main loop
    while true do
        youtubeUI.redrawScreen(state)
        
        local action = youtubePlayer.handleInput(state)
        
        if action == "exit" then
            break
        elseif action == "back_to_menu" then
            break
        end
    end
    
    -- Cleanup
    youtubePlayer.cleanup(state)
    return "menu"
end

function youtubePlayer.handleInput(state)
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "key" then
            local key = param1
            
            -- Global keys
            if key == keys.escape then
                return "back_to_menu"
            elseif key == keys.tab then
                state.tab = (state.tab % 2) + 1
                return "redraw"
            end
            
            -- Tab-specific keys
            if state.tab == 1 then -- Now Playing
                return youtubePlayer.handlePlayingKeys(state, key)
            elseif state.tab == 2 then -- Search
                return youtubePlayer.handleSearchKeys(state, key)
            end
            
        elseif event == "mouse_click" or event == "monitor_touch" then
            local button, x, y
            if event == "mouse_click" then
                button, x, y = param1, param2, param3
            else
                button, x, y = 1, param2, param3
            end
            
            return youtubePlayer.handleClick(state, x, y)
            
        elseif event == "redraw_screen" then
            return "redraw"
        end
    end
end

function youtubePlayer.handlePlayingKeys(state, key)
    if key == keys.space then
        return youtubePlayer.togglePlayback(state)
    elseif key == keys.s then
        return youtubePlayer.skipSong(state)
    elseif key == keys.l then
        return youtubePlayer.toggleLoop(state)
    elseif key == keys.minus or key == keys.numPadSubtract then
        return youtubePlayer.decreaseVolume(state)
    elseif key == keys.equals or key == keys.numPadAdd then
        return youtubePlayer.increaseVolume(state)
    end
    return nil
end

function youtubePlayer.handleSearchKeys(state, key)
    if key == keys.enter then
        state.waiting_for_input = true
        youtubeUI.handleSearchInput(state, youtubePlayer)
        return "redraw"
    elseif key == keys.up and state.search_results then
        state.selected_result = math.max(1, state.selected_result - 1)
        return "redraw"
    elseif key == keys.down and state.search_results then
        state.selected_result = math.min(#state.search_results, state.selected_result + 1)
        return "redraw"
    elseif key == keys.a and state.search_results and state.search_results[state.selected_result] then
        return youtubePlayer.addToQueue(state, state.search_results[state.selected_result])
    end
    return nil
end

function youtubePlayer.handleClick(state, x, y)
    -- Tab clicks
    if y == 2 then
        local tabWidth = math.floor(state.width / 2)
        if x <= tabWidth then
            state.tab = 1
        else
            state.tab = 2
        end
        return "redraw"
    end
    
    -- Tab-specific clicks
    if state.tab == 1 then
        return youtubePlayer.handlePlayingClick(state, x, y)
    elseif state.tab == 2 then
        return youtubePlayer.handleSearchClick(state, x, y)
    end
    
    return nil
end

function youtubePlayer.handlePlayingClick(state, x, y)
    -- Control buttons (row 8)
    if y == 8 then
        if x >= 3 and x <= 8 then -- PLAY/STOP
            return youtubePlayer.togglePlayback(state)
        elseif x >= 11 and x <= 16 then -- SKIP
            return youtubePlayer.skipSong(state)
        elseif x >= 19 and x <= 29 then -- LOOP
            return youtubePlayer.toggleLoop(state)
        elseif x >= 31 and x <= 44 then -- BACK TO MENU
            return "back_to_menu"
        end
    end
    
    -- Volume controls
    if y == 12 then
        if x >= 3 and x <= 5 then -- [-]
            return youtubePlayer.decreaseVolume(state)
        elseif x >= 7 and x <= 9 then -- [+]
            return youtubePlayer.increaseVolume(state)
        end
    end
    
    return nil
end

function youtubePlayer.handleSearchClick(state, x, y)
    -- Search button
    if y == 7 and x >= 3 and x <= 10 then
        state.waiting_for_input = true
        youtubePlayer.performSearch(state, "")
        return "redraw"
    end
    
    -- Search results
    if state.search_results and y >= 11 and y <= 18 then
        local resultIndex = y - 10
        if resultIndex <= #state.search_results then
            state.selected_result = resultIndex
            return youtubePlayer.addToQueue(state, state.search_results[resultIndex])
        end
    end
    
    return nil
end

-- Playback control functions
function youtubePlayer.togglePlayback(state)
    local success, error = errorHandler.safeExecute(function()
        if state.playing then
            speakerManager.stopAll()
            state.playing = false
            state.logger.info("YouTube", "Playback stopped")
        else
            if state.now_playing then
                youtubePlayer.playCurrentSong(state)
            elseif #state.queue > 0 then
                youtubePlayer.playNextInQueue(state)
            end
        end
    end, "YouTube playback toggle")
    
    if not success then
        state.is_error = true
        state.logger.error("YouTube", "Playback toggle failed: " .. tostring(error))
    end
    
    return "redraw"
end

function youtubePlayer.skipSong(state)
    local success, error = errorHandler.safeExecute(function()
        speakerManager.stopAll()
        state.playing = false
        
        if #state.queue > 0 then
            youtubePlayer.playNextInQueue(state)
        else
            state.now_playing = nil
            state.logger.info("YouTube", "Queue finished")
        end
    end, "YouTube skip song")
    
    if not success then
        state.is_error = true
        state.logger.error("YouTube", "Skip failed: " .. tostring(error))
    end
    
    return "redraw"
end

function youtubePlayer.toggleLoop(state)
    state.looping = (state.looping + 1) % 3
    local loopModes = {"OFF", "ALL", "ONE"}
    state.logger.info("YouTube", "Loop mode: " .. loopModes[state.looping + 1])
    return "redraw"
end

function youtubePlayer.increaseVolume(state)
    state.volume = math.min(3.0, state.volume + 0.1)
    speakerManager.setVolume(state.volume)
    state.logger.debug("YouTube", "Volume increased to " .. state.volume)
    return "redraw"
end

function youtubePlayer.decreaseVolume(state)
    state.volume = math.max(0.0, state.volume - 0.1)
    speakerManager.setVolume(state.volume)
    state.logger.debug("YouTube", "Volume decreased to " .. state.volume)
    return "redraw"
end

-- Search and queue functions
function youtubePlayer.performSearch(state, query)
    if not query or #query == 0 then
        return
    end
    
    state.is_loading = true
    state.search_error = false
    state.last_search = query
    
    local success, results = errorHandler.safeExecute(function()
        return httpClient.searchMusic(query)
    end, "YouTube search")
    
    state.is_loading = false
    
    if success and results then
        state.search_results = results
        state.selected_result = 1
        state.logger.info("YouTube", "Search completed: " .. #results .. " results")
    else
        state.search_error = true
        state.search_results = nil
        state.logger.error("YouTube", "Search failed: " .. tostring(results))
    end
end

function youtubePlayer.addToQueue(state, song)
    local success, error = errorHandler.safeExecute(function()
        table.insert(state.queue, {
            name = song.name,
            artist = song.artist,
            url = song.url,
            duration = song.duration
        })
        
        state.logger.info("YouTube", "Added to queue: " .. song.name)
        
        -- Auto-play if nothing is currently playing
        if not state.playing and not state.now_playing then
            youtubePlayer.playNextInQueue(state)
        end
    end, "YouTube add to queue")
    
    if not success then
        state.logger.error("YouTube", "Failed to add to queue: " .. tostring(error))
    end
    
    return "redraw"
end

function youtubePlayer.playCurrentSong(state)
    if not state.now_playing then
        return
    end
    
    local success, error = errorHandler.safeExecute(function()
        local audioUrl = httpClient.getAudioStream(state.now_playing.url)
        if audioUrl then
            speakerManager.playAudio(audioUrl, state.volume)
            state.playing = true
            state.logger.info("YouTube", "Playing: " .. state.now_playing.name)
        else
            error("Failed to get audio stream")
        end
    end, "YouTube play current song")
    
    if not success then
        state.is_error = true
        state.logger.error("YouTube", "Failed to play song: " .. tostring(error))
    end
end

function youtubePlayer.playNextInQueue(state)
    if #state.queue == 0 then
        return
    end
    
    local success, error = errorHandler.safeExecute(function()
        -- Move next song from queue to now_playing
        state.now_playing = table.remove(state.queue, 1)
        
        -- Play the song
        youtubePlayer.playCurrentSong(state)
    end, "YouTube play next in queue")
    
    if not success then
        state.is_error = true
        state.logger.error("YouTube", "Failed to play next song: " .. tostring(error))
    end
end

function youtubePlayer.cleanup(state)
    local success, error = errorHandler.safeExecute(function()
        speakerManager.stopAll()
        state.playing = false
        state.logger.info("YouTube", "YouTube player cleaned up")
    end, "YouTube cleanup")
    
    if not success then
        state.logger.error("YouTube", "Cleanup failed: " .. tostring(error))
    end
end

return youtubePlayer 