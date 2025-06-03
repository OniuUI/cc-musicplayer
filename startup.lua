-- Bognesferga Radio - Main Entry Point
-- A comprehensive music and radio system for ComputerCraft

local config = require("musicplayer.config")
local state = require("musicplayer.state")
local ui = require("musicplayer.ui")
local input = require("musicplayer.input")
local audio = require("musicplayer.audio")
local network = require("musicplayer.network")
local main = require("musicplayer.main")
local menu = require("musicplayer.menu")
local radio = require("musicplayer.radio")
local radio_ui = require("musicplayer.radio_ui")

-- Initialize the system
local function init()
    local width, height = term.getSize()
    return {
        width = width,
        height = height,
        mode = "menu", -- menu, youtube, radio_client, radio_host
        menuState = menu.init(),
        musicState = nil,
        radioState = nil
    }
end

-- Get station name input
local function getStationName(appState)
    radio_ui.drawStationNameInput(appState)
    
    local stationName = ""
    while true do
        local event, key = os.pullEvent()
        
        if event == "key" then
            if key == keys.enter and #stationName > 0 then
                return stationName
            elseif key == keys.escape then
                return nil
            elseif key == keys.backspace and #stationName > 0 then
                stationName = stationName:sub(1, -2)
                radio_ui.drawStationNameInput(appState)
                term.setCursorPos(4 + #stationName, 8)
                term.write(" ")
                term.setCursorPos(4 + #stationName, 8)
            end
        elseif event == "char" and #stationName < 30 then
            stationName = stationName .. key
            term.write(key)
        end
    end
end

-- Main menu loop
local function runMainMenu(appState)
    while appState.mode == "menu" do
        menu.drawMenu(appState, appState.menuState)
        
        local result = menu.handleInput(appState.menuState)
        
        if result == "redraw" then
            -- Continue loop to redraw
        elseif result == "YouTube Music Player" then
            appState.mode = "youtube"
            appState.musicState = state.init()
            return true
        elseif result == "Network Radio" then
            appState.mode = "radio_client"
            appState.radioState = radio.initClient()
            local success, message = radio.startClient(appState.radioState)
            if not success then
                -- Show error and return to menu
                term.clear()
                term.setCursorPos(1, 1)
                term.setTextColor(colors.red)
                print("Error: " .. message)
                print("Press any key to continue...")
                os.pullEvent("key")
                appState.mode = "menu"
            end
            return true
        elseif result == "Host Radio Station" then
            -- Get station name from user
            local stationName = getStationName(appState)
            if stationName then
                appState.mode = "radio_host"
                appState.radioState = radio.initHost(stationName)
                local success, message = radio.startHost(appState.radioState)
                if not success then
                    -- Show error and return to menu
                    term.clear()
                    term.setCursorPos(1, 1)
                    term.setTextColor(colors.red)
                    print("Error: " .. message)
                    print("Press any key to continue...")
                    os.pullEvent("key")
                    appState.mode = "menu"
                end
            else
                appState.mode = "menu"
            end
            return true
        elseif result == "Exit" then
            term.clear()
            term.setCursorPos(1, 1)
            term.setTextColor(colors.white)
            print("Thanks for using Bognesferga Radio!")
            return false
        end
    end
    return true
end

-- YouTube music player loop
local function runYouTubePlayer(appState)
    -- Initialize speakers
    appState.musicState.speakers = { peripheral.find("speaker") }
    if #appState.musicState.speakers == 0 then
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.red)
        print("No speakers found! Please attach a speaker.")
        print("Press any key to return to menu...")
        os.pullEvent("key")
        appState.mode = "menu"
        return
    end

    -- Run the original music player
    parallel.waitForAny(
        function() main.uiLoop(appState.musicState) end,
        function() audio.loop(appState.musicState) end,
        function() network.loop(appState.musicState) end,
        function()
            while appState.mode == "youtube" do
                local event, key = os.pullEvent("key")
                if key == keys.escape then
                    appState.mode = "menu"
                    break
                end
            end
        end
    )
end

-- Radio client loop
local function runRadioClient(appState)
    while appState.mode == "radio_client" do
        radio_ui.drawClientInterface(appState, appState.radioState)
        
        -- Handle network messages
        radio.handleClientMessages(appState.radioState)
        
        -- Handle input
        local event, key = os.pullEvent()
        
        if event == "key" then
            if key == keys.escape then
                radio.shutdown(appState.radioState)
                appState.mode = "menu"
                break
            elseif key == keys.s then
                radio.scanForStations(appState.radioState)
            elseif key == keys.up and #appState.radioState.station_list > 0 then
                appState.radioState.selected_station = appState.radioState.selected_station - 1
                if appState.radioState.selected_station < 1 then
                    appState.radioState.selected_station = #appState.radioState.station_list
                end
            elseif key == keys.down and #appState.radioState.station_list > 0 then
                appState.radioState.selected_station = appState.radioState.selected_station + 1
                if appState.radioState.selected_station > #appState.radioState.station_list then
                    appState.radioState.selected_station = 1
                end
            elseif key == keys.enter and #appState.radioState.station_list > 0 then
                local selectedStation = appState.radioState.station_list[appState.radioState.selected_station]
                radio.connectToStation(appState.radioState, selectedStation.id)
            elseif key == keys.d and appState.radioState.connected_station then
                radio.disconnectFromStation(appState.radioState)
            end
        end
        
        sleep(0.1) -- Small delay to prevent excessive CPU usage
    end
end

-- Radio host loop
local function runRadioHost(appState)
    while appState.mode == "radio_host" do
        radio_ui.drawHostInterface(appState, appState.radioState)
        
        -- Handle network messages
        radio.handleHostMessages(appState.radioState)
        
        -- Handle input
        local event, key = os.pullEvent()
        
        if event == "key" then
            if key == keys.escape then
                radio.shutdown(appState.radioState)
                appState.mode = "menu"
                break
            elseif key == keys.a then
                -- Add songs to playlist (integrate with YouTube search)
                addSongsToPlaylist(appState)
            elseif key == keys.space and #appState.radioState.playlist > 0 then
                if appState.radioState.is_playing then
                    radio.hostStopPlayback(appState.radioState)
                else
                    local currentSong = appState.radioState.playlist[appState.radioState.current_track]
                    radio.hostPlaySong(appState.radioState, currentSong)
                end
            elseif key == keys.n and #appState.radioState.playlist > 0 then
                radio.hostNextTrack(appState.radioState)
            end
        end
        
        sleep(0.1) -- Small delay to prevent excessive CPU usage
    end
end

-- Add songs to radio playlist using YouTube search
local function addSongsToPlaylist(appState)
    -- Create a temporary music state for searching
    local searchState = state.init()
    searchState.tab = 2 -- Search tab
    searchState.width = appState.width
    searchState.height = appState.height
    
    while true do
        ui.redrawScreen(searchState)
        
        local event, key, x, y = os.pullEvent()
        
        if event == "key" then
            if key == keys.escape then
                break
            end
        elseif event == "mouse_click" then
            local result = input.handleClick(searchState, x, y)
            if result == "back" then
                break
            elseif result == "search" then
                input.handleSearchInput(searchState)
            elseif type(result) == "table" and result.action == "add_to_radio" then
                -- Add selected song to radio playlist
                radio.addToPlaylist(appState.radioState, result.song)
                break
            end
        end
        
        sleep(0.05)
    end
end

-- Main application loop
local function main()
    local appState = init()
    
    while true do
        if appState.mode == "menu" then
            if not runMainMenu(appState) then
                break -- Exit requested
            end
        elseif appState.mode == "youtube" then
            runYouTubePlayer(appState)
        elseif appState.mode == "radio_client" then
            runRadioClient(appState)
        elseif appState.mode == "radio_host" then
            runRadioHost(appState)
        end
    end
end

-- Start the application
main() 