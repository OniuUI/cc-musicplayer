-- Radio UI module for network radio interfaces
local config = require("musicplayer.config")

local radio_ui = {}

function radio_ui.drawClientInterface(state, radioState)
    term.setCursorBlink(false)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()

    -- Draw header
    radio_ui.drawHeader(state)
    
    -- Connection status
    term.setBackgroundColor(config.ui.colors.background)
    term.setCursorPos(3, 4)
    
    if radioState.connection_status == "connected" then
        term.setTextColor(config.ui.colors.playing)
        term.write("📻 Connected to Radio Station")
    elseif radioState.connection_status == "connecting" then
        term.setTextColor(config.ui.colors.loading)
        term.write("⟳ Connecting...")
    elseif radioState.connection_status == "scanning" then
        term.setTextColor(config.ui.colors.loading)
        term.write("⟳ Scanning for stations...")
    else
        term.setTextColor(config.ui.colors.text_secondary)
        term.write("📻 Network Radio Client")
    end
    
    -- Current song info
    if radioState.current_song then
        term.setTextColor(config.ui.colors.text_accent)
        term.setCursorPos(3, 6)
        term.write("♫ " .. radioState.current_song.name)
        term.setTextColor(config.ui.colors.text_secondary)
        term.setCursorPos(3, 7)
        term.write("  " .. radioState.current_song.artist)
    end
    
    -- Station list
    if #radioState.station_list > 0 then
        term.setTextColor(config.ui.colors.text_accent)
        term.setCursorPos(3, 9)
        term.write("Available Stations:")
        
        local maxDisplay = math.min(#radioState.station_list, (state.height - 14) / 3)
        for i = 1, maxDisplay do
            local station = radioState.station_list[i]
            local y = 10 + (i - 1) * 3
            
            -- Highlight selected station
            if i == radioState.selected_station then
                term.setBackgroundColor(config.ui.colors.button_active)
                term.setTextColor(config.ui.colors.background)
            else
                term.setBackgroundColor(config.ui.colors.button)
                term.setTextColor(config.ui.colors.text_primary)
            end
            
            term.setCursorPos(3, y)
            term.clearLine()
            local buttonText = " " .. station.name .. " "
            local buttonWidth = math.max(#buttonText + 4, 30) -- Wider for easier clicking
            local paddedText = " " .. station.name .. string.rep(" ", buttonWidth - #buttonText - 1)
            term.write(paddedText)
            
            -- Store click area for this station
            radioState.station_list[i].click_area = {
                x1 = 3,
                y1 = y,
                x2 = 3 + buttonWidth - 1,
                y2 = y
            }
            
            -- Station info
            term.setBackgroundColor(config.ui.colors.background)
            term.setTextColor(config.ui.colors.text_secondary)
            term.setCursorPos(3, y + 1)
            local info = "Listeners: " .. station.listeners
            if station.current_song then
                info = info .. " | Playing: " .. station.current_song.name
            end
            term.write(info)
        end
    else
        term.setTextColor(config.ui.colors.text_disabled)
        term.setCursorPos(3, 9)
        term.write("No radio stations found")
        term.setCursorPos(3, 10)
        term.write("Click 'Scan for Stations' below")
    end
    
    -- Controls
    radio_ui.drawClientControls(state, radioState)
    
    -- Draw footer
    radio_ui.drawFooter(state)
end

function radio_ui.drawHostInterface(state, radioState)
    term.setCursorBlink(false)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()

    -- Draw header
    radio_ui.drawHeader(state)
    
    -- Station info
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_accent)
    term.setCursorPos(3, 4)
    term.write("📡 Hosting: " .. radioState.station_name)
    
    term.setTextColor(config.ui.colors.text_secondary)
    term.setCursorPos(3, 5)
    term.write("Listeners: " .. #radioState.clients)
    
    -- Current song
    if radioState.current_song then
        term.setTextColor(config.ui.colors.text_accent)
        term.setCursorPos(3, 7)
        term.write("♫ " .. radioState.current_song.name)
        term.setTextColor(config.ui.colors.text_secondary)
        term.setCursorPos(3, 8)
        term.write("  " .. radioState.current_song.artist)
        
        if radioState.is_playing then
            term.setTextColor(config.ui.colors.playing)
            term.setCursorPos(3, 9)
            term.write("▶ Broadcasting")
        end
    else
        term.setTextColor(config.ui.colors.text_disabled)
        term.setCursorPos(3, 7)
        term.write("♪ No song playing")
    end
    
    -- Playlist
    if #radioState.playlist > 0 then
        term.setTextColor(config.ui.colors.text_accent)
        term.setCursorPos(3, 11)
        term.write("Playlist (click to select):")
        
        local maxDisplay = math.min(#radioState.playlist, (state.height - 16) / 2)
        for i = 1, maxDisplay do
            local song = radioState.playlist[i]
            local y = 12 + (i - 1) * 2
            
            -- Highlight current track
            if i == radioState.current_track then
                term.setBackgroundColor(config.ui.colors.button_active)
                term.setTextColor(config.ui.colors.background)
            else
                term.setBackgroundColor(config.ui.colors.button)
                term.setTextColor(config.ui.colors.text_primary)
            end
            
            term.setCursorPos(3, y)
            term.clearLine()
            local trackText = (i) .. ". " .. song.name
            local buttonWidth = math.max(#trackText + 4, 35) -- Wider for easier clicking
            local paddedText = " " .. trackText .. string.rep(" ", buttonWidth - #trackText - 1)
            term.write(paddedText)
            
            -- Store click area for this track
            radioState.playlist[i].click_area = {
                x1 = 3,
                y1 = y,
                x2 = 3 + buttonWidth - 1,
                y2 = y
            }
            
            term.setBackgroundColor(config.ui.colors.background)
            term.setTextColor(config.ui.colors.text_secondary)
            term.setCursorPos(6, y + 1)
            term.write(song.artist)
        end
        
        if #radioState.playlist > maxDisplay then
            term.setTextColor(config.ui.colors.text_disabled)
            term.setCursorPos(3, 12 + maxDisplay * 2)
            term.write("... and " .. (#radioState.playlist - maxDisplay) .. " more")
        end
    else
        term.setTextColor(config.ui.colors.text_disabled)
        term.setCursorPos(3, 11)
        term.write("Playlist is empty")
        term.setCursorPos(3, 12)
        term.write("Click 'Add Songs' below to build your playlist")
    end
    
    -- Controls
    radio_ui.drawHostControls(state, radioState)
    
    -- Draw footer
    radio_ui.drawFooter(state)
end

function radio_ui.drawClientControls(state, radioState)
    local controlsY = state.height - 5
    
    -- Scan button
    term.setBackgroundColor(config.ui.colors.button)
    term.setTextColor(config.ui.colors.text_primary)
    term.setCursorPos(3, controlsY)
    local scanText = " Scan for Stations "
    term.write(scanText)
    radioState.scan_button = {
        x1 = 3,
        y1 = controlsY,
        x2 = 3 + #scanText - 1,
        y2 = controlsY
    }
    
    -- Connect button (only if stations available and not connected)
    if #radioState.station_list > 0 and not radioState.connected_station then
        term.setBackgroundColor(config.ui.colors.button)
        term.setTextColor(config.ui.colors.text_primary)
        term.setCursorPos(25, controlsY)
        local connectText = " Connect to Selected "
        term.write(connectText)
        radioState.connect_button = {
            x1 = 25,
            y1 = controlsY,
            x2 = 25 + #connectText - 1,
            y2 = controlsY
        }
    end
    
    -- Disconnect button (only if connected)
    if radioState.connected_station then
        term.setBackgroundColor(config.ui.colors.button)
        term.setTextColor(config.ui.colors.text_primary)
        term.setCursorPos(25, controlsY)
        local disconnectText = " Disconnect "
        term.write(disconnectText)
        radioState.disconnect_button = {
            x1 = 25,
            y1 = controlsY,
            x2 = 25 + #disconnectText - 1,
            y2 = controlsY
        }
    end
    
    -- Back button
    term.setBackgroundColor(config.ui.colors.button)
    term.setTextColor(config.ui.colors.text_primary)
    term.setCursorPos(3, controlsY + 2)
    local backText = " Back to Menu "
    term.write(backText)
    radioState.back_button = {
        x1 = 3,
        y1 = controlsY + 2,
        x2 = 3 + #backText - 1,
        y2 = controlsY + 2
    }
    
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_disabled)
    term.setCursorPos(3, controlsY + 4)
    term.write("Click buttons above or use keyboard shortcuts")
end

function radio_ui.drawHostControls(state, radioState)
    local controlsY = state.height - 6
    
    -- Add songs button
    term.setBackgroundColor(config.ui.colors.button)
    term.setTextColor(config.ui.colors.text_primary)
    term.setCursorPos(3, controlsY)
    local addText = " Add Songs "
    term.write(addText)
    radioState.add_button = {
        x1 = 3,
        y1 = controlsY,
        x2 = 3 + #addText - 1,
        y2 = controlsY
    }
    
    -- Play/Stop button (only if playlist has songs)
    if #radioState.playlist > 0 then
        term.setBackgroundColor(config.ui.colors.button)
        term.setTextColor(config.ui.colors.text_primary)
        term.setCursorPos(16, controlsY)
        
        local playStopText
        if radioState.is_playing then
            playStopText = " Stop Broadcast "
        else
            playStopText = " Start Broadcast "
        end
        term.write(playStopText)
        radioState.play_stop_button = {
            x1 = 16,
            y1 = controlsY,
            x2 = 16 + #playStopText - 1,
            y2 = controlsY
        }
        
        -- Next track button
        term.setBackgroundColor(config.ui.colors.button)
        term.setTextColor(config.ui.colors.text_primary)
        term.setCursorPos(35, controlsY)
        local nextText = " Next Track "
        term.write(nextText)
        radioState.next_button = {
            x1 = 35,
            y1 = controlsY,
            x2 = 35 + #nextText - 1,
            y2 = controlsY
        }
    end
    
    -- Back button
    term.setBackgroundColor(config.ui.colors.button)
    term.setTextColor(config.ui.colors.text_primary)
    term.setCursorPos(3, controlsY + 2)
    local backText = " Stop Station & Back to Menu "
    term.write(backText)
    radioState.back_button = {
        x1 = 3,
        y1 = controlsY + 2,
        x2 = 3 + #backText - 1,
        y2 = controlsY + 2
    }
    
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_disabled)
    term.setCursorPos(3, controlsY + 4)
    term.write("Click buttons above or use keyboard shortcuts")
end

function radio_ui.drawHeader(state)
    -- Header background
    term.setBackgroundColor(config.ui.colors.header_bg)
    term.setCursorPos(1, 1)
    term.clearLine()
    
    -- Calculate center position for the entire header including decorative elements
    local title = config.branding.title
    local fullHeader = "♪ " .. title .. " ♪"
    local headerX = math.floor((state.width - #fullHeader) / 2) + 1
    
    -- Ensure we don't go off the left edge
    if headerX < 1 then
        headerX = 1
    end
    
    -- Draw the complete header
    term.setCursorPos(headerX, 1)
    term.setTextColor(config.ui.colors.text_accent)
    term.write("♪ ")
    term.setTextColor(config.ui.colors.text_primary)
    term.write(title)
    term.setTextColor(config.ui.colors.text_accent)
    term.write(" ♪")
end

function radio_ui.drawFooter(state)
    -- Footer background
    term.setBackgroundColor(config.ui.colors.footer_bg)
    term.setCursorPos(1, state.height)
    term.clearLine()
    
    -- Rainbow "Developed by Forty" text
    local devText = config.branding.developer
    local footerX = math.floor((state.width - #devText) / 2) + 1
    term.setCursorPos(footerX, state.height)
    
    for i = 1, #devText do
        local colorIndex = ((i - 1) % #config.branding.rainbow_colors) + 1
        term.setTextColor(config.branding.rainbow_colors[colorIndex])
        term.write(devText:sub(i, i))
    end
end

function radio_ui.drawStationNameInput(state)
    term.setCursorBlink(false)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()

    -- Draw header
    radio_ui.drawHeader(state)
    
    -- Input prompt
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_accent)
    term.setCursorPos(3, 4)
    term.write("Create Radio Station")
    
    term.setTextColor(config.ui.colors.text_secondary)
    term.setCursorPos(3, 6)
    term.write("Enter a name for your radio station:")
    
    -- Input box
    paintutils.drawFilledBox(3, 8, state.width - 2, 9, config.ui.colors.search_box)
    term.setBackgroundColor(config.ui.colors.search_box)
    term.setCursorPos(4, 8)
    term.setTextColor(config.ui.colors.background)
    term.setCursorBlink(true)
    
    -- Instructions
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_disabled)
    term.setCursorPos(3, 11)
    term.write("Press ENTER to create station, ESC to cancel")
    
    -- Draw footer
    radio_ui.drawFooter(state)
end

return radio_ui 