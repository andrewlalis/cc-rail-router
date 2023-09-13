--[[
A central server to coordinate a rail network. This central server keeps a
graph of the entire network, and handles requests to find paths to route
traffic through.
]]--

local RECEIVE_CHANNEL = 45453

local modem = peripheral.wrap("top") or error("Missing top modem")
modem.open(RECEIVE_CHANNEL)

local loadGraph()
    local g = nil
    local f = io.open("network_graph.tbl", "r")
    g = textutils.unserialize(f:read("*a"))
    f:close()
    --return g
    return {
        nodes = {
            {
                id = "Junction-HandieVale",
                connections = {
                    {from = "handievale", to = "N1"},
                    {from = "N1", to = "handievale"},
                    {from = "handievale", to = "W1"},
                    {from = "W1", to = "handievale"},
                    {from = "N1", to = "W1"},
                    {from = "W1", to = "N1"}
                }
            },
            {
                id = "Junction-Middlecross",
                connections = {
                    {from = "W1", to = "W2"},
                    {from = "W2", to = "W1"},
                    {from = "N2", to = "S1"},
                    {from = "S1", to = "N2"}
                }
            }
        },
        edges = {
            {
                {id = "handievale", length = 16},
                {id = "N1", length = -1},
                {id = "W1", length = 300},
                {id = "N2", length = 600},
                {id = "E1", length = 75},
                {id = "end", length = 60},
                {id = "W2", length = -1},
                {id = "S1", length = -1}
            }
        }
    }
end

local findNodeById(graph, nodeId)
    for _, node in pairs(graph.nodes) do
        if node.id == nodeId then return node end
    end
    return nil
end

local findEdgeById(graph, edgeId)
    for _, edge in pairs(graph.edges) do
        if edge.id == edgeId then return edge end
    end
    return nil
end

local findNextEdges(graph, edgeId)
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

local findPath(graph, nodeA, nodeB)

end

local handleRequest(graph, replyChannel, msg)
    if msg.command == "ROUTE" then

    end
end

local function handleRequests(graph)
    while true do
        local event, side, channel, replyChannel, msg, dist = os.pullEvent("modem_message")
        if channel == RECEIVE_CHANNEL then
            handleRequest(graph, replyChannel, msg)
        end
    end
end

handleRequests(loadGraph())
