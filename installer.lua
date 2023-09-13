--[[
A general-purpose installation script that can be run on any cc-rail-router
hardware to set it up for its purpose.
]]--

local function clearScreen()
    if term.isColor() then
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
    end
    term.clear()
    term.setCursorPos(1, 1)
end

local function promptAnyKey()
    print("Press any key to continue.")
    os.pullEvent("key")
end

local function readString(prompt, allowEmpty)
    if allowEmpty == nil then allowEmpty = true end
    local txt = nil
    repeat
        clearScreen()
        print(prompt)
        local x, y = term.getCursorPos()
        term.setCursorPos(1, y + 2)
        term.setCursorBlink(true)
        txt = io.read()
        term.setCursorBlink(false)
        if not allowEmpty and (not txt or #txt == 0) then
            term.setCursorPos(1, y + 4)
            print("Empty input not allowed.")
            os.sleep(2)
        end
    until (txt ~= nil and #txt > 0) or allowEmpty
    return txt
end

local function readNumber(prompt, minVal, maxVal, defaultVal)
    local num = nil
    while num == nil or num < minVal or num > maxVal do
        local txt = readString(prompt, defaultVal ~= nil)
        if not txt or #txt == 0 then return defaultVal end
        num = tonumber(txt)
        if num == nil or num < minVal or num > maxVal then
            print("Invalid number input. Should be between "..minVal.." and "..maxVal..".")
            os.sleep(2)
        end
    end
    return num
end

local function readChoice(prompt, choices, defaultChoice)
    while true do
        clearScreen()
        print(prompt)
        for i, choice in pairs(choices) do
            print(i..". "..choice)
        end
        local x, y = term.getCursorPos()
        term.setCursorPos(1, y + 2)
        local txt = io.read()
        if (not txt or #txt == 0) and defaultChoice ~= nil then
            return defaultChoice
        end
        local txtNum = tonumber(txt)
        if txtNum then
            if txtNum < 1 or txtNum > #choices then
                print("Invalid numeric choice. Should be between 1 and "..#choices..".")
                os.sleep(2)
            else
                return choices[txtNum]
            end
        else
            for i, choice in pairs(choices) do
                if choice == txt then
                    return choice
                end
            end
            print("Invalid choice. Please choose one of the options.")
            os.sleep(2)
        end
    end
end

local function waitForPeripheralAttach(side)
    while true do
        local event, s = os.pullEvent("peripheral")
        if side == nil or s == side then return s end
    end
end

local function waitForPeripheralDetach(side)
    while true do
        local event, s = os.pullEvent("peripheral_detach")
        if side == nil or s == side then return s end
    end
end

local function waitForModemPresent(side, wireless)
    while true do
        local modem = peripheral.wrap(side)
        if modem == nil then
            print("Please attach modem to side "..side..".")
            promptAnyKey()
        elseif not modem.isWireless or modem.isWireless() ~= wireless then
            local name = "modem"
            if wireless then name = "wireless " .. name end
            print("The peripheral on side "..side.." is not a compatible "..name..". Please detach this peripheral and add the correct one now.")
            promptAnyKey()
        end
    end
end

local function saveTable(filename, table)
    local f = io.open(filename, "w")
    f:write(textutils.serialize(table))
    f:close()
end

local function createStartupScript(program)
    local sf = io.open("startup.lua", "w")
    sf:write("shell.execute(\""..program.."\")\n")
    sf:close()
end

local function installStation()
    clearScreen()
    print("Installing station beacon software.")
    os.sleep(1)
    waitForModemPresent("top", true)
    local config = {}
    config.name = readString("Enter the station's codename.", false)
    config.displayName = readString("Enter the station's display name.", false)
    config.range = readNumber("Enter the broadcast range for this station, in blocks.", 4, 64)
    clearScreen()
    saveTable("station_config.tbl", config)
    print("Saved station configuration to station_config.tbl.")
    if fs.exists("station.lua") then
        print("Deleting existing station.lua.")
        fs.delete("station.lua")
    end
    shell.execute("wget", "https://github.com/andrewlalis/cc-rail-router/raw/main/station.lua", "station.lua")
    print("Downloaded station.lua.")
    createStartupScript("station.lua")
end

local function installSwitch()
    clearScreen()
    print("Installing switch controller software.")
    os.sleep(1)
    waitForModemPresent("top", true)

end

local function installRouter()
    clearScreen()
    print("Installing handheld router software.")
    os.sleep(1)
    waitForModemPresent("back", true)

end

clearScreen()
print("Rail Software Installation Wizard")
os.sleep(2)
local choice = readChoice(
    "What type of software would you like to install?",
    {"Station Beacon", "Switch Controller", "Handheld Router", "Exit"}
)
if choice == "Station Beacon" then
    installStation()
elseif choice == "Switch Controller" then
    installSwitch()
elseif choice == "Handheld Router" then
    installRouter()
else
    print("Exiting.")
end
