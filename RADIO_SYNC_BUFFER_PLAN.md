# Radio Host PRE-Buffer Synchronization System

## Overview

This document outlines the implementation of a PRE-buffer system for the radio host that ensures synchronized playback across all clients regardless of network latency, distance, or processing delays.

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           RADIO HOST (Server)                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌──────────────────┐    ┌─────────────────────────────┐ │
│  │   Audio     │    │   PRE-BUFFER     │    │    Network Broadcast       │ │
│  │   Stream    │───▶│   (30-60 sec)    │───▶│    with Timestamps         │ │
│  │   Source    │    │                  │    │                             │ │
│  └─────────────┘    └──────────────────┘    └─────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │              Buffer Management System                                   │ │
│  │  • Maintains 30-60 second audio buffer                                 │ │
│  │  • Tracks buffer positions with precise timestamps                     │ │
│  │  • Monitors client latency and adjusts playback timing                 │ │
│  │  • Determines optimal sync point for all clients                       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         NETWORK LAYER                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │   Latency       │  │   Buffer Data   │  │    Sync Commands           │  │
│  │   Measurement   │  │   Broadcast     │  │    & Timing                │  │
│  │   (Ping/Pong)   │  │   (Chunked)     │  │    Adjustments             │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CLIENT NODES (Multiple)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Client A (Fast - 50ms latency)     Client B (Medium - 200ms latency)     │
│  ┌─────────────────────────────┐    ┌─────────────────────────────────┐     │
│  │  ┌─────────────────────────┐ │    │  ┌─────────────────────────────┐ │     │
│  │  │    Local Buffer         │ │    │  │    Local Buffer             │ │     │
│  │  │    (30-60 sec)          │ │    │  │    (30-60 sec)              │ │     │
│  │  └─────────────────────────┘ │    │  └─────────────────────────────┘ │     │
│  │             │                │    │             │                    │     │
│  │             ▼                │    │             ▼                    │     │
│  │  ┌─────────────────────────┐ │    │  ┌─────────────────────────────┐ │     │
│  │  │   Sync Calculator       │ │    │  │   Sync Calculator           │ │     │
│  │  │   Delay: +150ms         │ │    │  │   Delay: +0ms (slowest)     │ │     │
│  │  │   (Wait for slowest)    │ │    │  │   (Sets the tempo)          │ │     │
│  │  └─────────────────────────┘ │    │  └─────────────────────────────┘ │     │
│  │             │                │    │             │                    │     │
│  │             ▼                │    │             ▼                    │     │
│  │  ┌─────────────────────────┐ │    │  ┌─────────────────────────────┐ │     │
│  │  │    Audio Playback       │ │    │  │    Audio Playback           │ │     │
│  │  │    (Synchronized)       │ │    │  │    (Synchronized)           │ │     │
│  │  └─────────────────────────┘ │    │  └─────────────────────────────┘ │     │
│  └─────────────────────────────┘    └─────────────────────────────────┘     │
│                                                                             │
│  Client C (Slow - 500ms latency)                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ┌─────────────────────────┐                                         │   │
│  │  │    Local Buffer         │                                         │   │
│  │  │    (30-60 sec)          │                                         │   │
│  │  └─────────────────────────┘                                         │   │
│  │             │                                                         │   │
│  │             ▼                                                         │   │
│  │  ┌─────────────────────────┐                                         │   │
│  │  │   Sync Calculator       │                                         │   │
│  │  │   Delay: +0ms           │  ◄─── This client sets the tempo        │   │
│  │  │   (Slowest client)      │       for all other clients             │   │
│  │  └─────────────────────────┘                                         │   │
│  │             │                                                         │   │
│  │             ▼                                                         │   │
│  │  ┌─────────────────────────┐                                         │   │
│  │  │    Audio Playback       │                                         │   │
│  │  │    (Synchronized)       │                                         │   │
│  │  └─────────────────────────┘                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Timing Diagram

```
Time →  0s    5s    10s   15s   20s   25s   30s   35s   40s
        │     │     │     │     │     │     │     │     │
Host:   ├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────
        │ Buf │ Buf │ Buf │ Buf │ Buf │ Buf │ Buf │ Buf │ Buf
        │ 0-5 │ 5-10│10-15│15-20│20-25│25-30│30-35│35-40│40-45
        │     │     │     │     │     │     │     │     │

Client A├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────
(50ms)  │Wait │Wait │Wait │Wait │Wait │Play │Play │Play │Play
        │     │     │     │     │     │ 0-5 │ 5-10│10-15│15-20

Client B├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────
(200ms) │Wait │Wait │Wait │Wait │Play │Play │Play │Play │Play
        │     │     │     │     │ 0-5 │ 5-10│10-15│15-20│20-25

Client C├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────
(500ms) │Wait │Wait │Play │Play │Play │Play │Play │Play │Play
        │     │     │ 0-5 │ 5-10│10-15│15-20│20-25│25-30│30-35

Legend:
- Buf X-Y: Host buffering audio seconds X to Y
- Play X-Y: Client playing audio seconds X to Y
- Wait: Client waiting for sync point
```

## Implementation Plan

### Phase 1: Host-Side PRE-Buffer System

#### 1.1 Buffer Management
```lua
-- New buffer system in radio_host.lua
local audioBuffer = {
    chunks = {},           -- Array of audio chunks with timestamps
    buffer_duration = 45,  -- 45 second buffer
    chunk_duration = 0.5,  -- 500ms per chunk
    current_position = 0,  -- Current playback position in buffer
    buffer_start_time = 0, -- When buffer started
}
```

