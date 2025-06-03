-- UI Components for Bognesferga Radio
-- Reusable UI elements and rendering functions

local config = require("musicplayer.config")
local common = require("musicplayer.utils.common")

local components = {}

-- Header component
function components.drawHeader(state)
    -- Header background
    term.setBackgroundColor(config.ui.colors.header_bg)
    term.setCursorPos(1, 1)
    term.clearLine()
    
    -- Calculate center position for the entire header including decorative elements
    local title = config.branding.title
    local fullHeader = "♪ " .. title .. " ♪"
    local headerX = common.centerText(fullHeader, state.width)
    
    -- Draw the complete header
    term.setCursorPos(headerX, 1)
    term.setTextColor(config.ui.colors.text_accent)
    term.write("♪ ")
    term.setTextColor(config.ui.colors.text_primary)
    term.write(title)
    term.setTextColor(config.ui.colors.text_accent)
    term.write(" ♪")
end

-- Tab component
function components.drawTabs(state)
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

-- Footer component
function components.drawFooter(state)
    -- Footer background
    term.setBackgroundColor(config.ui.colors.footer_bg)
    term.setCursorPos(1, state.height)
    term.clearLine()
    
    -- Rainbow "Developed by Forty" text
    local devText = config.branding.developer
    local footerX = common.centerText(devText, state.width)
    term.setCursorPos(footerX, state.height)
    
    for i = 1, #devText do
        local colorIndex = ((i - 1) % #config.branding.rainbow_colors) + 1
        term.setTextColor(config.branding.rainbow_colors[colorIndex])
        term.write(devText:sub(i, i))
    end
end

-- Button component
function components.drawButton(x, y, text, isActive, isEnabled)
    isEnabled = isEnabled ~= false -- Default to true
    
    local bgColor, textColor
    
    if not isEnabled then
        bgColor = config.ui.colors.button
        textColor = config.ui.colors.text_disabled
    elseif isActive then
        bgColor = config.ui.colors.button_active
        textColor = config.ui.colors.background
    else
        bgColor = config.ui.colors.button
        textColor = config.ui.colors.text_primary
    end
    
    term.setBackgroundColor(bgColor)
    term.setTextColor(textColor)
    term.setCursorPos(x, y)
    term.write(" " .. text .. " ")
    
    return #text + 2 -- Return button width
end

-- Progress bar component
function components.drawProgressBar(x, y, width, progress, color)
    progress = common.clamp(progress, 0, 1)
    color = color or config.ui.colors.volume_fill
    
    local fillWidth = math.floor(width * progress)
    
    term.setCursorPos(x, y)
    term.setBackgroundColor(color)
    term.write(string.rep(" ", fillWidth))
    
    term.setBackgroundColor(config.ui.colors.volume_bg)
    term.write(string.rep(" ", width - fillWidth))
end

-- Volume slider component
function components.drawVolumeSlider(state)
    local sliderY = 10
    local sliderWidth = 20
    local sliderX = 3
    
    -- Volume label
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_primary)
    term.setCursorPos(sliderX, sliderY)
    term.write("Volume: ")
    
    -- Volume percentage
    local volumePercent = math.floor((state.volume / config.max_volume) * 100)
    term.setTextColor(config.ui.colors.volume_text)
    term.write(volumePercent .. "%")
    
    -- Volume slider
    term.setCursorPos(sliderX, sliderY + 1)
    components.drawProgressBar(sliderX, sliderY + 1, sliderWidth, state.volume / config.max_volume, config.ui.colors.volume_fill)
    
    -- Volume controls
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_secondary)
    term.setCursorPos(sliderX, sliderY + 2)
    term.write("[-] [+] Volume")
end

-- Status indicator component
function components.drawStatusIndicator(x, y, status, text)
    local color
    local icon
    
    if status == "playing" then
        color = config.ui.colors.playing
        icon = "▶"
    elseif status == "loading" then
        color = config.ui.colors.loading
        icon = "⟳"
    elseif status == "error" then
        color = config.ui.colors.error
        icon = "✗"
    elseif status == "stopped" then
        color = config.ui.colors.text_disabled
        icon = "⏹"
    else
        color = config.ui.colors.text_secondary
        icon = "•"
    end
    
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(color)
    term.setCursorPos(x, y)
    term.write(icon .. " " .. text)
