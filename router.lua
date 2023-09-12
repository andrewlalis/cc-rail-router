--[[
This program should be installed on a portable computer with a wireless
modem, to act as a routing beacon in conjunction with managed switches.
]]--
local SWITCH_CHANNEL = 45450
local STATION_BROADCAST_CHANNEL = 45451
local STATION_REQUEST_CHANNEL = 45452
local MY_CHANNEL = 45460

local g = require("simple-graphics")
local W, H = term.getSize()

local modem = peripheral.wrap("back") or error("Missing modem.")
modem.open(MY_CHANNEL) -- Listen for messages directed to this device.
modem.open(STATION_BROADCAST_CHANNEL) -- Listen for station broadcasts.

local function serializeRoutePath(path)
    local str = ""
    for i, segment in pairs(path) do
        str = str .. segment
        if i < #path then str = str .. "," end
    end
    return str
end

local function broadcastRoute(route)
    while true do
        modem.transmit(SWITCH_CHANNEL, MY_CHANNEL, route)
        os.sleep(0.5)
    end
end

-- Repeats until we are within range of a station that's sending out its info.
local function waitForStation(stationName)
    while true do
        local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
        if channel == STATION_BROADCAST_CHANNEL and msg == stationName and dist <= 16 then
            return
        end
    end
end

local function listenForAnyStation()
    while true do
        local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
        if channel == STATION_BROADCAST_CHANNEL and type(msg) == "string" and dist <= 16 then
            os.queueEvent("rail_station_nearby", msg, dist)
        end
    end
end

local function waitForNoStation(targetName)
    local lastPing = os.epoch()
    while os.epoch() - lastPing < 5000 do
        parallel.waitForAny(
            function ()
                local event, name, dist = os.pullEvent("rail_station_nearby")
                if not targetName or targetName == name then
                    stationPresent = true
                    lastPing = os.epoch()
                end
            end,
            function () os.sleep(3) end
        )
    end
end

local function waitForModemMessage(expectedReplyChannel, timeout)
    local data = nil
    parallel.waitForAny(
        function ()
            while true do
                local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
                if replyChannel == expectedReplyChannel then
                    data = {}
                    data.channel = channel
                    data.replyChannel = replyChannel
                    data.msg = msg
                    data.dist = dist
                    return
                end
            end
        end,
        function () os.sleep(timeout) end
    )
    return data
end

local function handleNearbyStation()
    while true do
        g.clear(term, colors.white)
        g.drawText(term, 1, 1, "Looking for nearby station", colors.black, colors.yellow)
        g.drawText(term, 1, 2, "Walk near a station to", colors.gray, colors.white)
        g.drawText(term, 1, 3, "see available routes.", colors.gray, colors.white)
        os.sleep(1)

        local event, name, dist = os.pullEvent("rail_station_nearby")
        g.clear(term, colors.white)
        g.drawXLine(term, 1, W, 1, colors.lightBlue)
        g.drawText(term, 1, 1, "Found a station!", colors.black, colors.lightBlue)
        g.drawText(term, 1, 3, name, colors.blue, colors.white)
        g.drawText(term, 1, 5, "Fetching routes...", colors.gray, colors.white)
        os.sleep(1)

        modem.transmit(STATION_REQUEST_CHANNEL, MY_CHANNEL, "GET_ROUTES")
        local response = waitForModemMessage(STATION_REQUEST_CHANNEL, 1)
        if not response or not response.msg or type(response.msg) ~= "table" then
            g.clear(term, colors.white)
            g.drawXLine(term, 1, W, 1, colors.red)
            g.drawText(term, 1, 1, "Error", colors.white, colors.red)
            g.drawText(term, 1, 2, "Failed to get routes.", colors.gray, colors.white)
            if response then
                term.setCursorPos(1, 3)
                term.setTextColor(colors.black)
                term.setBackgroundColor(colors.lightGray)
                print("Response:"..textutils.serialize(response, {compact=true}))
            end
            os.sleep(5)
        else
            local routes = response.msg
            g.clear(term, colors.white)
            g.drawXLine(term, 1, W, 1, colors.blue)
            g.drawText(term, 1, 1, "Routes", colors.white, colors.blue)
            g.drawText(term, W-3, 1, "Quit", colors.white, colors.red)
            for i, route in pairs(routes) do
                local y = i + 1
                local bg = colors.white
                if i % 2 == 0 then bg = colors.lightGray end
                g.drawXLine(term, 1, W, y, bg)
                g.drawText(term, 1, y, i..". "..route.name, colors.black, bg)
            end
            -- Either wait for the user to choose a route, or go away from the
            -- station transponder.
            local routeChosen = false
            parallel.waitForAny(
                function ()
                    while true do
                        local event, button, x, y = os.pullEvent("mouse_click")
                        if button == 1 then
                            if x >= W-3 and y == 1 then
                                break
                            elseif y > 1 and y - 1 <= #routes then
                                local selectedRoute = routes[y-1]
                                os.queueEvent("rail_route_selected", selectedRoute)
                                routeChosen = true
                                return
                            end
                        end
                    end
                end,
                function () waitForNoStation(name) end
            )
            -- Quit our main loop if the user has chosen a route.
            if routeChosen then return end
        end
    end
end

local function waitForRouteSelection()
    while true do
        parallel.waitForAny(
            listenForAnyStation,
            handleNearbyStation
        )
        local event, route = os.pullEvent("rail_route_selected")
        if event and type(route) == "table" then
            return route
        end
    end
end

local args = {...}

if #args > 1 then
    local route = args
    print("Routing via command-line args:")
    for _, branch in pairs(route) do
        print("  "..branch)
    end
    parallel.waitForAny(
        function() broadcastRoute(route) end,
        function() waitForStation(route[#route]) end
    )
    return
end

g.clear(term, colors.white)
g.drawTextCenter(term, W/2, H/2, "Rail Router", colors.black, colors.white)
g.drawTextCenter(term, W/2, H/2 + 2, "By Andrew", colors.gray, colors.white)
os.sleep(1)

while true do
    local route = waitForRouteSelection()
    g.clear(term, colors.white)
    g.drawTextCenter(term, W/2, 2, "Broadcasting route...", colors.black, colors.white)
    g.drawText(term, 1, 4, "  Path:", colors.gray, colors.white)
    for i, segment in pairs(route.path) do
        local y = i + 4
        g.drawText(term, 4, y, segment, colors.gray, colors.white)
    end
    g.drawText(term, W-3, 1, "Quit", colors.white, colors.red)

    parallel.waitForAny(
        function() broadcastRoute(route.path) end,
        function() waitForStation(route.path[#route.path]) end,
        function() -- Listen for user clicks on the "Quit" button.
            while true do
                local event, button, x, y = os.pullEvent("mouse_click")
                if button == 1 and x >= W-3 and y == 1 then
                    return
                end
            end
        end
    )
end
