-- Simple coordinate test for monitor touch events
local width, height = term.getSize()

print("Screen size: " .. width .. "x" .. height)
print("Click anywhere to see coordinates...")
print("Press 'q' to quit")

while true do
    local event, param1, param2, param3 = os.pullEvent()
    
    if event == "mouse_click" then
        local button, x, y = param1, param2, param3
        print("MOUSE_CLICK: button=" .. button .. " x=" .. x .. " y=" .. y)
    elseif event == "monitor_touch" then
        local side, x, y = param1, param2, param3
        print("MONITOR_TOUCH: side=" .. side .. " x=" .. x .. " y=" .. y)
    elseif event == "key" then
        local key = param1
        if key == keys.q then
            break
        end
    end
end

print("Test finished") 