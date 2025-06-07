-- UI Components for Bognesferga Radio
-- Reusable UI elements and rendering functions

local themes = require("musicplayer/ui/themes")
local common = require("musicplayer/utils/common")

local components = {}

-- Get current theme
local function getTheme()
    return themes.getCurrent()
end

-- Header component (consolidated from ui.lua, menu.lua, radio_ui.lua)
function components.drawHeader(state)
    local theme = getTheme()
    
    -- Header background
    term.setBackgroundColor(theme.colors.header_bg)
    term.setCursorPos(1, 1)
    term.clearLine()
    
    -- Calculate center position for the entire header including decorative elements
    local title = theme.branding.title
    local fullHeader = "♪ " .. title .. " ♪"
    local headerX = common.centerText(fullHeader, state.width)
    
    -- Draw the complete header
    term.setCursorPos(headerX, 1)
    term.setTextColor(theme.colors.text_accent)
    term.write("♪ ")
    term.setTextColor(theme.colors.text_primary)
    term.write(title)
    term.setTextColor(theme.colors.text_accent)
    term.write(" ♪")
end

-- Footer component (consolidated from ui.lua, menu.lua, radio_ui.lua)
function components.drawFooter(state)
    local theme = getTheme()
    
    -- Footer background
    term.setBackgroundColor(theme.colors.footer_bg)
    term.setCursorPos(1, state.height)
    term.clearLine()
    
    -- Rainbow "Developed by Forty" text
    local devText = theme.branding.developer
    local footerX = common.centerText(devText, state.width)
    term.setCursorPos(footerX, state.height)
    
    for i = 1, #devText do
        local colorIndex = ((i - 1) % #theme.branding.rainbow_colors) + 1
        term.setTextColor(theme.branding.rainbow_colors[colorIndex])
        term.write(devText:sub(i, i))
    end
end

-- Tab component
function components.drawTabs(state, tabs)
    local theme = getTheme()
    
    -- Tab background
    term.setBackgroundColor(theme.colors.tab_bg)
    term.setCursorPos(1, 2)
    term.clearLine()
    
    for i = 1, #tabs do
        if state.tab == i then
            term.setTextColor(theme.colors.background)
            term.setBackgroundColor(theme.colors.tab_active)
        else
            term.setTextColor(theme.colors.text_primary)
            term.setBackgroundColor(theme.colors.tab_inactive)
        end
        
        local x = (math.floor((state.width / #tabs) * (i - 0.5))) - math.ceil(#tabs[i] / 2) + 1
        term.setCursorPos(x, 2)
        term.write(tabs[i])
    end
end

-- Button component with click area tracking
function components.drawButton(x, y, text, isActive, isEnabled, clickAreas, buttonId)
    local theme = getTheme()
    isEnabled = isEnabled ~= false -- Default to true
    
    local bgColor, textColor
    
    if not isEnabled then
        bgColor = theme.colors.button
        textColor = theme.colors.text_disabled
    elseif isActive then
        bgColor = theme.colors.button_active
        textColor = theme.colors.background
    else
        bgColor = theme.colors.button
        textColor = theme.colors.text_primary
    end
    
    term.setBackgroundColor(bgColor)
    term.setTextColor(textColor)
    term.setCursorPos(x, y)
    
    local buttonText = " " .. text .. " "
    local buttonWidth = math.max(#buttonText, theme.layout.min_button_width)
    local paddedText = common.padString(buttonText, buttonWidth, " ", "center")
    
    term.write(paddedText)
    
    -- Store click area if clickAreas table provided
    if clickAreas and buttonId then
        clickAreas[buttonId] = {
            x1 = x,
            y1 = y,
            x2 = x + buttonWidth - 1,
            y2 = y,
            action = buttonId
        }
    end
    
    return buttonWidth -- Return button width
end

-- Wide button component for menu items
function components.drawWideButton(x, y, text, description, isSelected, clickAreas, buttonId, minWidth)
    local theme = getTheme()
    minWidth = minWidth or 25
    
    local bgColor, textColor
    if isSelected then
        bgColor = theme.colors.button_active
        textColor = theme.colors.background
    else
        bgColor = theme.colors.button
        textColor = theme.colors.text_primary
    end
    
    -- Draw button
    term.setBackgroundColor(bgColor)
    term.setTextColor(textColor)
    term.setCursorPos(x, y)
    term.clearLine()
    
    local buttonText = " " .. text .. " "
    local buttonWidth = math.max(#buttonText + 4, minWidth)
    local paddedText = " " .. text .. string.rep(" ", buttonWidth - #buttonText - 1)
    term.write(paddedText)
    
    -- Store click area
    if clickAreas and buttonId then
        clickAreas[buttonId] = {
            x1 = x,
            y1 = y,
            x2 = x + buttonWidth - 1,
            y2 = y,
            action = buttonId
        }
    end
    
    -- Draw description
    if description then
        term.setBackgroundColor(theme.colors.background)
        term.setTextColor(theme.colors.text_secondary)
        term.setCursorPos(x, y + 1)
        term.write(description)
    end
    
    return buttonWidth
end

-- Progress bar component
function components.drawProgressBar(x, y, width, progress, color)
    local theme = getTheme()
    progress = common.clamp(progress, 0, 1)
    color = color or theme.colors.volume_fill
    
    local fillWidth = math.floor(width * progress)
    
    term.setCursorPos(x, y)
    term.setBackgroundColor(color)
    term.write(string.rep(" ", fillWidth))
    
    term.setBackgroundColor(theme.colors.volume_bg)
    term.write(string.rep(" ", width - fillWidth))
end

-- Volume slider component
function components.drawVolumeSlider(state)
    local theme = getTheme()
    local sliderY = 10
    local sliderWidth = 20
    local sliderX = 3
    
    -- Volume label
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.text_primary)
    term.setCursorPos(sliderX, sliderY)
    term.write("Volume: ")
    
    -- Volume percentage (assuming max volume from config)
    local maxVolume = 3.0 -- From config
    local volumePercent = math.floor((state.volume / maxVolume) * 100)
    term.setTextColor(theme.colors.volume_text)
    term.write(volumePercent .. "%")
    
    -- Volume slider
    term.setCursorPos(sliderX, sliderY + 1)
    components.drawProgressBar(sliderX, sliderY + 1, sliderWidth, state.volume / maxVolume, theme.colors.volume_fill)
    
    -- Volume controls
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.text_secondary)
    term.setCursorPos(sliderX, sliderY + 2)
    term.write("[-] [+] Volume")
end

-- Status indicator component
function components.drawStatusIndicator(x, y, status, text)
    local theme = getTheme()
    local color, icon
    
    if status == "playing" then
        color = theme.colors.playing
        icon = "▶"
    elseif status == "loading" then
        color = theme.colors.loading
        icon = "⟳"
    elseif status == "error" then
        color = theme.colors.error
        icon = "✗"
    elseif status == "stopped" then
        color = theme.colors.text_disabled
        icon = "⏹"
    elseif status == "connected" then
        color = theme.colors.playing
        icon = "📻"
    elseif status == "connecting" then
        color = theme.colors.loading
        icon = "⟳"
    elseif status == "scanning" then
        color = theme.colors.loading
        icon = "⟳"
    else
        color = theme.colors.text_secondary
        icon = "•"
    end
    
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(color)
    term.setCursorPos(x, y)
    term.write(icon .. " " .. text)
end

-- Song info component
function components.drawSongInfo(state, x, y)
    local theme = getTheme()
    
    if state.now_playing then
        -- Song title with accent color
        term.setBackgroundColor(theme.colors.background)
        term.setTextColor(theme.colors.text_accent)
        term.setCursorPos(x, y)
        term.write("♫ " .. common.truncateString(state.now_playing.name, state.width - x - 2))
        
        -- Artist with secondary color
        term.setTextColor(theme.colors.text_secondary)
        term.setCursorPos(x, y + 1)
        term.write("  " .. common.truncateString(state.now_playing.artist, state.width - x - 2))
    else
        term.setBackgroundColor(theme.colors.background)
        term.setTextColor(theme.colors.text_disabled)
        term.setCursorPos(x, y)
        term.write("♪ Not playing")
    end
end

-- Queue component
function components.drawQueue(state, x, y, maxItems)
    local theme = getTheme()
    maxItems = maxItems or 5
    
    if #state.queue == 0 then
        term.setBackgroundColor(theme.colors.background)
        term.setTextColor(theme.colors.text_disabled)
        term.setCursorPos(x, y)
        term.write("Queue is empty")
        return
    end
    
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.text_primary)
    term.setCursorPos(x, y)
    term.write("Queue (" .. #state.queue .. " songs):")
    
    local displayCount = math.min(maxItems, #state.queue)
    for i = 1, displayCount do
        local song = state.queue[i]
        term.setTextColor(theme.colors.text_secondary)
        term.setCursorPos(x, y + i)
        
        local queueText = i .. ". " .. common.truncateString(song.name, state.width - x - 4)
        term.write(queueText)
    end
    
    if #state.queue > maxItems then
        term.setTextColor(theme.colors.text_disabled)
        term.setCursorPos(x, y + maxItems + 1)
        term.write("... and " .. (#state.queue - maxItems) .. " more")
    end
end

-- Search results component
function components.drawSearchResults(state, x, y, maxItems, clickAreas)
    local theme = getTheme()
    maxItems = maxItems or 8
    
    if not state.search_results or #state.search_results == 0 then
        if state.search_error then
            term.setBackgroundColor(theme.colors.background)
            term.setTextColor(theme.colors.error)
            term.setCursorPos(x, y)
            term.write("Search error - please try again")
        elseif state.last_search then
            term.setBackgroundColor(theme.colors.background)
            term.setTextColor(theme.colors.text_disabled)
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
            term.setBackgroundColor(theme.colors.button_hover)
            term.setTextColor(theme.colors.text_primary)
        else
            term.setBackgroundColor(theme.colors.background)
            term.setTextColor(theme.colors.text_secondary)
        end
        
        term.setCursorPos(x, y + i - 1)
        term.clearLine()
        
        local resultText = i .. ". " .. common.truncateString(result.name .. " - " .. result.artist, state.width - x - 4)
        term.write(resultText)
        
        -- Store click area
        if clickAreas then
            clickAreas["result_" .. i] = {
                x1 = x,
                y1 = y + i - 1,
                x2 = state.width - 1,
                y2 = y + i - 1,
                action = "select_result",
                index = i
            }
        end
    end
end

-- Loading spinner component
function components.drawLoadingSpinner(x, y, frame)
    local theme = getTheme()
    local spinners = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
    frame = (frame % #spinners) + 1
    
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.loading)
    term.setCursorPos(x, y)
    term.write(spinners[frame])
end

-- Text input component
function components.drawTextInput(x, y, width, text, placeholder, isFocused)
    local theme = getTheme()
    placeholder = placeholder or ""
    text = text or ""
    
    local bgColor = isFocused and theme.colors.search_box or theme.colors.background
    local textColor = (#text > 0) and theme.colors.text_primary or theme.colors.text_disabled
    
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
    local theme = getTheme()
    term.setCursorBlink(false)
    term.setBackgroundColor(theme.colors.background)
    term.clear()
end

return components 