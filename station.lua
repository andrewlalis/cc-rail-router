--[[
Stations are kiosks where users can configure their portable computer for a
particular route to another station.

You should add a "station_config.tbl" file containing:
{
    name = "stationname",
    displayName = "Station Name",
    range = 8
}
]]--

local modem = peripheral.wrap("top") or error("Missing top modem")
local BROADCAST_CHANNEL = 45451
local RECEIVE_CHANNEL = 45452

modem.open(RECEIVE_CHANNEL)

local function readConfig()
    local f = io.open("station_config.tbl", "r")
    if not f then error("Missing station_config.tbl") end
    local cfg = textutils.unserialize(f:read("*a"))
    f:close()
    return cfg
end

local function broadcastName(config)
    while true do
        modem.transmit(BROADCAST_CHANNEL, BROADCAST_CHANNEL, config.name)
        os.sleep(1)
    end
end

local function handleRequests(config)
    while true do
        local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
        if channel == RECEIVE_CHANNEL and dist <= config.range then
            if msg == "GET_ROUTES" then
                modem.transmit(replyChannel, RECEIVE_CHANNEL, config.routes)
                print(textutils.formatTime(os.time()).." Sent routes to "..replyChannel)
            end
        end
    end
end

local config = readConfig()
term.clear()
term.setCursorPos(1, 1)
print("Running station transponder for \""..config.name.."\".")
print("  Display Name: "..config.displayName)
print("  Range: "..config.range.." blocks")
print("  Routes:")
for i, route in pairs(config.routes) do
    local pathStr = ""
    for j, segment in pairs(route.path) do
        pathStr = pathStr .. segment
        if j < #route.path then pathStr = pathStr .. "," end
    end
    print("   "..i..". "..route.name..": "..pathStr)
end
parallel.waitForAll(
    function() broadcastName(config) end,
    function() handleRequests(config) end
)
