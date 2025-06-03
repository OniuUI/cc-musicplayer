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

colorPrint("Setting up modular structure...", colors.cyan)
sleep(0.5)

-- Create musicplayer directory
if not fs.exists("musicplayer") then
	fs.makeDir("musicplayer")
	colorPrint("✓ Created musicplayer directory", colors.lime)
else
	colorPrint("✓ Musicplayer directory exists", colors.yellow)
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

-- List of files to download
local files = {
	{name = "startup.lua", url = baseUri .. "startup.lua", path = "startup.lua"},
	{name = "config.lua", url = baseUri .. "musicplayer/config.lua", path = "musicplayer/config.lua"},
	{name = "state.lua", url = baseUri .. "musicplayer/state.lua", path = "musicplayer/state.lua"},
	{name = "ui.lua", url = baseUri .. "musicplayer/ui.lua", path = "musicplayer/ui.lua"},
	{name = "input.lua", url = baseUri .. "musicplayer/input.lua", path = "musicplayer/input.lua"},
	{name = "audio.lua", url = baseUri .. "musicplayer/audio.lua", path = "musicplayer/audio.lua"},
	{name = "network.lua", url = baseUri .. "musicplayer/network.lua", path = "musicplayer/network.lua"},
	{name = "main.lua", url = baseUri .. "musicplayer/main.lua", path = "musicplayer/main.lua"}
}

colorPrint("Downloading files...", colors.cyan)
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
versionFile.write("2.1")
versionFile.close()
colorPrint("✓ Created version file", colors.lime)

sleep(0.5)

-- Success animation
local _, currentY = term.getCursorPos()
term.setCursorPos(1, currentY + 1)
colorPrint("Installation complete!", colors.lime)

-- Feature list with colors
sleep(0.3)
colorPrint("This modular radio player features:", colors.cyan)
local features = {
	"• Clean separation of concerns",
	"• Easy to maintain and extend", 
	"• YouTube search and streaming",
	"• Queue management",
	"• Volume controls",
	"• Loop modes",
	"• Modern touch interface"
}

for i, feature in ipairs(features) do
	local featureColors = {colors.yellow, colors.orange, colors.red, colors.magenta, colors.purple, colors.blue, colors.cyan}
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
	{text = "4. Search for music on YouTube", color = colors.lightGray},
	{text = "5. Enjoy your music!", color = colors.lime}
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
colorPrint("Tips:", colors.yellow)
colorPrint("• Use the Search tab to find YouTube videos", colors.lightGray)
colorPrint("• Click volume bar to adjust sound", colors.lightGray)
colorPrint("• Try pasting YouTube playlist links", colors.lightGray)
colorPrint("• Use Loop button to repeat songs/queue", colors.lightGray)

sleep(0.5)

-- Final animated message
local _, currentY = term.getCursorPos()
term.setCursorPos(1, currentY + 2)
term.setTextColor(colors.lime)
term.write("Ready to rock! ")
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
