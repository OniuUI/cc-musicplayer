-- UI rendering module for the radio player
local config = require("musicplayer.config")

local ui = {}

function ui.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()

    -- Draw header banner
    ui.drawHeader(state)
    
    -- Draw the tabs
    ui.drawTabs(state)

    if state.tab == 1 then
        ui.drawNowPlaying(state)
    elseif state.tab == 2 then
        ui.drawSearch(state)
    end
    
    -- Draw footer
    ui.drawFooter(state)
end

function ui.drawHeader(state)
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

function ui.drawTabs(state)
    -- Tab background
    term.setBackgroundColor(config.ui.colors.tab_bg)
    term.setCursorPos(1, 2)
    term.clearLine()
    
    for i = 1, #config.ui.tabs do
        if state.tab == i then
            term.setTextColor(config.ui.colors.background)
            term.setBackgroundColor(config.ui.colors.tab_active)
        else
            term.setTextColor(config.ui.colors.text_primary)
            term.setBackgroundColor(config.ui.colors.tab_inactive)
        end
        
        local x = (math.floor((state.width / #config.ui.tabs) * (i - 0.5))) - math.ceil(#config.ui.tabs[i] / 2) + 1
        term.setCursorPos(x, 2)
        term.write(config.ui.tabs[i])
    end
end

function ui.drawFooter(state)
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

function ui.drawNowPlaying(state)
    -- Song info section with enhanced styling
    if state.now_playing ~= nil then
        term.setBackgroundColor(config.ui.colors.background)
        
        -- Song title with accent color
        term.setTextColor(config.ui.colors.text_accent)
        term.setCursorPos(3, 4)
        term.write("♫ " .. state.now_playing.name)
        
        -- Artist with secondary color
        term.setTextColor(config.ui.colors.text_secondary)
        term.setCursorPos(3, 5)
        term.write("  " .. state.now_playing.artist)
    else
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_disabled)
        term.setCursorPos(3, 4)
        term.write("♪ Not playing")
    end

    -- Status messages with enhanced colors
    if state.is_loading then
        term.setTextColor(config.ui.colors.loading)
        term.setBackgroundColor(config.ui.colors.background)
        term.setCursorPos(3, 6)
        term.write("⟳ Loading...")
    elseif state.is_error then
        term.setTextColor(config.ui.colors.error)
        term.setBackgroundColor(config.ui.colors.background)
        term.setCursorPos(3, 6)
        term.write("✗ Network error")
    elseif state.playing then
        term.setTextColor(config.ui.colors.playing)
        term.setBackgroundColor(config.ui.colors.background)
        term.setCursorPos(3, 6)
        term.write("▶ Playing")
    end

    -- Control buttons with enhanced styling
    ui.drawControlButtons(state)
    
    -- Volume slider with new design
    ui.drawVolumeSlider(state)
    
    -- Queue with better formatting
    ui.drawQueue(state)
end

function ui.drawControlButtons(state)
    local buttonY = 8
    
    -- Play/Stop button with enhanced colors
    if state.playing then
        term.setTextColor(config.ui.colors.text_primary)
        term.setBackgroundColor(config.ui.colors.error)
        term.setCursorPos(3, buttonY)
        term.write(" STOP ")
    else
        if state.now_playing ~= nil or #state.queue > 0 then
            term.setTextColor(config.ui.colors.text_primary)
            term.setBackgroundColor(config.ui.colors.playing)
        else
            term.setTextColor(config.ui.colors.text_disabled)
            term.setBackgroundColor(config.ui.colors.button)
        end
        term.setCursorPos(3, buttonY)
        term.write(" PLAY ")
    end

    -- Skip button
    if state.now_playing ~= nil or #state.queue > 0 then
        term.setTextColor(config.ui.colors.text_primary)
        term.setBackgroundColor(config.ui.colors.button)
    else
        term.setTextColor(config.ui.colors.text_disabled)
        term.setBackgroundColor(config.ui.colors.button)
    end
    term.setCursorPos(11, buttonY)
    term.write(" SKIP ")

    -- Loop button with status indication
    if state.looping ~= 0 then
        term.setTextColor(config.ui.colors.background)
        term.setBackgroundColor(config.ui.colors.button_active)
    else
        term.setTextColor(config.ui.colors.text_primary)
        term.setBackgroundColor(config.ui.colors.button)
    end
    term.setCursorPos(19, buttonY)
    if state.looping == 0 then
        term.write(" LOOP OFF ")
    elseif state.looping == 1 then
        term.write(" LOOP ALL ")
    else
        term.write(" LOOP ONE ")
    end
end

function ui.drawVolumeSlider(state)
    local sliderY = 10
    local sliderX = 3
    local sliderWidth = 22
    
    -- Volume label
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_accent)
    term.setCursorPos(sliderX, sliderY)
    term.write("Volume:")
    
    -- Slider background
    term.setCursorPos(sliderX, sliderY + 1)
    paintutils.drawBox(sliderX, sliderY + 1, sliderX + sliderWidth, sliderY + 1, config.ui.colors.volume_bg)
    
    -- Slider fill
    local fillWidth = math.floor(sliderWidth * (state.volume / config.max_volume) + 0.5)
    if fillWidth > 0 then
        paintutils.drawBox(sliderX, sliderY + 1, sliderX + fillWidth - 1, sliderY + 1, config.ui.colors.volume_fill)
    end
    
    -- Volume percentage
    local percentage = math.floor(100 * (state.volume / config.max_volume) + 0.5)
    term.setCursorPos(sliderX + sliderWidth + 2, sliderY + 1)
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.volume_text)
    term.write(percentage .. "%")
