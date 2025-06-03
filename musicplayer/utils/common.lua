-- Common utilities for the Bognesferga Radio system
-- Contains frequently used functions to avoid code duplication

local common = {}

-- String utilities
function common.truncateString(str, maxLength, suffix)
    suffix = suffix or "..."
    if #str <= maxLength then
        return str
    end
    return str:sub(1, maxLength - #suffix) .. suffix
end

function common.centerText(text, width)
    local padding = math.floor((width - #text) / 2)
    return math.max(1, padding + 1)
end

function common.padString(str, length, char, align)
    char = char or " "
    align = align or "left"
    
    if #str >= length then
        return str
    end
    
    local padding = length - #str
    if align == "center" then
        local leftPad = math.floor(padding / 2)
        local rightPad = padding - leftPad
        return string.rep(char, leftPad) .. str .. string.rep(char, rightPad)
    elseif align == "right" then
        return string.rep(char, padding) .. str
    else
        return str .. string.rep(char, padding)
    end
end

-- Table utilities
function common.deepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = common.deepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function common.tableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function common.tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Math utilities
function common.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function common.round(num, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

-- Time utilities
function common.formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%d:%02d", minutes, secs)
    end
end

function common.getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- Color utilities
function common.getColorName(colorValue)
    local colorNames = {
        [colors.white] = "white",
        [colors.orange] = "orange",
        [colors.magenta] = "magenta",
        [colors.lightBlue] = "lightBlue",
        [colors.yellow] = "yellow",
        [colors.lime] = "lime",
        [colors.pink] = "pink",
        [colors.gray] = "gray",
        [colors.lightGray] = "lightGray",
        [colors.cyan] = "cyan",
        [colors.purple] = "purple",
        [colors.blue] = "blue",
        [colors.brown] = "brown",
        [colors.green] = "green",
        [colors.red] = "red",
        [colors.black] = "black"
    }
    return colorNames[colorValue] or "unknown"
end

-- File utilities
function common.ensureDirectory(path)
    if not fs.exists(path) then
        fs.makeDir(path)
        return true
    end
    return false
end

function common.fileExists(path)
    return fs.exists(path) and not fs.isDir(path)
end

function common.directoryExists(path)
    return fs.exists(path) and fs.isDir(path)
end

-- URL utilities
function common.buildUrl(baseUrl, params)
    local url = baseUrl
    local first = true
    
    for key, value in pairs(params) do
        if first then
            url = url .. "?"
            first = false
        else
            url = url .. "&"
        end
        url = url .. textutils.urlEncode(tostring(key)) .. "=" .. textutils.urlEncode(tostring(value))
    end
    
    return url
end

-- Validation utilities
function common.isValidUrl(url)
    return type(url) == "string" and (url:match("^https?://") ~= nil)
end

function common.isValidNumber(value, min, max)
    local num = tonumber(value)
    if not num then
        return false
    end
    
    if min and num < min then
        return false
    end
    
    if max and num > max then
        return false
    end
    
    return true
end

-- Event utilities
function common.safeQueueEvent(eventName, ...)
    local success, err = pcall(os.queueEvent, eventName, ...)
    if not success then
        -- Fallback: try to log the error if possible
        print("Error queuing event '" .. eventName .. "': " .. tostring(err))
    end
    return success
end

-- Safe function execution
function common.safePcall(func, ...)
    local success, result = pcall(func, ...)
    if success then
        return true, result
    else
        return false, tostring(result)
    end
end

return common 