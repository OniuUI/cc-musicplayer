local baseUri = "https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/"

-- Animation and color functions
local function animateText(text, color, delay)
	term.setTextColor(color)
	for i = 1, #text do
		term.write(text:sub(i, i))
		sleep(delay or 0.05)
	end
end

local function drawBanner()
	term.clear()
	term.setCursorPos(1, 1)
	
	-- Animated banner with colors
	term.setBackgroundColor(colors.blue)
	term.setTextColor(colors.white)
	term.clearLine()
	local w, h = term.getSize()
	
	-- Center the banner text
	local bannerText = "  Bognesferga Radio Installer  "
	local startX = math.floor((w - #bannerText) / 2) + 1
	term.setCursorPos(startX, 1)
	animateText(bannerText, colors.white, 0.03)
	
	term.setBackgroundColor(colors.black)
	term.setCursorPos(1, 3)
	
	-- Animated "Developed by Forty" banner
	term.setTextColor(colors.yellow)
	local devText = "Developed by "
	local nameText = "Forty"
	local centerX = math.floor((w - (#devText + #nameText)) / 2) + 1
	
	term.setCursorPos(centerX, 3)
	animateText(devText, colors.yellow, 0.04)
	
	-- Animate "Forty" with rainbow effect
	local rainbowColors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
	for i = 1, #nameText do
		local colorIndex = ((i - 1) % #rainbowColors) + 1
		term.setTextColor(rainbowColors[colorIndex])
		term.write(nameText:sub(i, i))
		sleep(0.1)
	end
	
	-- Decorative line
	term.setCursorPos(1, 5)
	term.setTextColor(colors.lightGray)
	local line = string.rep("=", w)
	animateText(line, colors.lightGray, 0.01)
	
	term.setCursorPos(1, 7)
end

local function colorPrint(text, color)
	term.setTextColor(color or colors.white)
	print(text)
end

local function animatedProgress(current, total, color)
	local w = term.getSize()
	local barWidth = w - 20
	local progress = math.floor((current / total) * barWidth)
	
	term.setTextColor(colors.white)
	term.write("[")
	
	-- Progress bar with color
	term.setTextColor(color or colors.lime)
	for i = 1, progress do
		term.write("=")
	end
	
	term.setTextColor(colors.gray)
	for i = progress + 1, barWidth do
		term.write("-")
	end
	
	term.setTextColor(colors.white)
	term.write("] ")
	
	term.setTextColor(colors.yellow)
	term.write(math.floor((current / total) * 100) .. "%")
end

-- Main installation
drawBanner()

colorPrint("Setting up advanced modular structure...", colors.cyan)
sleep(0.5)

-- Create directory structure with new organized folders
local directories = {
	"musicplayer",
	"musicplayer/core",
	"musicplayer/ui",
	"musicplayer/audio",
	"musicplayer/network",
	"musicplayer/utils",
	"musicplayer/middleware",
	"musicplayer/telemetry",
	"musicplayer/logs"
}

for _, dir in ipairs(directories) do
	if not fs.exists(dir) then
		fs.makeDir(dir)
		colorPrint("✓ Created " .. dir .. " directory", colors.lime)
	else
		colorPrint("✓ " .. dir .. " directory exists", colors.yellow)
	end
	sleep(0.1)
end

sleep(0.3)

-- Test HTTP connectivity first
colorPrint("Testing HTTP connectivity...", colors.cyan)
sleep(0.5)

local testResponse = http.get("https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/version.txt")
if testResponse then
	local testContent = testResponse.readAll()
	testResponse.close()
	colorPrint("✓ HTTP connectivity OK (version: " .. testContent .. ")", colors.lime)
else
	colorPrint("ERROR: Cannot connect to GitHub", colors.red)
	colorPrint("This might be due to:", colors.yellow)
	colorPrint("• Internet connection issues", colors.lightGray)
	colorPrint("• ComputerCraft HTTP whitelist restrictions", colors.lightGray)
	colorPrint("• Server configuration blocking requests", colors.lightGray)
	return
end

sleep(0.5)

-- Files to download with new refactored structure
local files = {
	-- Core files
	{name = "startup.lua", url = baseUri .. "startup.lua", path = "startup.lua"},
	{name = "uninstall.lua", url = baseUri .. "uninstall.lua", path = "uninstall.lua"},
	
	-- Configuration
	{name = "config.lua", url = baseUri .. "musicplayer/config.lua", path = "musicplayer/config.lua"},
	
	-- Core system modules
	{name = "system.lua", url = baseUri .. "musicplayer/core/system.lua", path = "musicplayer/core/system.lua"},
	
	-- UI modules
	{name = "components.lua", url = baseUri .. "musicplayer/ui/components.lua", path = "musicplayer/ui/components.lua"},
	{name = "ui.lua", url = baseUri .. "musicplayer/ui.lua", path = "musicplayer/ui.lua"},
	
	-- Audio modules
	{name = "speaker_manager.lua", url = baseUri .. "musicplayer/audio/speaker_manager.lua", path = "musicplayer/audio/speaker_manager.lua"},
	{name = "audio.lua", url = baseUri .. "musicplayer/audio.lua", path = "musicplayer/audio.lua"},
	
	-- Network modules
	{name = "http_client.lua", url = baseUri .. "musicplayer/network/http_client.lua", path = "musicplayer/network/http_client.lua"},
	{name = "network.lua", url = baseUri .. "musicplayer/network.lua", path = "musicplayer/network.lua"},
	
	-- Utilities
	{name = "common.lua", url = baseUri .. "musicplayer/utils/common.lua", path = "musicplayer/utils/common.lua"},
	
	-- Middleware
	{name = "error_handler.lua", url = baseUri .. "musicplayer/middleware/error_handler.lua", path = "musicplayer/middleware/error_handler.lua"},
	
	-- Legacy modules (still needed for compatibility)
	{name = "state.lua", url = baseUri .. "musicplayer/state.lua", path = "musicplayer/state.lua"},
	{name = "input.lua", url = baseUri .. "musicplayer/input.lua", path = "musicplayer/input.lua"},
	{name = "main.lua", url = baseUri .. "musicplayer/main.lua", path = "musicplayer/main.lua"},
	{name = "menu.lua", url = baseUri .. "musicplayer/menu.lua", path = "musicplayer/menu.lua"},
	{name = "radio.lua", url = baseUri .. "musicplayer/radio.lua", path = "musicplayer/radio.lua"},
	{name = "radio_ui.lua", url = baseUri .. "musicplayer/radio_ui.lua", path = "musicplayer/radio_ui.lua"},
	
	-- Application management
	{name = "system_init.lua", url = baseUri .. "musicplayer/system_init.lua", path = "musicplayer/system_init.lua"},
	{name = "app_manager.lua", url = baseUri .. "musicplayer/app_manager.lua", path = "musicplayer/app_manager.lua"},
	{name = "input_handlers.lua", url = baseUri .. "musicplayer/input_handlers.lua", path = "musicplayer/input_handlers.lua"},
	{name = "mode_handlers.lua", url = baseUri .. "musicplayer/mode_handlers.lua", path = "musicplayer/mode_handlers.lua"},
	
	-- Telemetry modules
	{name = "telemetry.lua", url = baseUri .. "musicplayer/telemetry/telemetry.lua", path = "musicplayer/telemetry/telemetry.lua"},
	{name = "logger.lua", url = baseUri .. "musicplayer/telemetry/logger.lua", path = "musicplayer/telemetry/logger.lua"},
	{name = "system_detector.lua", url = baseUri .. "musicplayer/telemetry/system_detector.lua", path = "musicplayer/telemetry/system_detector.lua"}
}

colorPrint("Downloading " .. #files .. " files...", colors.cyan)
sleep(0.3)

-- Download each file with animated progress
for i, file in ipairs(files) do
	term.setTextColor(colors.white)
	term.write("Downloading " .. file.name .. "... ")
	
	-- Show progress bar
	local x, y = term.getCursorPos()
	term.setCursorPos(1, y + 1)
	animatedProgress(i - 1, #files, colors.orange)
	term.setCursorPos(x, y)
	
	local response = http.get(file.url)
	
	if response then
		local content = response.readAll()
		if content and content ~= "" then
			local fileInstance = fs.open(file.path, "w")
			fileInstance.write(content)
			fileInstance.close()
			response.close()
			
			colorPrint("✓ (" .. string.len(content) .. " bytes)", colors.lime)
		else
			colorPrint("ERROR: Content is empty", colors.red)
			if response then response.close() end
			return
		end
	else
		colorPrint("ERROR: Failed to download", colors.red)
		colorPrint("URL was: " .. file.url, colors.lightGray)
		return
	end
	
	sleep(0.2)
end

-- Final progress bar
local _, currentY = term.getCursorPos()
term.setCursorPos(1, currentY)
animatedProgress(#files, #files, colors.lime)
print()

-- Create version file
local versionFile = fs.open("version.txt", "w")
versionFile.write("4.1")
versionFile.close()
colorPrint("✓ Created version file (v4.1)", colors.lime)

sleep(0.5)

-- Success animation
local _, currentY = term.getCursorPos()
term.setCursorPos(1, currentY + 1)
colorPrint("Installation complete!", colors.lime)

-- Feature list with colors
sleep(0.3)
colorPrint("This advanced radio player features:", colors.cyan)
local features = {
	"• Modular architecture with organized code structure",
	"• Advanced error handling middleware",
	"• Comprehensive HTTP client with retry logic",
	"• Smart speaker management system",
	"• Reusable UI components",
	"• Utility functions to avoid code duplication",
	"• Enhanced telemetry and logging system",
	"• Dual-screen support with debug console",
	"• YouTube search and streaming",
	"• Network radio functionality"
}

for i, feature in ipairs(features) do
	local featureColors = {colors.yellow, colors.orange, colors.red, colors.magenta, colors.purple, colors.blue, colors.cyan, colors.lime, colors.white, colors.lightBlue}
	local colorIndex = ((i - 1) % #featureColors) + 1
	colorPrint(feature, featureColors[colorIndex])
	sleep(0.1)
end

sleep(0.5)

-- Final message with animation
local _, currentY = term.getCursorPos()
term.setCursorPos(1, currentY + 2)

-- Startup instructions section with banner
term.setBackgroundColor(colors.green)
term.setTextColor(colors.white)
local w = term.getSize()
local instructionBanner = "  HOW TO START YOUR RADIO  "
local bannerX = math.floor((w - #instructionBanner) / 2) + 1
term.setCursorPos(bannerX, currentY + 2)
term.clearLine()
animateText(instructionBanner, colors.white, 0.03)

term.setBackgroundColor(colors.black)
term.setCursorPos(1, currentY + 4)

-- Step by step instructions with colors
colorPrint("To start your Bognesferga Radio:", colors.cyan)
sleep(0.3)

local steps = {
	{text = "1. Type: ", color = colors.white, code = "startup", codeColor = colors.yellow},
	{text = "2. Press Enter to launch", color = colors.white},
	{text = "3. Connect speakers if needed", color = colors.lightGray},
	{text = "4. For dual-screen: Connect 2 monitors", color = colors.lightGray},
	{text = "5. Check logs in musicplayer/logs/", color = colors.lightGray},
	{text = "6. Enjoy your enhanced music experience!", color = colors.lime}
}

for i, step in ipairs(steps) do
	sleep(0.2)
	term.setTextColor(step.color)
	term.write(step.text)
	if step.code then
		term.setTextColor(step.codeColor)
		term.write(step.code)
	end
	print()
end

sleep(0.5)

-- Quick start box
local _, currentY = term.getCursorPos()
term.setCursorPos(1, currentY + 1)
term.setBackgroundColor(colors.blue)
term.setTextColor(colors.white)
term.clearLine()
local quickStart = "  QUICK START: Just type 'startup' now!  "
local quickX = math.floor((w - #quickStart) / 2) + 1
term.setCursorPos(quickX, currentY + 1)
animateText(quickStart, colors.white, 0.02)

term.setBackgroundColor(colors.black)
term.setCursorPos(1, currentY + 3)

-- Additional tips
colorPrint("New in v4.1:", colors.yellow)
colorPrint("• Modular code architecture", colors.lightGray)
colorPrint("• Enhanced error handling", colors.lightGray)
colorPrint("• Improved network reliability", colors.lightGray)
colorPrint("• Better speaker management", colors.lightGray)
colorPrint("• Reusable UI components", colors.lightGray)
colorPrint("• Type 'uninstall' to remove the system", colors.lightGray)

sleep(0.5)

-- Final animated message
local _, currentY = term.getCursorPos()
term.setCursorPos(1, currentY + 2)
term.setTextColor(colors.lime)
term.write("Ready to rock with enhanced architecture! ")
term.setTextColor(colors.yellow)
term.write("Type 'startup' to begin!")

-- Enhanced blinking effect
for i = 1, 5 do
	sleep(0.3)
	term.setTextColor(colors.red)
	term.write(" ♪")
	sleep(0.3)
	local x, y = term.getCursorPos()
	term.setCursorPos(x - 1, y)
	term.write(" ")
	term.setCursorPos(x - 1, y)
end

term.setTextColor(colors.white)
print()
print()