end

-- Song info component
function components.drawSongInfo(state, x, y)
    if state.now_playing then
        -- Song title with accent color
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_accent)
        term.setCursorPos(x, y)
        term.write("♫ " .. common.truncateString(state.now_playing.name, state.width - x - 2))
        
        -- Artist with secondary color
        term.setTextColor(config.ui.colors.text_secondary)
        term.setCursorPos(x, y + 1)
        term.write("  " .. common.truncateString(state.now_playing.artist, state.width - x - 2))
    else
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_disabled)
        term.setCursorPos(x, y)
        term.write("♪ Not playing")
    end
end

-- Queue component
function components.drawQueue(state, x, y, maxItems)
    maxItems = maxItems or 5
    
    if #state.queue == 0 then
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_disabled)
        term.setCursorPos(x, y)
        term.write("Queue is empty")
        return
    end
    
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_primary)
    term.setCursorPos(x, y)
    term.write("Queue (" .. #state.queue .. " songs):")
    
    local displayCount = math.min(maxItems, #state.queue)
    for i = 1, displayCount do
        local song = state.queue[i]
        term.setTextColor(config.ui.colors.text_secondary)
        term.setCursorPos(x, y + i)
        
        local queueText = i .. ". " .. common.truncateString(song.name, state.width - x - 4)
        term.write(queueText)
    end
    
    if #state.queue > maxItems then
        term.setTextColor(config.ui.colors.text_disabled)
        term.setCursorPos(x, y + maxItems + 1)
        term.write("... and " .. (#state.queue - maxItems) .. " more")
    end
end

-- Search results component
function components.drawSearchResults(state, x, y, maxItems)
    maxItems = maxItems or 8
    
    if not state.search_results or #state.search_results == 0 then
        if state.search_error then
            term.setBackgroundColor(config.ui.colors.background)
            term.setTextColor(config.ui.colors.error)
            term.setCursorPos(x, y)
            term.write("Search error - please try again")
        elseif state.last_search then
            term.setBackgroundColor(config.ui.colors.background)
            term.setTextColor(config.ui.colors.text_disabled)
            term.setCursorPos(x, y)
            term.write("No results found for: " .. state.last_search)
        end
        return
    end
    
    local displayCount = math.min(maxItems, #state.search_results)
    for i = 1, displayCount do
        local result = state.search_results[i]
        local isSelected = (state.selected_result == i)
        
        if isSelected then
            term.setBackgroundColor(config.ui.colors.button_hover)
            term.setTextColor(config.ui.colors.text_primary)
        else
            term.setBackgroundColor(config.ui.colors.background)
            term.setTextColor(config.ui.colors.text_secondary)
        end
        
        term.setCursorPos(x, y + i - 1)
        term.clearLine()
        
        local resultText = i .. ". " .. common.truncateString(result.name .. " - " .. result.artist, state.width - x - 4)
        term.write(resultText)
    end
end

-- Loading spinner component
function components.drawLoadingSpinner(x, y, frame)
    local spinners = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
    frame = (frame % #spinners) + 1
    
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.loading)
    term.setCursorPos(x, y)
    term.write(spinners[frame])
end

-- Text input component
function components.drawTextInput(x, y, width, text, placeholder, isFocused)
    placeholder = placeholder or ""
    text = text or ""
    
    local bgColor = isFocused and config.ui.colors.search_box or config.ui.colors.background
    local textColor = (#text > 0) and config.ui.colors.text_primary or config.ui.colors.text_disabled
    
    term.setBackgroundColor(bgColor)
    term.setTextColor(textColor)
    term.setCursorPos(x, y)
    
    local displayText = (#text > 0) and text or placeholder
    displayText = common.truncateString(displayText, width)
    displayText = common.padString(displayText, width, " ", "left")
    
    term.write(displayText)
    
    if isFocused then
        term.setCursorBlink(true)
        term.setCursorPos(x + math.min(#text, width - 1), y)
    end
end

-- Clear screen with background color
function components.clearScreen()
    term.setCursorBlink(false)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()
end

return components 