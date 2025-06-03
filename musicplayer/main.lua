-- Main loop module for the radio player
local config = require("musicplayer.config")
local ui = require("musicplayer.ui")
local input = require("musicplayer.input")
local network = require("musicplayer.network")

local main = {}

function main.uiLoop(state)
    ui.redrawScreen(state)

    while true do
        if state.waiting_for_input then
            main.handleSearchInput(state)
        else
            parallel.waitForAny(
                function()
                    main.handleMouseClick(state)
                end,
                function()
                    main.handleMouseDrag(state)
                end,
                function()
                    main.handleRedrawEvent(state)
                end
            )
        end
    end
end

function main.handleSearchInput(state)
    parallel.waitForAny(
        function()
            term.setCursorPos(4, 5)
            term.setBackgroundColor(config.ui.colors.button_active)
            term.setTextColor(config.ui.colors.background)
            local input = read()

            network.performSearch(state, input)
            state.waiting_for_input = false
            os.queueEvent("redraw_screen")
        end,
        function()
            while state.waiting_for_input do
                local event, button, x, y = os.pullEvent("mouse_click")
                if y < 5 or y > 6 or x < 3 or x > state.width - 2 then
                    state.waiting_for_input = false
                    os.queueEvent("redraw_screen")
                    break
                end
            end
        end
    )
end

function main.handleMouseClick(state)
    local event, button, x, y = os.pullEvent("mouse_click")
    
    if input.handleMouseClick(state, button, x, y) then
        ui.redrawScreen(state)
    end
end

function main.handleMouseDrag(state)
    local event, button, x, y = os.pullEvent("mouse_drag")
    
    if input.handleMouseDrag(state, button, x, y) then
        ui.redrawScreen(state)
    end
end

function main.handleRedrawEvent(state)
    local event = os.pullEvent("redraw_screen")
    ui.redrawScreen(state)
end

return main 