--[[
This program is to be installed on a computer that controls a single rail
junction. As a player with a portable computer approaches, that portable
computer will be sending out a signal indicating their preferred switching
configuration (the branch they're coming from, and the one they want to go to),
and the junction's computer will then send a success reply.
]]

local CONFIG_FILE = "switch_config.tbl"
local CHANNEL = 0
local config = nil
 
local modem = peripheral.wrap("top") or error("Missing modem")
if not modem.isWireless() then error("Wireless modem required") end
modem.open(CHANNEL)
 
term.clear()
term.setCursorPos(1, 1)
print("Receiving routing commands on channel 0")

-- Series of guided inputs for building a configuration file from user input.
local function configSetupWizard()
    local cfg = {range = 32, switches = {}}
    term.clear()
    term.setCursorPos(1, 1)
    print("Switch Controller Config Setup Wizard")
    print("-------------------------------------")
    print("What range (blocks) does this switch have? Defaults to 32.")
    local rangeStr = io.read()
    if rangeStr then
        local rangeInt = tonumber(rangeStr)
        if rangeInt == nil or rangeInt < 1 or rangeInt > 128 then
            print("Invalid range value. Should be a positive integer number. Got "..rangeStr)
            return nil
        end
    end
    print("How many switch configurations are there? Usually 1 for each possible path of travel.")
    local switchCountStr = io.read()
    if not switchCountStr then
        print("Invalid switch configuration count.")
        return nil
    end
    local switchCount = tonumber(switchCountStr)
    if switchCount == nil or switchCount < 2 or switchCount > 32 then
        print("Invalid switch configuration count. Expected a positive integer between 2 and 32.")
        return nil
    end
    for i = 1, switchCount do
        local sw = {from = nil, to = nil, controls = {}}
        print("Switch Configuration #"..i..":")
        print("What is name of the branch traffic comes from?")
        sw.from = io.read()
        print("What is the name of the branch traffic goes to?")
        sw.to = io.read()
        print("How many control points are needed for this switch configuration?")
        local controlCountStr = io.read()
        local controlCount = 0
        if controlCountStr then controlCount = tonumber(controlCountStr) end
        if not controlCount or controlCount < 1 then
            print("Invalid control point count. Expected a positive integer.")
            return nil
        end
        for c = 1, controlCount do
            local ctl = {type = "redstone", side = "top", state = true}
            print("  Control Point #"..c..":")
            print("  What type of control is this?")
            print("  1. redstone")
            print("  2. redstoneIntegrator")
            local typeStr = io.read()
            if not typeStr or typeStr == "1" or typeStr == "redstone" then
                ctl.type = "redstone"
                print("  What side is redstone output on?")
                ctl.side = io.read()
                print("  What state should the output be? [T/F]")
                local stateStr = io.read()
                ctl.state = stateStr == "T" or stateStr == "True" or stateStr == "t" or stateStr == "true"
            elseif typeStr == "2" or typeStr == "redstoneIntegrator" then
                ctl.type = "redstoneIntegrator"
                print("  What is the peripheral name?")
                ctl.name = io.read()
                print("  What side is output on?")
                ctl.side = io.read()
                print("  What state should the output be? [T/F]")
                local stateStr = io.read()
                ctl.state = stateStr == "T" or stateStr == "True" or stateStr == "t" or stateStr == "true"
            else
                print("  Unsupported control type.")
                return nil
            end
            table.insert(sw.controls, ctl)
        end
        table.insert(config.switches, sw)
    end
    local f = io.open(CONFIG_FILE, "w")
    f:write(textutils.serialize(cfg))
    f:close()
    return cfg
end

local function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local f = io.open(CONFIG_FILE, "r")
        local cfg = textutils.unserialize(f:read("*a"))
        f:close()
        print("Loaded configuration from file:")
        print("  "..tostring(#config.switches).." switch configurations.")
        print("  "..tostring(config.range).." block range.")
        return cfg
    else
        print("File "..CONFIG_FILE.." doesn't exist. Start setup wizard? [y/n]")
        local response = io.read()
        if response == "y" or response == "Y" or response == "yes" then
            return configSetupWizard()
        else
            return nil
        end
    end
end

local function findSwitchConfiguration(cfg, from, to)
    if from == nil or to == nil then return nil end
    for _, sw in pairs(cfg.switches) do
        if sw.from == from and sw.to == to then return sw end
    end
    return nil
end

local function isSwitchConfigurationActive(sw)
    for _, control in pairs(sw.controls) do
        if control.type == "redstone" then
            local state = redstone.getOutput(control.side)
            if state ~= control.state then return false end
        elseif control.type == "redstoneIntegrator" then
            local state = peripheral.call(control.name, "getOutput", control.side)
            if state ~= control.state then return false end
        else
            error("Invalid control type: "..control.type)
        end
    end
    return true
end

local function activateSwitchConfiguration(sw)
    print("Activating switch: FROM="..sw.from..", TO="..sw.to)
    for _, control in pairs(sw.controls) do
        if control.type == "redstone" then
            redstone.setOutput(control.side, control.state)
        elseif control.type == "redstoneIntegrator" then
            peripheral.call(control.name, "setOutput", control.side, control.state)
        else
            error("Invalid control type: "..control.type)
        end
    end
end
 
-- Handles incoming rail messages that consist of a list of branch names
-- that the user would like to traverse.
local function handleModemMsg(replyChannel, msg)
    -- Ignore invalid messages.
    if not msg or #msg < 2 then return end
    -- Find the switch configuration(s) that pertain to this route.
    for i = 1, #msg - 1 do
        local sw = findSwitchConfiguration(config, msg[i], msg[i+1])
        if sw and not isSwitchConfigurationActive(sw) then
            activateSwitchConfiguration(sw)
        end
    end
end

config = loadConfig()
if not config then
    print("Unable to load configuration. Exiting.")
    return
end

while true do
    local event, p1, p2, p3, p4, p5 = os.pullEvent()
    if event == "modem_message" then
        local channel = p2
        local replyChannel = p3
        local msg = p4
        local dist = p5
        if channel == CHANNEL and dist ~= nil and dist < config.range and msg ~= nil then
            handleModemMsg(replyChannel, msg)
        end
    end
end