--[[
Stations are kiosks where users can configure their portable computer for a
particular route to another station.
]]--

local modem = peripheral.wrap("top") or error("Missing top modem")
local CHANNEL = 1
local STATION_NAME = "Test Station"

local function broadcastName()
    while true do
        modem.transmit(CHANNEL, CHANNEL, STATION_NAME)
        os.sleep(1)
    end
end

parallel.waitForAll(
    broadcastName
)
