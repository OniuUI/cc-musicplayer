-- Network handling module for the radio player
local config = require("musicplayer.config")

local network = {}

function network.loop(state)
    while true do
        parallel.waitForAny(
            function()
                network.handleHttpSuccess(state)
            end,
            function()
                network.handleHttpFailure(state)
            end
        )
    end
end

function network.handleHttpSuccess(state)
    local event, url, handle = os.pullEvent("http_success")

    if url == state.last_search_url then
        network.handleSearchResponse(state, handle)
    elseif url == state.last_download_url then
        network.handleDownloadResponse(state, handle)
    end
end

function network.handleHttpFailure(state)
    local event, url = os.pullEvent("http_failure")

    if url == state.last_search_url then
        state.search_error = true
        os.queueEvent("redraw_screen")
    elseif url == state.last_download_url then
        state.is_loading = false
        state.is_error = true
        state.playing = false
        state.playing_id = nil
        os.queueEvent("redraw_screen")
        os.queueEvent("audio_update")
    end
end

function network.handleSearchResponse(state, handle)
    state.search_results = textutils.unserialiseJSON(handle.readAll())
    handle.close()
    os.queueEvent("redraw_screen")
end

function network.handleDownloadResponse(state, handle)
    state.is_loading = false
    state.player_handle = handle
    state.start = handle.read(config.initial_read_size)
    state.size = config.chunk_size
    state.playing_status = 1
    os.queueEvent("redraw_screen")
    os.queueEvent("audio_update")
end

function network.performSearch(state, searchTerm)
    if string.len(searchTerm) > 0 then
        state.last_search = searchTerm
        state.last_search_url = config.api_base_url .. "?v=" .. config.version .. "&search=" .. textutils.urlEncode(searchTerm)
        http.request(state.last_search_url)
        state.search_results = nil
        state.search_error = false
    else
        state.last_search = nil
        state.last_search_url = nil
        state.search_results = nil
        state.search_error = false
    end
end

return network 