--[[
A central server to coordinate a rail network. This central server keeps a
graph of the entire network, and handles requests to find paths to route
traffic through.
]]--

local RECEIVE_CHANNEL = 45452

-- ONLY FOR DEBUGGING
-- inspect = require("inspect")
local modem = peripheral.wrap("top") or error("Missing top modem")
modem.open(RECEIVE_CHANNEL)

local function generateStandardNode(id, edgeIds)
    local node = {id = id, connections = {}, type = "JUNCTION"}
    for _, edgeId in pairs(edgeIds) do
        for _, edgeId2 in pairs(edgeIds) do
            if edgeId2 ~= edgeId then
                table.insert(node.connections, {from = edgeId, to = edgeId2})
            end
        end
    end
    return node
end

local function generateStationNode(id, displayName, edgeId)
    return {
        id = id,
        displayName = displayName,
        connections = {
            {from = nil, to = edgeId},
            {from = edgeId, to = nil}
        },
        type = "STATION"
    }
end

local function loadGraph()
    -- local g = nil
    -- local f = io.open("network_graph.tbl", "r")
    -- g = textutils.unserialize(f:read("*a"))
    -- f:close()
    --return g
    local tempGraph = {
        nodes = {
            generateStandardNode("Junction-HandieVale", {"handievale", "N1", "W1"}),
            generateStandardNode("Junction-Middlecross", {"W1", "N2", "W2", "S1"}),
            generateStandardNode("Junction-Foundry", {"E1", "N3", "W3", "N2"}),
            generateStandardNode("Junction-End", {"E1", "E2", "end"}),
            generateStandardNode("Junction-Klausville", {"N3", "N4", "klausville"}),
            generateStandardNode("Junction-Foundry-West", {"W3", "foundry", "W4"}),
            generateStationNode("station-klausville", "Klausville", "klausville"),
            generateStationNode("station-handievale", "HandieVale", "handievale"),
            generateStationNode("station-end", "End & Biofuel Refinery", "end"),
            generateStationNode("station-foundry", "Jack's Foundry", "foundry")
        },
        edges = {
            {id = "handievale", length = 16},
            {id = "end", length = 48},
            {id = "foundry", length = 45},
            {id = "klausville", length = 12},
            {id = "N1", length = nil},
            {id = "W1", length = 300},
            {id = "N2", length = 600},
            {id = "E1", length = 75},
            {id = "W2", length = nil},
            {id = "S1", length = nil},
            {id = "W3", length = 50},
            {id = "W4", length = nil},
            {id = "N3", length = 350},
            {id = "N4", length = nil}
        }
    }
    return tempGraph
end

local function filterTable(arr, func)
    local new_index = 1
    local size_orig = #arr
    for old_index, v in ipairs(arr) do
        if func(v, old_index) then
            arr[new_index] = v
            new_index = new_index + 1
        end
    end
    for i = new_index, size_orig do arr[i] = nil end
end

local function findNodeById(graph, nodeId)
    for _, node in pairs(graph.nodes) do
        if node.id == nodeId then return node end
    end
    return nil
end

local function findEdgeById(graph, edgeId)
    for _, edge in pairs(graph.edges) do
        if edge.id == edgeId then return edge end
    end
    return nil
end

local function findEdgeBetweenNodes(graph, fromNode, toNode)
    local edgeIdsFrom = {}
    for _, conn in pairs(fromNode.connections) do
        if conn.to and not tableContains(edgeIdsFrom, conn.to) then
            table.insert(edgeIdsFrom, conn.to)
        end
    end
    local edgeIds = {}
    for _, conn in pairs(toNode.connections) do
        if conn.from and tableContains(edgeIdsFrom, conn.from) and not tableContains(edgeIds, conn.from) then
            table.insert(edgeIds, conn.from)
        end
    end

end

local function tableContains(table, value)
    for _, item in pairs(table) do
        if item == value then return true end
    end
    return false
end

local function removeElement(table, value)
    local idx = nil
    for i, item in pairs(table) do
        if item == value then idx = i break end
    end
    if idx then table.remove(table, idx) end
end

local function findNextEdges(graph, edgeId)
    local edges = {}
    for _, node in pairs(graph.nodes) do
        for _, connection in pairs(node.connections) do
            if connection.from == edgeId then
                table.insert(edges, findEdgeById(connection.to))
            end
        end
    end
    return edges
end

-- Find the set of nodes directly connected to this one via some edges
local function findConnectedNodes(graph, startNode)
    local edges = {}
    local edgeIds = {}
    for _, conn in pairs(startNode.connections) do
        if conn.to ~= nil then
            local edge = findEdgeById(graph, conn.to)
            if edge ~= nil and edge.length ~= nil and not tableContains(edgeIds, edge.id) then
                table.insert(edges, edge)
                table.insert(edgeIds, edge.id)
            end
        end
    end
    local connections = {}
    for _, edge in pairs(edges) do
        for _, node in pairs(graph.nodes) do
            if node.id ~= startNode.id then
                for _, conn in pairs(node.connections) do
                    if conn.from == edge.id then
                        table.insert(connections, {node = node, distance = edge.length, via = edge.id})
                        break
                    end
                end
            end
        end
    end
    return connections
