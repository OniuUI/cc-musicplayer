local baseUri = "https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/"

term.clear()

print("Installing iPod-style Music Player...")
print("Setting up modular structure...")

-- Test HTTP connectivity first
print("Testing HTTP connectivity...")
local testResponse = http.get("https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/version.txt")
if testResponse then
	local testContent = testResponse.readAll()
	testResponse.close()
	print("✓ HTTP connectivity OK (version: " .. testContent .. ")")
else
	print("ERROR: Cannot connect to GitHub")
	print("This might be due to:")
	print("• Internet connection issues")
	print("• ComputerCraft HTTP whitelist restrictions")
	print("• Server configuration blocking requests")
	return
end

-- Create musicplayer directory
if not fs.exists("musicplayer") then
	fs.makeDir("musicplayer")
	print("✓ Created musicplayer directory")
end

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

-- Download each file
for _, file in ipairs(files) do
	print("Downloading " .. file.name .. "...")
	print("URL: " .. file.url)
	local response = http.get(file.url)
	
	if response then
		local content = response.readAll()
		if content and content ~= "" then
			local fileInstance = fs.open(file.path, "w")
			fileInstance.write(content)
			fileInstance.close()
			response.close()
			print("✓ Downloaded " .. file.name .. " (" .. string.len(content) .. " bytes)")
		else
			print("ERROR: " .. file.name .. " downloaded but content is empty")
			if response then response.close() end
			return
		end
	else
		print("ERROR: Failed to download " .. file.name)
		print("HTTP request returned nil - check URL and internet connection")
		print("URL was: " .. file.url)
		return
	end
end

-- Create version file
local versionFile = fs.open("version.txt", "w")
versionFile.write("2.1")
versionFile.close()
print("✓ Created version file")

print("")
print("Installation complete!")
print("This modular music player features:")
print("• Clean separation of concerns")
print("• Easy to maintain and extend")
print("• YouTube search and streaming")
print("• Queue management")
print("• Volume controls")
print("• Loop modes")
print("• Modern touch interface")
print("")
print("Run 'startup' to begin using your new music player!")
