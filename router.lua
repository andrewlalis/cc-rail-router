--[[
This program should be installed on a portable computer with a wireless
modem, to act as a routing beacon in conjunction with managed switches.
It also serves as the GUI that users of the system interact with.
]]--
local SWITCH_CHANNEL = 45450
local STATION_BROADCAST_CHANNEL = 45451
local SERVER_CHANNEL = 45452
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

local function isValidStationInfo(msg)
    return msg ~= nil and
        msg.name ~= nil and type(msg.name) == "string" and
        msg.range ~= nil and type(msg.range) == "number" and
        msg.displayName ~= nil and type(msg.displayName) == "string"
end

-- Repeats until we are within range of a station that's sending out its info.
local function waitForStation(stationName)
    while true do
        local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
        if type(channel) == "number" and channel == STATION_BROADCAST_CHANNEL and isValidStationInfo(msg) and msg.name == stationName and msg.range >= dist then
            return
        end
    end
end

local function listenForAnyStation()
    while true do
        local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
        if type(channel) == "number" and channel == STATION_BROADCAST_CHANNEL and isValidStationInfo(msg) and msg.range >= dist then
            os.queueEvent("rail_station_nearby", msg, dist)
        end
    end
end

local function waitForNoStation(targetName)
    local lastPing = os.epoch()
    while os.epoch() - lastPing < 5000 do
        parallel.waitForAny(
            function ()
                local event, data, dist = os.pullEvent("rail_station_nearby")
                if not targetName or targetName == data.name then
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
                if type(replyChannel) == "number" and replyChannel == expectedReplyChannel then
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

local function drawLookingForStationScreen()
    g.clear(term, colors.white)
    g.drawText(term, 1, 1, "Looking for nearby station", colors.black, colors.yellow)
    g.drawText(term, 1, 2, "Walk near a station to", colors.gray, colors.white)
    g.drawText(term, 1, 3, "see available routes.", colors.gray, colors.white)
end

local function drawStationFoundScreen(stationName)
    g.clear(term, colors.white)
    g.drawXLine(term, 1, W, 1, colors.lightBlue)
    g.drawText(term, 1, 1, "Found a station!", colors.black, colors.lightBlue)
    g.drawText(term, 1, 3, stationName, colors.blue, colors.white)
    g.drawText(term, 1, 5, "Fetching routes...", colors.gray, colors.white)
end

local function drawDestinationsChoiceScreen(choices)
    g.clear(term, colors.white)
    g.drawXLine(term, 1, W, 1, colors.blue)
    g.drawText(term, 1, 1, "Destinations", colors.white, colors.blue)
    g.drawText(term, W-3, 1, "Quit", colors.white, colors.red)
    for i, choice in pairs(choices) do
        local y = i + 1
        local bg = colors.white
        if i % 2 == 0 then bg = colors.lightGray end
        g.drawXLine(term, 1, W, y, bg)
        g.drawText(term, 1, y, i..". "..choice, colors.black, bg)
    end
end

local function drawErrorPage(errorMsg)
    g.clear(term, colors.white)
    g.drawXLine(term, 1, W, 1, colors.red)
    g.drawText(term, 1, 1, "Error", colors.white, colors.red)
    term.setCursorPos(1, 2)
    term.setTextColor(colors.black)
    term.setBackgroundColor(colors.white)
    print(errorMsg)
    local x, y = term.getCursorPos()
    term.setCursorPos(1, y + 1)
    print("Click to dismiss")
    parallel.waitForAny(
        function () os.sleep(5) end,
        function () os.pullEvent("mouse_click") end
    )
end

local function handleNearbyStation()
    while true do
        drawLookingForStationScreen()
        local event, stationData, dist = os.pullEvent("rail_station_nearby")
        drawStationFoundScreen(stationData.displayName)
        os.sleep(0.5)

        modem.transmit(SERVER_CHANNEL, MY_CHANNEL, {command = "GET_ROUTES", startNode = stationData.name})
        local response = waitForModemMessage(SERVER_CHANNEL, 3)
        if response and response.msg.success then
            local stations = response.msg.stations
            local stationNames = {}
            local stationIds = {}
            for _, station in pairs(stations) do
                table.insert(stationNames, station.displayName)
                table.insert(stationIds, station.id)
            end
            drawDestinationsChoiceScreen(stationNames)
            local destination = nil
            -- Wait for user to choose destination, quit, or go away from station.
            parallel.waitForAny(
                function ()
                    while true do
                        local event, button, x, y = os.pullEvent("mouse_click")
                        if button == 1 then
                            if x >= W-3 and y == 1 then
                                return
                            elseif y > 1 and y - 1 <= #stationIds then
                                destination = stationIds[y-1]
                                return
                            end
                        end
                    end
                end,
                function () waitForNoStation(stationData.name) end
            )
            if destination ~= nil then
                -- Fetch the whole route.
                modem.transmit(SERVER_CHANNEL, MY_CHANNEL, {command = "ROUTE", startNode = stationData.name, endNode = destination})
                local routeResponse = waitForModemMessage(SERVER_CHANNEL, 3)
                if routeResponse and routeResponse.msg.success then
                    local routeEdgeIds = {}
                    for _, segment in pairs(routeResponse.msg.route) do
                        if segment.via then
                            table.insert(routeEdgeIds, segment.via)
                        end
                    end
                    os.queueEvent("rail_route_selected", {path = routeEdgeIds, destination = destination})
                    return
                elseif routeResponse and routeResponse.msg.error then
                    drawErrorPage("Failed to get route: "..routeResponse.msg.error)
                else
                    drawErrorPage("Failed to get route. Please contact an administrator if the issue persists.")
                end
            end
        elseif response and response.msg.error then
            drawErrorPage(response.msg.error)
        else
            drawErrorPage("Could not get a list of stations. Please contact an administrator if the issue persists.\n"..textutils.serialize(response, {compact=true}))
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
        if event and route then
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
    broadcastRoute(route)
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
        function() waitForStation(route.destination) end,
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
