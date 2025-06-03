-- Main menu module for Bognesferga Radio
local config = require("musicplayer.config")

local menu = {}

function menu.init()
    return {
        selected_option = 1,
        options = {
            {name = "YouTube Music Player", description = "Search and play music from YouTube"},
            {name = "Network Radio", description = "Connect to shared radio stations on the server"},
            {name = "Host Radio Station", description = "Create your own radio station for others to join"},
            {name = "Exit", description = "Close Bognesferga Radio"}
        }
    }
end

function menu.drawMenu(state, menuState)
    term.setCursorBlink(false)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()

    -- Draw header
    menu.drawHeader(state)
    
    -- Draw menu title
    term.setBackgroundColor(config.ui.colors.background)
    term.setTextColor(config.ui.colors.text_accent)
    term.setCursorPos(3, 4)
    term.write("Welcome to Bognesferga Radio!")
    
    term.setTextColor(config.ui.colors.text_secondary)
    term.setCursorPos(3, 5)
    term.write("Choose your experience:")

    -- Draw menu options
    for i, option in ipairs(menuState.options) do
        local y = 7 + (i - 1) * 3
        
        if i == menuState.selected_option then
            -- Highlight selected option
            term.setBackgroundColor(config.ui.colors.button_active)
            term.setTextColor(config.ui.colors.background)
        else
            term.setBackgroundColor(config.ui.colors.button)
            term.setTextColor(config.ui.colors.text_primary)
        end
        
        -- Option box
        term.setCursorPos(3, y)
        term.clearLine()
        term.write(" " .. option.name .. " ")
        
        -- Description
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_secondary)
        term.setCursorPos(3, y + 1)
        term.write(option.description)
    end
    
    -- Instructions
    term.setTextColor(config.ui.colors.text_disabled)
    term.setCursorPos(3, state.height - 3)
    term.write("Use UP/DOWN arrows to navigate, ENTER to select")
    
    -- Draw footer
    menu.drawFooter(state)
end

function menu.drawHeader(state)
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

function menu.drawFooter(state)
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

function menu.handleInput(menuState)
    while true do
        local event, key = os.pullEvent("key")
        
        if key == keys.up then
            menuState.selected_option = menuState.selected_option - 1
            if menuState.selected_option < 1 then
                menuState.selected_option = #menuState.options
            end
            return "redraw"
        elseif key == keys.down then
            menuState.selected_option = menuState.selected_option + 1
            if menuState.selected_option > #menuState.options then
                menuState.selected_option = 1
            end
            return "redraw"
        elseif key == keys.enter then
            return menuState.options[menuState.selected_option].name
        end
    end
end

return menu 