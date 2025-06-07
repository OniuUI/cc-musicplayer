-- Radio UI Layout for Bognesferga Radio
-- Consolidated radio interface using reusable components

local components = require("musicplayer.ui.components")
local themes = require("musicplayer.ui.themes")

local radioUI = {}

-- Tab definitions for radio interface
local TABS = {" Stations ", " Now Playing "}

function radioUI.redrawScreen(state)
    components.clearScreen()

    -- Draw header banner
    components.drawHeader(state)
    
    -- Draw the tabs
    components.drawTabs(state, TABS)

    if state.tab == 1 then
        radioUI.drawStations(state)
    elseif state.tab == 2 then
        radioUI.drawNowPlaying(state)
    end
    
    -- Draw footer
    components.drawFooter(state)
end

function radioUI.drawStations(state)
    local theme = themes.getCurrent()
    
    -- Station list title
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.text_accent)
    term.setCursorPos(3, 4)
    term.write("Available Radio Stations:")
    
    -- Scanning status
    if state.scanning then
        components.drawStatusIndicator(3, 6, "scanning", "Scanning for stations...")
        components.drawLoadingSpinner(25, 6, state.spinner_frame or 1)
    elseif state.scan_error then
        components.drawStatusIndicator(3, 6, "error", "Failed to scan for stations")
    elseif not state.stations or #state.stations == 0 then
        term.setTextColor(theme.colors.text_disabled)
        term.setCursorPos(3, 6)
        term.write("No stations found. Click 'Refresh' to scan again.")
    end
    
    -- Station list
    if state.stations and #state.stations > 0 then
        radioUI.drawStationList(state)
    end
    
    -- Control buttons
    radioUI.drawStationControls(state)
    
    -- Instructions
    term.setTextColor(theme.colors.text_disabled)
    term.setCursorPos(3, state.height - 3)
    term.write("Click on a station to connect | ESC: Back to menu")
end