#### 1.2 Buffer Population
- **Continuous Buffering**: Host continuously downloads and buffers 45 seconds of audio ahead
- **Chunk Timestamping**: Each audio chunk gets precise timestamp when added to buffer
- **Position Tracking**: Track exact position in song and buffer simultaneously

#### 1.3 Client Latency Measurement
```lua
-- Latency tracking system
local clientLatencies = {
    [clientId] = {
        samples = {},      -- Array of latency measurements
        average = 0,       -- Rolling average latency
        last_ping = 0,     -- Last ping timestamp
        status = "active"  -- active, slow, timeout
    }
}
```

### Phase 2: Network Protocol Enhancement

#### 2.1 New Message Types
```lua
-- Latency measurement
{
    type = "ping_request",
    timestamp = os.epoch("utc"),
    sequence = 123
}

{
    type = "ping_response", 
    timestamp = os.epoch("utc"),
    sequence = 123,
    client_timestamp = original_timestamp
}

-- Buffer data broadcast
{
    type = "buffer_chunk",
    chunk_id = "song_123_chunk_45",
    audio_data = binary_data,
    buffer_position = 22.5,  -- Position in buffer (seconds)
    song_position = 67.3,    -- Position in actual song
    timestamp = os.epoch("utc")
}

-- Sync coordination
{
    type = "sync_command",
    target_position = 45.2,  -- Where all clients should be
    sync_timestamp = future_timestamp,  -- When to start playing
    slowest_client_latency = 500,  -- ms
    buffer_offset = 30.0     -- How far ahead buffer is
}
```

#### 2.2 Adaptive Sync Algorithm
```lua
function calculateOptimalSync(clientLatencies)
    -- Find slowest client
    local maxLatency = 0
    for clientId, data in pairs(clientLatencies) do
        maxLatency = math.max(maxLatency, data.average)
    end
    
    -- Add safety margin
    local syncDelay = maxLatency + 200  -- +200ms safety
    
    -- Calculate when all clients should start playing
    local syncTimestamp = os.epoch("utc") + syncDelay
    
    return {
        sync_timestamp = syncTimestamp,
        slowest_latency = maxLatency,
        recommended_delay = syncDelay
    }
end
```

### Phase 3: Client-Side Buffer Management

#### 3.1 Local Buffer System
```lua
-- Client buffer management
local clientBuffer = {
    chunks = {},           -- Received audio chunks
    target_buffer_size = 45,  -- Seconds to buffer
    current_position = 0,  -- Current playback position
    sync_offset = 0,       -- Delay to match slowest client
    playback_ready = false -- Ready to start synchronized playback
}
```

#### 3.2 Sync Calculation
```lua
function calculateClientSync(hostSyncCommand, localLatency)
    -- Calculate how much to delay playback
    local myDelay = hostSyncCommand.slowest_latency - localLatency
    
    -- Ensure we have enough buffer
    local requiredBuffer = (hostSyncCommand.slowest_latency / 1000) + 5  -- +5s safety
    
    return {
        delay_ms = math.max(0, myDelay),
        buffer_ready = (#clientBuffer.chunks * 0.5) >= requiredBuffer,
        start_timestamp = hostSyncCommand.sync_timestamp + myDelay
    }
end
```

### Phase 4: Advanced Features

#### 4.1 Dynamic Buffer Adjustment
- **Network Quality Monitoring**: Adjust buffer size based on network stability
- **Adaptive Chunk Size**: Smaller chunks for low latency, larger for stability
- **Quality Degradation**: Reduce audio quality if network can't keep up

#### 4.2 Fallback Mechanisms
- **Buffer Underrun Protection**: Pause all clients if any client's buffer runs low
- **Client Dropout Handling**: Remove slow clients from sync calculation if needed
- **Emergency Resync**: Force resync if clients drift too far apart

#### 4.3 Performance Optimization
- **Predictive Buffering**: Pre-load next song's buffer before current song ends
- **Compression**: Compress audio chunks for faster network transfer
- **Priority Queuing**: Prioritize sync messages over audio data

## Configuration Options

```lua
-- New config section for buffer system
config.radio_sync = {
    -- Buffer settings
    buffer_duration = 45,        -- Seconds of audio to buffer
    chunk_duration = 0.5,        -- Duration of each audio chunk
    safety_margin = 5,           -- Extra buffer time for safety
    
    -- Latency management
    max_client_latency = 2000,   -- Max allowed latency (ms)
    latency_samples = 10,        -- Number of samples for average
    ping_interval = 5,           -- Seconds between latency measurements
    
    -- Sync behavior
    sync_tolerance = 100,        -- Acceptable drift (ms)
    resync_threshold = 500,      -- Force resync if drift exceeds this
    slow_client_timeout = 30,    -- Remove clients that can't keep up
    
    -- Performance
    enable_compression = true,   -- Compress audio chunks
    adaptive_quality = true,     -- Reduce quality for slow clients
    predictive_buffering = true  -- Pre-load next song
}
```

## Benefits of This System

1. **Network Latency Compensation**: Automatically adjusts for different client latencies
2. **Scalable**: Works with any number of clients at various distances
3. **Fault Tolerant**: Handles client dropouts and network issues gracefully
4. **Quality Adaptive**: Maintains best possible quality for each client's connection
5. **Synchronized**: All clients play the exact same audio at the exact same time
6. **Buffer Protection**: Large buffer prevents audio dropouts from network hiccups

## Implementation Timeline

- **Week 1**: Implement host-side buffer system and basic chunk management
- **Week 2**: Add latency measurement and client tracking
- **Week 3**: Implement client-side buffer and sync calculation
- **Week 4**: Add advanced features and optimization
- **Week 5**: Testing and refinement with multiple clients

This system ensures that regardless of network conditions, all radio clients will play synchronized audio, with the slowest client setting the tempo for everyone else. 