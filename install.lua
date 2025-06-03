local baseUri = "https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/"
local files = { "help", "play", "save", "savetodevice", "startup", "menu", "setvolume" }

term.clear()

for _, file in pairs(files) do
	print("Downloading program '" .. file .. "'...")

	local response = http.get(baseUri .. file .. ".lua")
	
	if response then
		local fileInstance = fs.open(file .. ".lua", "w")
		fileInstance.write(response.readAll())
		fileInstance.close()
		response.close()
	else
		print("ERROR: Failed to download " .. file .. ".lua")
		print("Please check your internet connection and try again.")
		return
	end
end

local updateUri = "https://raw.githubusercontent.com/OniuUI/cc-musicplayer/refs/heads/master/version.txt"

local updateResponse = http.get(updateUri)

if updateResponse then
	local updateFile = fs.open("version.txt", "w")
	updateFile.write(updateResponse.readAll())
	updateFile.close()
	updateResponse.close()
	
	print("Installation complete! Please restart your computer.")
else
	print("ERROR: Failed to download version.txt")
	print("Installation may be incomplete.")
end
