-- Main menu feature for Bognesferga Radio
-- Consolidated menu system with improved UI components

local components = require("musicplayer.ui.components")
local themes = require("musicplayer.ui.themes")

local mainMenu = {}

function mainMenu.init()
    return {
        selected_option = 1,
        clickAreas = {},
        options = {
            {
                id = "youtube",
                name = "YouTube Music Player", 
                description = "Search and play music from YouTube"
            },
            {
                id = "radio_client",
                name = "Network Radio", 
                description = "Connect to shared radio stations on the server"
            },
            {
                id = "radio_host",
                name = "Host Radio Station", 
                description = "Create your own radio station for others to join"
            },
            {
                id = "exit",
                name = "Exit", 
                description = "Close Bognesferga Radio"
            }
        }
    }
end

function mainMenu.drawMenu(state, menuState)
    components.clearScreen()
    
    -- Draw header
    components.drawHeader(state)
    
    -- Draw menu title
    local theme = themes.getCurrent()
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.text_accent)
    term.setCursorPos(3, 4)
    term.write("Welcome to Bognesferga Radio!")
    
    term.setTextColor(theme.colors.text_secondary)
    term.setCursorPos(3, 5)
    term.write("Choose your experience:")

    -- Clear click areas
    menuState.clickAreas = {}

    -- Draw menu options using the new wide button component
    for i, option in ipairs(menuState.options) do
        local y = 7 + (i - 1) * 3
        local isSelected = (i == menuState.selected_option)
        
        components.drawWideButton(
            3, y, 
            option.name, 
            option.description, 
            isSelected, 
            menuState.clickAreas, 
            option.id,
            25
        )
    end
    
    -- Instructions
    term.setTextColor(theme.colors.text_disabled)
    term.setCursorPos(3, state.height - 3)
    term.write("Click on an option above or use UP/DOWN arrows + ENTER")
    
    -- Draw footer
    components.drawFooter(state)
end

function mainMenu.handleInput(menuState)
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "key" then
            local key = param1
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
                return menuState.options[menuState.selected_option].id
            end
        elseif event == "mouse_click" or event == "monitor_touch" then
            local button, x, y
            if event == "mouse_click" then
                button, x, y = param1, param2, param3
            else -- monitor_touch
                button, x, y = 1, param2, param3  -- Treat monitor touch as left click
            end
            
            -- Check if click is on any menu option
            for optionId, clickArea in pairs(menuState.clickAreas) do
                if x >= clickArea.x1 and x <= clickArea.x2 and
                   y >= clickArea.y1 and y <= clickArea.y2 then
                    -- Find the option index
                    for i, option in ipairs(menuState.options) do
                        if option.id == optionId then
                            menuState.selected_option = i
                            return optionId
                        end
                    end
                end
            end
        end
    end
end

return mainMenu 