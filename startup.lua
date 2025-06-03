-- Bognesferga Radio for ComputerCraft
-- Modular version with clean separation of concerns

-- Import all modules
local stateModule = require("musicplayer.state")
local main = require("musicplayer.main")
local audio = require("musicplayer.audio")
local network = require("musicplayer.network")

-- Check for speakers
local speakers = { peripheral.find("speaker") }
if #speakers == 0 then
    error("No speakers attached. You need to connect a speaker to this computer. If this is an Advanced Noisy Pocket Computer, then this is a bug, and you should try restarting your Minecraft game.", 0)
end

-- Initialize state
local state = stateModule.init()

-- Start all parallel loops
parallel.waitForAny(
    function() main.uiLoop(state) end,
    function() audio.loop(state) end,
    function() network.loop(state) end
) 