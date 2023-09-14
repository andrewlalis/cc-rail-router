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

local function readConfig()
    local f = io.open("station_config.tbl", "r")
    if not f then error("Missing station_config.tbl") end
    local cfg = textutils.unserialize(f:read("*a"))
    f:close()
    return cfg
end

local function broadcast(config)
    while true do
        modem.transmit(BROADCAST_CHANNEL, BROADCAST_CHANNEL, config)
        os.sleep(1)
    end
end

local config = readConfig()
term.clear()
term.setCursorPos(1, 1)
print("Running station transponder for \""..config.name.."\".")
print("  Display Name: "..config.displayName)
print("  Range: "..config.range.." blocks")
broadcast(config)
