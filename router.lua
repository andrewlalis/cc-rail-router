--[[
This program should be installed on a portable computer with a wireless
modem, to act as a routing beacon in conjunction with managed switches.
]]--
local modem = peripheral.wrap("back") or error("Missing modem.")

local args = {...}

local route = args
print("Routing via:")
for _, branch in pairs(route) do
    print("  "..branch)
end

local function sendRoute(route)
    modem.transmit(0, 42, route)
end

while true do
    sendRoute(route)
    os.sleep(1)
end
