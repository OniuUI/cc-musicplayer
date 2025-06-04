-- HTTP Client for Bognesferga Radio
-- Handles all HTTP requests with proper error handling and retry logic

local config = require("musicplayer.config")
local common = require("musicplayer.utils.common")

local httpClient = {}

-- API configuration from working original
local API_BASE_URL = "https://ipod-2to6magyna-uc.a.run.app/"
local API_VERSION = "2.1"

-- Initialize HTTP client with error handler
function httpClient.init(errorHandler)
    httpClient.errorHandler = errorHandler
    httpClient.requestTimeout = 30 -- seconds
    httpClient.maxRetries = 3
    httpClient.retryDelay = 1 -- seconds
    
    return httpClient
end

-- Make a GET request with error handling
function httpClient.get(url, options)
    options = options or {}
    local binary = options.binary or false
    local headers = options.headers or {}
    local timeout = options.timeout or httpClient.requestTimeout
    
    -- Validate URL
    if not common.isValidUrl(url) then
        if httpClient.errorHandler then
            httpClient.errorHandler.handleNetworkError(url, "HttpClient", {reason = "Invalid URL"})
        end
        return false, "Invalid URL: " .. tostring(url)
    end
    
    -- Prepare request options
    local requestOptions = {
        url = url,
        binary = binary,
        headers = headers,
        timeout = timeout
    }
    
    -- Make request with retry logic
    for attempt = 1, httpClient.maxRetries do
        local success, handle, errorMsg = httpClient.makeRequest(requestOptions, attempt)
        
        if success then
            return true, handle
        elseif attempt < httpClient.maxRetries then
            -- Wait before retry
            sleep(httpClient.retryDelay * attempt)
        else
            -- Final attempt failed
            if httpClient.errorHandler then
                httpClient.errorHandler.handleNetworkError(url, "HttpClient", {
                    reason = errorMsg,
                    attempts = attempt
                })
            end
            return false, errorMsg
        end
    end
    
    return false, "Max retries exceeded"
end

-- Make a single HTTP request
function httpClient.makeRequest(requestOptions, attempt)
    attempt = attempt or 1
    
    -- Make the request
    http.request(requestOptions)
    
    -- Wait for response
    local success, handle, errorMsg = httpClient.waitForResponse(requestOptions.url, requestOptions.timeout)
    
    if success then
        return true, handle
    else
        return false, errorMsg or "Request failed"
    end
end

-- Wait for HTTP response with timeout
function httpClient.waitForResponse(url, timeout)
    local startTime = os.clock()
    
    while true do
        local event, eventUrl, handle = os.pullEvent()
        
        if event == "http_success" and eventUrl == url then
            return true, handle
        elseif event == "http_failure" and eventUrl == url then
            return false, "HTTP request failed"
        elseif os.clock() - startTime > timeout then
            return false, "Request timeout"
        end
    end
end

-- Download JSON data
function httpClient.getJson(url, options)
    local success, handle = httpClient.get(url, options)
    
    if not success then
        return false, handle -- handle contains error message
    end
    
    local responseText = handle.readAll()
    handle.close()
    
    if not responseText or responseText == "" then
        if httpClient.errorHandler then
            httpClient.errorHandler.handleNetworkError(url, "HttpClient", {reason = "Empty response"})
        end
        return false, "Empty response"
    end
    
    -- Parse JSON
    local parseSuccess, data = pcall(textutils.unserialiseJSON, responseText)
    
    if not parseSuccess then
        if httpClient.errorHandler then
            httpClient.errorHandler.handleNetworkError(url, "HttpClient", {
                reason = "JSON parse error",
                response = responseText:sub(1, 100) -- First 100 chars for debugging
            })
        end
        return false, "Failed to parse JSON response"
    end
    
    return true, data
end

-- Download binary data (for audio streams)
function httpClient.getBinary(url, options)
    options = options or {}
    options.binary = true
    
    return httpClient.get(url, options)
end

-- Enhanced YouTube API methods using the working original's approach
-- Make direct search request (async, returns immediately)
function httpClient.requestYouTubeSearch(searchTerm)
    if not searchTerm or searchTerm == "" then
        return false, "Empty search term"
    end
    
    local searchUrl = API_BASE_URL .. "?v=" .. API_VERSION .. "&search=" .. textutils.urlEncode(searchTerm)
    
    -- Make async request (like the working original)
    http.request(searchUrl)
    return true, searchUrl
end

-- Make direct audio stream request (async, returns immediately)
function httpClient.requestYouTubeAudio(trackId)
    if not trackId or trackId == "" then
        return false, "Empty track ID"
    end
    
    local streamUrl = API_BASE_URL .. "?v=" .. API_VERSION .. "&id=" .. textutils.urlEncode(trackId)
    
    -- Make async binary request (like the working original)
    http.request({url = streamUrl, binary = true})
    return true, streamUrl
end

-- Search for music
function httpClient.searchMusic(searchTerm)
    if not searchTerm or searchTerm == "" then
        return false, "Empty search term"
    end
    
    local searchUrl = common.buildUrl(config.api_base_url, {
        v = config.version,
        search = searchTerm
    })
    
    return httpClient.getJson(searchUrl)
end

-- Get audio stream
function httpClient.getAudioStream(trackId)
    if not trackId or trackId == "" then
        return false, "Empty track ID"
    end
    
    local streamUrl = common.buildUrl(config.api_base_url, {
        v = config.version,
        id = trackId
    })
    
    return httpClient.getBinary(streamUrl)
end

-- Check API connectivity
function httpClient.checkConnectivity()
    local testUrl = config.api_base_url .. "?v=" .. config.version .. "&ping=1"
    
    local success, handle = httpClient.get(testUrl, {timeout = 5})
    
    if success then
        handle.close()
        return true
    else
        return false, handle -- handle contains error message
    end
end

-- Get API status
function httpClient.getApiStatus()
    local statusUrl = common.buildUrl(config.api_base_url, {
        v = config.version,
        status = "1"
    })
    
    return httpClient.getJson(statusUrl)
end

-- Cancel all pending requests (if possible)
function httpClient.cancelAllRequests()
    -- ComputerCraft doesn't provide a direct way to cancel requests
    -- This is a placeholder for future implementation
    if httpClient.errorHandler then
        httpClient.errorHandler.getLogger().debug("HttpClient", "Request cancellation requested (not implemented)")
    end
end

-- Set request timeout
function httpClient.setTimeout(timeout)
    httpClient.requestTimeout = timeout
end

-- Set max retries
function httpClient.setMaxRetries(retries)
    httpClient.maxRetries = retries
end

-- Set retry delay
function httpClient.setRetryDelay(delay)
    httpClient.retryDelay = delay
end

-- Get client statistics
function httpClient.getStats()
    return {
        timeout = httpClient.requestTimeout,
        maxRetries = httpClient.maxRetries,
        retryDelay = httpClient.retryDelay
    }
end

return httpClient 