function radioUI.drawStationList(state)
    local theme = themes.getCurrent()
    local startY = 8
    local maxStations = math.min(8, #state.stations)
    
    for i = 1, maxStations do
        local station = state.stations[i]
        local y = startY + i - 1
        local isConnected = (state.connected_station == station.id)
        local isSelected = (state.selected_station == i)
        
        -- Station background
        if isConnected then
            term.setBackgroundColor(theme.colors.playing)
            term.setTextColor(theme.colors.background)
        elseif isSelected then
            term.setBackgroundColor(theme.colors.button_hover)
            term.setTextColor(theme.colors.text_primary)
        else
            term.setBackgroundColor(theme.colors.background)
            term.setTextColor(theme.colors.text_secondary)
        end
        
        term.setCursorPos(3, y)
        term.clearLine()
        
        -- Station status icon
        local statusIcon = "📻"
        if isConnected then
            statusIcon = "🔊"
        elseif station.listeners then
            statusIcon = "👥"
        end
        
        -- Station info
        local stationText = statusIcon .. " " .. station.name
        if station.listeners then
            stationText = stationText .. " (" .. station.listeners .. " listeners)"
        end
        
        term.write(stationText)
        
        -- Station description on next line if selected
        if isSelected and station.description then
            term.setBackgroundColor(theme.colors.background)
            term.setTextColor(theme.colors.text_disabled)
            term.setCursorPos(5, y + 1)
            term.write(station.description)
        end
    end
    
    if #state.stations > maxStations then
        term.setTextColor(theme.colors.text_disabled)
        term.setCursorPos(3, startY + maxStations)
        term.write("... and " .. (#state.stations - maxStations) .. " more stations")
    end
end

function radioUI.drawStationControls(state)
    local theme = themes.getCurrent()
    local buttonY = state.height - 5
    
    -- Refresh button
    components.drawButton(3, buttonY, "Refresh", false, not state.scanning)
    
    -- Connect/Disconnect button
    if state.connected_station then
        components.drawButton(15, buttonY, "Disconnect", true, true)
    else
        local canConnect = state.selected_station and state.stations and state.stations[state.selected_station]
        components.drawButton(15, buttonY, "Connect", false, canConnect)
    end
    
    -- Back to Menu button
    components.drawButton(30, buttonY, "Back to Menu", false, true)
end

function radioUI.drawNowPlaying(state)
    local theme = themes.getCurrent()
    
    if state.connected_station and state.current_station then
        -- Station info
        term.setBackgroundColor(theme.colors.background)
        term.setTextColor(theme.colors.text_accent)
        term.setCursorPos(3, 4)
        term.write("📻 Connected to: " .. state.current_station.name)
        
        -- Connection status
        components.drawStatusIndicator(3, 6, "connected", "Connected and streaming")
        
        -- Current song info if available
        if state.now_playing then
            components.drawSongInfo(state, 3, 8)
        else
            term.setTextColor(theme.colors.text_secondary)
            term.setCursorPos(3, 8)
            term.write("♪ Live radio stream")
        end
        
        -- Volume controls
        components.drawVolumeSlider(state)
        
        -- Station stats
        if state.current_station.listeners then
            term.setTextColor(theme.colors.text_secondary)
            term.setCursorPos(3, 16)
            term.write("👥 " .. state.current_station.listeners .. " listeners")
        end
        
    else
        -- Not connected state
        term.setBackgroundColor(theme.colors.background)
        term.setTextColor(theme.colors.text_disabled)
        term.setCursorPos(3, 4)
        term.write("📻 Not connected to any station")
        
        term.setCursorPos(3, 6)
        term.write("Go to the Stations tab to connect to a radio station")
    end
    
    -- Control buttons
    radioUI.drawPlayingControls(state)
end

function radioUI.drawPlayingControls(state)
    local theme = themes.getCurrent()
    local buttonY = state.height - 5
    
    if state.connected_station then
        -- Disconnect button
        components.drawButton(3, buttonY, "Disconnect", true, true)
        
        -- Volume controls (if not already shown in slider)
        components.drawButton(18, buttonY, "Vol -", false, true)
        components.drawButton(26, buttonY, "Vol +", false, true)
    end
    
    -- Back to stations
    components.drawButton(35, buttonY, "Back to Stations", false, true)
end

-- Handle station selection input
function radioUI.handleStationInput(state)
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "key" then
            local key = param1
            if key == keys.up and state.stations and #state.stations > 0 then
                state.selected_station = state.selected_station - 1
                if state.selected_station < 1 then
                    state.selected_station = #state.stations
                end
                return "redraw"
            elseif key == keys.down and state.stations and #state.stations > 0 then
                state.selected_station = state.selected_station + 1
                if state.selected_station > #state.stations then
                    state.selected_station = 1
                end
                return "redraw"
            elseif key == keys.enter and state.selected_station and state.stations and state.stations[state.selected_station] then
                return "connect_station"
            elseif key == keys.r then
                return "refresh_stations"
            elseif key == keys.escape then
                return "back_to_menu"
            end
        elseif event == "mouse_click" or event == "monitor_touch" then
            local button, x, y
            if event == "mouse_click" then
                button, x, y = param1, param2, param3
            else -- monitor_touch
                -- monitor_touch returns: event, side, x, y (no button parameter)
                -- param1 = side, param2 = x, param3 = y
                button, x, y = 1, param2, param3  -- Treat monitor touch as left click
            end
            
            -- Check station clicks
            if state.stations and #state.stations > 0 then
                local startY = 8
                local maxStations = math.min(8, #state.stations)
                
                for i = 1, maxStations do
                    local stationY = startY + i - 1
                    if y == stationY and x >= 3 then
                        state.selected_station = i
                        return "connect_station"
                    end
                end
            end
            
            -- Check button clicks (simplified - would need proper click areas)
            if y == state.height - 5 then
                if x >= 3 and x <= 12 then
                    return "refresh_stations"
                elseif x >= 15 and x <= 28 then
                    if state.connected_station then
                        return "disconnect_station"
                    else
                        return "connect_station"
                    end
                elseif x >= 30 then
                    return "back_to_menu"
                end
            end
        end
    end
end

return radioUI 