local baseUri = "https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/"

term.clear()

print("Installing iPod-style Music Player...")
print("Downloading main program...")

local response = http.get(baseUri .. "startup.lua")

if response then
	local fileInstance = fs.open("startup.lua", "w")
	fileInstance.write(response.readAll())
	fileInstance.close()
	response.close()
	print("✓ Downloaded startup.lua")
else
	print("ERROR: Failed to download startup.lua")
	print("Please check your internet connection and try again.")
	return
end

-- Create version file
local versionFile = fs.open("version.txt", "w")
versionFile.write("2.1")
versionFile.close()
print("✓ Created version file")

print("")
print("Installation complete!")
print("This music player features:")
print("• YouTube search and streaming")
print("• Queue management")
print("• Volume controls")
print("• Loop modes")
print("• Modern touch interface")
print("")
print("Run 'startup' to begin using your new music player!")
