local baseUri = "https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/"

term.clear()

print("Installing iPod-style Music Player...")
print("Setting up modular structure...")

-- Create musicplayer directory
if not fs.exists("musicplayer") then
	fs.makeDir("musicplayer")
	print("✓ Created musicplayer directory")
end

-- List of files to download
local files = {
	{name = "startup.lua", path = "startup.lua"},
	{name = "config.lua", path = "musicplayer/config.lua"},
	{name = "state.lua", path = "musicplayer/state.lua"},
	{name = "ui.lua", path = "musicplayer/ui.lua"},
	{name = "input.lua", path = "musicplayer/input.lua"},
	{name = "audio.lua", path = "musicplayer/audio.lua"},
	{name = "network.lua", path = "musicplayer/network.lua"},
	{name = "main.lua", path = "musicplayer/main.lua"}
}

-- Download each file
for _, file in ipairs(files) do
	print("Downloading " .. file.name .. "...")
	local response = http.get(baseUri .. file.name)
	
	if response then
		local fileInstance = fs.open(file.path, "w")
		fileInstance.write(response.readAll())
		fileInstance.close()
		response.close()
		print("✓ Downloaded " .. file.name)
	else
		print("ERROR: Failed to download " .. file.name)
		print("Please check your internet connection and try again.")
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
