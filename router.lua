--[[
This program should be installed on a portable computer with a wireless
modem, to act as a routing beacon in conjunction with managed switches.
]]--
local modem = peripheral.wrap("back") or error("Missing modem.")

local STATION_CHANNEL = 1

local function broadcastRoute(route)
    while true do
        modem.transmit(0, 42, route)
        os.sleep(0.5)
    end
end

-- Repeats until we are within range of a station that's sending out its info.
local function waitForStation(stationName)
    while true do
        local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
        if channel == STATION_CHANNEL and msg == stationName and dist <= 16 then
            print("Arrived at station " .. stationName)
            return
        end
    end
end

local args = {...}

local route = args
print("Routing via:")
for _, branch in pairs(route) do
    print("  "..branch)
end

parallel.waitForAny(
    function() broadcastRoute(route) end
    function() waitForStation(route[#route]) end
)