end

local function findPath(graph, startNode, endNode)
    local INFINITY = 1000000000
    local dist = {}
    local prev = {}
    local queue = {}
    for _, node in pairs(graph.nodes) do
        dist[node.id] = INFINITY
        prev[node.id] = nil
        table.insert(queue, node)
    end
    dist[startNode.id] = 0

    while #queue > 0 do
        local minIdx = nil
        local minDist = INFINITY + 1
        for i, node in pairs(queue) do
            if dist[node.id] < minDist then
                minIdx = i
                minDist = dist[node.id]
            end
        end
        if minIdx == nil then return nil end
        local u = table.remove(queue, minIdx)
        if u.id == endNode.id and (prev[u.id] or u.id == startNode.id) then
            local s = {}
            while u ~= nil do
                local via = nil
                local distance = nil
                local node = u
                u = nil
                if prev[node.id] then
                    via = prev[node.id].via
                    distance = prev[node.id].distance
                    u = prev[node.id].node
                end
                table.insert(s, 1, {node = node, via = via, distance = distance})
            end
            return s
        end
        for _, neighbor in pairs(findConnectedNodes(graph, u)) do
            local unvisited = false
            for _, node in pairs(queue) do
                if node.id == neighbor.node.id then
                    unvisited = true
                    break
                end
            end
            if unvisited then
                local alt = dist[u.id] + neighbor.distance
                if alt < dist[neighbor.node.id] then
                    dist[neighbor.node.id] = alt
                    prev[neighbor.node.id] = {node = u, via = neighbor.via, distance = neighbor.distance}
                end
            end
        end
    end
    return nil
end

local function getReachableStations(graph, startNode)
    local queue = findConnectedNodes(graph, startNode)
    local stations = {}
    local visitedNodeIds = {startNode.id}
    while #queue > 0 do
        local node = table.remove(queue, 1).node
        if node.type == "STATION" and not tableContains(visitedNodeIds, node.id) then
            table.insert(stations, node)
        end
        table.insert(visitedNodeIds, node.id)
        for _, conn in pairs(findConnectedNodes(graph, node)) do
            if not tableContains(visitedNodeIds, conn.node.id) then
                table.insert(queue, conn)
            end
        end
    end
    return stations
end

local function handleRouteRequest(graph, replyChannel, msg)
    if not msg.startNode or not msg.endNode then
        modem.transmit(replyChannel, RECEIVE_CHANNEL, {success = false, error = "Invalid request"})
        return
    end
    local startNode = findNodeById(graph, msg.startNode)
    local endNode = findNodeById(graph, msg.endNode)
    if not startNode or not endNode then
        modem.transmit(replyChannel, RECEIVE_CHANNEL, {success = false, error = "Unknown node(s)"})
        return
    end
    local path = findPath(graph, startNode, endNode)
    if not path then
        modem.transmit(replyChannel, RECEIVE_CHANNEL, {success = false, error = "No valid path"})
        return
    end
    modem.transmit(replyChannel, RECEIVE_CHANNEL, {success = true, route = path})
end

local function handleGetRoutesRequest(graph, replyChannel, msg)
    if not msg.startNode then
        modem.transmit(replyChannel, RECEIVE_CHANNEL, {success = false, error = "Invalid request"})
        return
    end
    local startNode = findNodeById(graph, msg.startNode)
    if not startNode then
        modem.transmit(replyChannel, RECEIVE_CHANNEL, {success = false, error = "Unknown node"})
        return
    end
    local stations = getReachableStations(graph, startNode)
    modem.transmit(replyChannel, RECEIVE_CHANNEL, {success = true, stations = stations})
end

local function handleRequests(graph)
    while true do
        local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
        if channel == RECEIVE_CHANNEL and msg and msg.command and type(msg.command) == "string" then
            if msg.command == "ROUTE" then
                handleRouteRequest(graph, replyChannel, msg)
            elseif msg.command == "GET_ROUTES" then
                handleGetRoutesRequest(graph, replyChannel, msg)
            else
                modem.transmit(replyChannel, RECEIVE_CHANNEL, {success = false, error = "Invalid command"})
            end
        end
    end
end

handleRequests(loadGraph())

-- local graph = loadGraph()
-- print("GRAPH:")
-- print(inspect(graph))
-- local startNode = findNodeById(graph, "station-handievale")
-- print(inspect(getReachableStations(graph, startNode)))
-- local endNode = findNodeById(graph, "station-foundry")
-- print("\n\nPATH:")
-- local path = findPath(graph, startNode, endNode)
-- if path then
--     print("Found path!")
--     for i, element in pairs(path) do
--         print(i..". "..element.node.id.." via edge "..inspect(element.via).." @ "..inspect(element.distance))
--     end
-- end