end

function ui.drawQueue(state)
    if #state.queue > 0 then
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_accent)
        term.setCursorPos(3, 13)
        term.write("Up Next:")
        
        local maxDisplay = math.min(#state.queue, state.height - 16)
        for i = 1, maxDisplay do
            term.setTextColor(config.ui.colors.text_primary)
            term.setCursorPos(3, 14 + (i - 1) * 2)
            term.write((i) .. ". " .. state.queue[i].name)
            term.setTextColor(config.ui.colors.text_secondary)
            term.setCursorPos(6, 15 + (i - 1) * 2)
            term.write(state.queue[i].artist)
        end
        
        if #state.queue > maxDisplay then
            term.setTextColor(config.ui.colors.text_disabled)
            term.setCursorPos(3, 14 + maxDisplay * 2)
            term.write("... and " .. (#state.queue - maxDisplay) .. " more")
        end
    end
end

function ui.drawSearch(state)
    -- Search bar with enhanced styling
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_accent)
    term.setCursorPos(3, 4)
    term.write("Search YouTube:")
    
    paintutils.drawFilledBox(3, 5, state.width - 2, 6, config.ui.colors.search_box)
    term.setBackgroundColor(config.ui.colors.search_box)
    term.setCursorPos(4, 5)
    term.setTextColor(config.ui.colors.background)
    term.write(state.last_search or "Type here to search...")

    -- Search results with better formatting
    if state.search_results ~= nil then
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_accent)
        term.setCursorPos(3, 8)
        term.write("Results:")
        
        local maxResults = math.min(#state.search_results, (state.height - 12) / 2)
        for i = 1, maxResults do
            -- Result number and title
            term.setTextColor(config.ui.colors.text_primary)
            term.setCursorPos(3, 9 + (i - 1) * 2)
            term.write(i .. ". " .. state.search_results[i].name)
            
            -- Artist
            term.setTextColor(config.ui.colors.text_secondary)
            term.setCursorPos(6, 10 + (i - 1) * 2)
            term.write(state.search_results[i].artist)
        end
    else
        term.setCursorPos(3, 8)
        term.setBackgroundColor(config.ui.colors.background)
        if state.search_error then
            term.setTextColor(config.ui.colors.error)
            term.write("✗ Network error - check connection")
        elseif state.last_search_url ~= nil then
            term.setTextColor(config.ui.colors.loading)
            term.write("⟳ Searching...")
        else
            term.setTextColor(config.ui.colors.text_secondary)
            term.write("Tip: You can paste YouTube video or playlist links")
        end
    end

    -- Fullscreen song options
    if state.in_search_result then
        ui.drawSearchResultMenu(state)
    end
end

function ui.drawSearchResultMenu(state)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()
    
    -- Redraw header and footer for consistency
    ui.drawHeader(state)
    ui.drawFooter(state)
    
    -- Song info
    term.setCursorPos(3, 4)
    term.setTextColor(config.ui.colors.text_accent)
    term.write("♫ " .. state.search_results[state.clicked_result].name)
    term.setCursorPos(3, 5)
    term.setTextColor(config.ui.colors.text_secondary)
    term.write("  " .. state.search_results[state.clicked_result].artist)

    -- Action buttons with enhanced styling
    local options = {"Play now", "Play next", "Add to queue", "Cancel"}
    local positions = {8, 10, 12, 15}
    local colors = {config.ui.colors.playing, config.ui.colors.button_active, config.ui.colors.button, config.ui.colors.error}
    
    for i, option in ipairs(options) do
        term.setBackgroundColor(colors[i])
        term.setTextColor(config.ui.colors.text_primary)
        term.setCursorPos(3, positions[i])
        term.clearLine()
        term.write(" " .. option .. " ")
    end
end

return ui 