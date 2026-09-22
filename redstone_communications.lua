local CONFIG_FILE = "redstone_communications.cfg"

local CHANNEL = 48173
local PROTOCOL = "Redstone Communications"
local VERSION = 1

local SIDES = {
    "top",
    "bottom",
    "left",
    "right",
    "front",
    "back"
}

local modem = peripheral.find("modem")

if not modem then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)

    print("REDSTONE COMMUNICATIONS")
    print("")
    print("ERROR")
    print("")
    print("No modem found.")
    print("")
    print("Connect a modem and restart.")

    return
end

local COMPUTER_ID = os.getComputerID()

local config = {
    key = "",
    routes = {
        top = {},
        bottom = {},
        left = {},
        right = {},
        front = {},
        back = {}
    }
}

local workingConfig = nil

local running = true
local configOpen = false

local remoteStates = {}

local localStates = {}

local outputStates = {}

local mainSelection = 1
local configSelection = 1
local outputSelection = 1

local configItems = {
    "KEY",
    "ROUTES",
    "SAVE",
    "RESET",
    "CANCEL"
}

--------------------------------------------------
-- BASIC
--------------------------------------------------

local function copyTable(value)
    local serialized = textutils.serialize(value)
    return textutils.unserialize(serialized)
end

local function sideExists(side)
    for i = 1, #SIDES do
        if SIDES[i] == side then
            return true
        end
    end

    return false
end

local function getSideIndex(side)
    for i = 1, #SIDES do
        if SIDES[i] == side then
            return i
        end
    end

    return 1
end

local function nextSide(side, direction)
    local index = getSideIndex(side)

    index = index + direction

    if index > #SIDES then
        index = 1
    end

    if index < 1 then
        index = #SIDES
    end

    return SIDES[index]
end

local function normalizeConfig()
    if type(config) ~= "table" then
        config = {}
    end

    if type(config.key) ~= "string" then
        config.key = ""
    end

    if type(config.routes) ~= "table" then
        config.routes = {}
    end

    for i = 1, #SIDES do
        local input = SIDES[i]

        if type(config.routes[input]) ~= "table" then
            config.routes[input] = {}
        end

        local clean = {}

        for j = 1, #SIDES do
            local output = SIDES[j]

            if output ~= input
            and config.routes[input][output] == true then
                clean[output] = true
            end
        end

        config.routes[input] = clean
    end
end

--------------------------------------------------
-- SAVE / LOAD
--------------------------------------------------

local function saveConfig()
    normalizeConfig()

    local file = fs.open(CONFIG_FILE, "w")

    if not file then
        return false
    end

    file.write(textutils.serialize({
        version = VERSION,
        key = config.key,
        routes = config.routes
    }))

    file.close()

    return true
end

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then
        normalizeConfig()
        saveConfig()
        return
    end

    local file = fs.open(CONFIG_FILE, "r")

    if not file then
        normalizeConfig()
        return
    end

    local data = file.readAll()
    file.close()

    local ok, result = pcall(textutils.unserialize, data)

    if ok and type(result) == "table" then
        config = result
    end

    normalizeConfig()
end

local function resetConfig()
    config = {
        key = "",
        routes = {
            top = {},
            bottom = {},
            left = {},
            right = {},
            front = {},
            back = {}
        }
    }
end

--------------------------------------------------
-- SCREEN
--------------------------------------------------

local function getScreenSize()
    local w, h = term.getSize()

    if type(w) ~= "number" then
        w = 51
    end

    if type(h) ~= "number" then
        h = 19
    end

    return w, h
end

local function clearScreen()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    term.clear()
    term.setCursorPos(1, 1)
end

local function center(y, text, color)
    local w, h = getScreenSize()

    if y < 1 or y > h then
        return
    end

    text = tostring(text or "")

    if #text > w then
        text = string.sub(text, 1, w)
    end

    local x = math.floor((w - #text) / 2) + 1

    if x < 1 then
        x = 1
    end

    term.setCursorPos(x, y)
    term.setTextColor(color or colors.white)
    term.setBackgroundColor(colors.black)
    term.write(text)
end

local function separator(y)
    local w, h = getScreenSize()

    if y < 1 or y > h then
        return
    end

    local length = math.min(w - 6, 42)

    if length < 1 then
        length = 1
    end

    local x = math.floor((w - length) / 2) + 1

    term.setCursorPos(x, y)
    term.setTextColor(colors.gray)
    term.write(string.rep("-", length))
end

local function menuLine(y, text, selected)
    local w, h = getScreenSize()

    if y < 1 or y > h then
        return
    end

    local width = math.min(42, w - 6)

    if width < 10 then
        width = w - 2
    end

    local x = math.floor((w - width) / 2) + 1

    if selected then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    term.setCursorPos(x, y)
    term.write(string.rep(" ", width))

    local value = text

    if #value > width - 2 then
        value = string.sub(value, 1, width - 2)
    end

    term.setCursorPos(x + 1, y)
    term.write(value)

    term.setBackgroundColor(colors.black)
end

--------------------------------------------------
-- KEY INPUT SCREEN
--------------------------------------------------

local function keyInputScreen()
    clearScreen()

    local w, h = getScreenSize()

    center(3, "COMMUNICATION KEY", colors.white)
    center(4, "ENTER SHARED KEY", colors.gray)

    separator(6)

    local width = math.min(38, w - 6)

    if width < 12 then
        width = w - 2
    end

    local x = math.floor((w - width) / 2) + 1

    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)

    term.setCursorPos(x, 8)
    term.write(string.rep(" ", width))

    local value = workingConfig.key or ""

    if #value > width - 2 then
        value = string.sub(value, 1, width - 2)
    end

    term.setCursorPos(x + 1, 8)
    term.write(value)

    term.setCursorBlink(true)

    while true do
        local event, valueOrKey = os.pullEvent()

        if event == "char" then
            if #value < width - 2 then
                value = value .. valueOrKey

                term.setCursorPos(x + 1, 8)
                term.write(string.rep(" ", width - 2))

                term.setCursorPos(x + 1, 8)
                term.write(value)
            end

        elseif event == "key" then
            if valueOrKey == keys.backspace then
                if #value > 0 then
                    value = string.sub(value, 1, #value - 1)

                    term.setCursorPos(x + 1, 8)
                    term.write(string.rep(" ", width - 2))

                    term.setCursorPos(x + 1, 8)
                    term.write(value)
                end

            elseif valueOrKey == keys.enter then
                workingConfig.key = value

                term.setCursorBlink(false)

                return true

            elseif valueOrKey == keys.escape then
                term.setCursorBlink(false)

                return false
            end
        end
    end
end

--------------------------------------------------
-- OUTPUT SCREEN
--------------------------------------------------

local function drawOutputScreen(inputSide)
    clearScreen()

    center(2, "ROUTE CONFIGURATION", colors.white)
    center(3, "INPUT: " .. string.upper(inputSide), colors.gray)

    separator(5)

    local y = 7

    for i = 1, #SIDES do
        local output = SIDES[i]

        local state = false

        if workingConfig.routes[inputSide] then
            state = workingConfig.routes[inputSide][output] == true
        end

        local text

        if output == inputSide then
            text = string.upper(output) .. "    [INPUT]"
        elseif state then
            text = string.upper(output) .. "    [ON]"
        else
            text = string.upper(output) .. "    [OFF]"
        end

        menuLine(y, text, i == outputSelection)

        y = y + 1
    end

    separator(y + 1)

    center(y + 3, "LEFT / RIGHT  CHANGE", colors.gray)
    center(y + 4, "UP / DOWN  SELECT", colors.gray)
    center(y + 5, "ENTER  RETURN", colors.gray)
    center(y + 6, "ESC  CANCEL", colors.gray)
end

local function outputScreen(inputSide)
    outputSelection = 1

    while true do
        drawOutputScreen(inputSide)

        local event, key = os.pullEvent("key")

        if key == keys.up then
            outputSelection = outputSelection - 1

            if outputSelection < 1 then
                outputSelection = #SIDES
            end

        elseif key == keys.down then
            outputSelection = outputSelection + 1

            if outputSelection > #SIDES then
                outputSelection = 1
            end

        elseif key == keys.left or key == keys.right then
            local output = SIDES[outputSelection]

            if output ~= inputSide then
                if not workingConfig.routes[inputSide] then
                    workingConfig.routes[inputSide] = {}
                end

                if workingConfig.routes[inputSide][output] then
                    workingConfig.routes[inputSide][output] = nil
                else
                    workingConfig.routes[inputSide][output] = true
                end
            end

        elseif key == keys.enter then
            return

        elseif key == keys.escape then
            return
        end
    end
end

--------------------------------------------------
-- ROUTE SCREEN
--------------------------------------------------

local function routeOutputCount(inputSide)
    local count = 0

    if workingConfig.routes[inputSide] then
        for i = 1, #SIDES do
            if workingConfig.routes[inputSide][SIDES[i]] then
                count = count + 1
            end
        end
    end

    return count
end

local function drawRouteScreen()
    clearScreen()

    center(2, "ROUTE CONFIGURATION", colors.white)
    center(3, "SELECT INPUT SOURCE", colors.gray)

    separator(5)

    local y = 7

    for i = 1, #SIDES do
        local input = SIDES[i]
        local count = routeOutputCount(input)

        local text = string.upper(input) .. "    OUTPUTS: " .. tostring(count)

        menuLine(y, text, i == configSelection)

        y = y + 1
    end

    separator(y + 1)

    center(y + 3, "ENTER  CONFIGURE OUTPUTS", colors.gray)
    center(y + 4, "ESC  RETURN", colors.gray)
end

local function routeScreen()
    configSelection = 1

    while true do
        drawRouteScreen()

        local event, key = os.pullEvent("key")

        if key == keys.up then
            configSelection = configSelection - 1

            if configSelection < 1 then
                configSelection = #SIDES
            end

        elseif key == keys.down then
            configSelection = configSelection + 1

            if configSelection > #SIDES then
                configSelection = 1
            end

        elseif key == keys.enter then
            local inputSide = SIDES[configSelection]

            outputScreen(inputSide)

        elseif key == keys.escape then
            return
        end
    end
end

--------------------------------------------------
-- CONFIGURATION SCREEN
--------------------------------------------------

local function drawConfiguration()
    clearScreen()

    center(2, "REDSTONE COMMUNICATIONS", colors.white)
    center(3, "CONFIGURATION", colors.gray)

    separator(5)

    local keyText = workingConfig.key

    if keyText == "" then
        keyText = "NOT SET"
    end

    menuLine(7, "KEY       " .. keyText, configSelection == 1)

    local totalRoutes = 0

    for i = 1, #SIDES do
        if routeOutputCount(SIDES[i]) > 0 then
            totalRoutes = totalRoutes + 1
        end
    end

    menuLine(
        9,
        "ROUTES    " .. tostring(totalRoutes) .. " INPUTS",
        configSelection == 2
    )

    separator(11)

    menuLine(13, "SAVE & EXIT", configSelection == 3)
    menuLine(15, "RESET", configSelection == 4)
    menuLine(17, "CANCEL", configSelection == 5)

    center(19, "UP / DOWN  SELECT", colors.gray)
    center(20, "ENTER  OPEN / CONFIRM", colors.gray)
    center(21, "ESC  CANCEL", colors.gray)
end

local function configurationScreen()
    workingConfig = copyTable(config)

    configSelection = 1

    configOpen = true

    while configOpen do
        drawConfiguration()

        local event, key = os.pullEvent("key")

        if key == keys.up then
            configSelection = configSelection - 1

            if configSelection < 1 then
                configSelection = #configItems
            end

        elseif key == keys.down then
            configSelection = configSelection + 1

            if configSelection > #configItems then
                configSelection = 1
            end

        elseif key == keys.enter then

            if configSelection == 1 then
                keyInputScreen()

            elseif configSelection == 2 then
                routeScreen()

            elseif configSelection == 3 then
                config = copyTable(workingConfig)

                normalizeConfig()
                saveConfig()

                workingConfig = nil
                configOpen = false

            elseif configSelection == 4 then
                resetConfig()

                workingConfig = copyTable(config)

            elseif configSelection == 5 then
                workingConfig = nil
                configOpen = false
            end

        elseif key == keys.escape then
            workingConfig = nil
            configOpen = false
        end
    end
end

--------------------------------------------------
-- COMMUNICATION STATE
--------------------------------------------------

local function ensureRemote(sender)
    if not remoteStates[sender] then
        remoteStates[sender] = {}

        for i = 1, #SIDES do
            remoteStates[sender][SIDES[i]] = false
        end
    end
end

local function setSourceState(sender, inputSide, state)
    if not sideExists(inputSide) then
        return
    end

    if sender == "local" then
        localStates[inputSide] = state
        return
    end

    ensureRemote(sender)

    remoteStates[sender][inputSide] = state
end

local function inputIsActive(inputSide)
    if localStates[inputSide] == true then
        return true
    end

    for sender, states in pairs(remoteStates) do
        if states[inputSide] == true then
            return true
        end
    end

    return false
end

local function calculateOutput(outputSide)
    for i = 1, #SIDES do
        local inputSide = SIDES[i]

        if workingConfig == nil then
            if config.routes[inputSide]
            and config.routes[inputSide][outputSide]
            and inputIsActive(inputSide) then
                return true
            end
        else
            if config.routes[inputSide]
            and config.routes[inputSide][outputSide]
            and inputIsActive(inputSide) then
                return true
            end
        end
    end

    return false
end

local function updateOutputs()
    for i = 1, #SIDES do
        local output = SIDES[i]

        local active = calculateOutput(output)

        outputStates[output] = active

        if active then
            redstone.setAnalogOutput(output, 15)
        else
            redstone.setAnalogOutput(output, 0)
        end
    end
end

--------------------------------------------------
-- TRANSMISSION
--------------------------------------------------

local function transmitInput(inputSide, state)
    if config.key == "" then
        return
    end

    modem.transmit(
        CHANNEL,
        CHANNEL,
        {
            protocol = PROTOCOL,
            version = VERSION,
            key = config.key,
            sender = COMPUTER_ID,
            input = inputSide,
            state = state
        }
    )
end

local function transmitAllLocalStates()
    if config.key == "" then
        return
    end

    for i = 1, #SIDES do
        local inputSide = SIDES[i]
        local state = redstone.getInput(inputSide)

        localStates[inputSide] = state

        transmitInput(inputSide, state)
    end
end

--------------------------------------------------
-- INPUT TASK
--------------------------------------------------

local function inputTask()
    for i = 1, #SIDES do
        local side = SIDES[i]

        localStates[side] = redstone.getInput(side)
    end

    updateOutputs()

    transmitAllLocalStates()

    while running do
        for i = 1, #SIDES do
            local side = SIDES[i]

            local current = redstone.getInput(side)
            local previous = localStates[side]

            if current ~= previous then
                localStates[side] = current

                updateOutputs()

                transmitInput(side, current)
            end
        end

        sleep(0.05)
    end
end

--------------------------------------------------
-- RECEIVE TASK
--------------------------------------------------

local function receiveTask()
    modem.open(CHANNEL)

    while running do
        local event,
              side,
              channel,
              replyChannel,
              message,
              distance = os.pullEvent("modem_message")

        if channel == CHANNEL
        and type(message) == "table"
        and message.protocol == PROTOCOL
        and message.version == VERSION
        and type(message.key) == "string"
        and message.key == config.key
        and type(message.sender) == "number"
        and message.sender ~= COMPUTER_ID
        and type(message.input) == "string"
        and sideExists(message.input)
        and type(message.state) == "boolean" then

            setSourceState(
                tostring(message.sender),
                message.input,
                message.state
            )

            updateOutputs()
        end
    end
end

--------------------------------------------------
-- MAIN SCREEN
--------------------------------------------------

local function getActiveInputText()
    local active = {}

    for i = 1, #SIDES do
        local side = SIDES[i]

        if localStates[side] then
            table.insert(active, string.upper(side))
        end
    end

    if #active == 0 then
        return "NONE"
    end

    return table.concat(active, ", ")
end

local function drawMain()
    clearScreen()

    local w, h = getScreenSize()

    center(2, "REDSTONE COMMUNICATIONS", colors.white)
    center(3, "LEVEL SYSTEM", colors.gray)

    separator(5)

    local keyStatus

    if config.key == "" then
        keyStatus = "NOT SET"
    else
        keyStatus = "CONFIGURED"
    end

    center(7, "COMMUNICATION", colors.gray)
    center(8, keyStatus, colors.white)

    center(10, "COMPUTER ID", colors.gray)
    center(11, tostring(COMPUTER_ID), colors.white)

    center(13, "LOCAL INPUT", colors.gray)
    center(14, getActiveInputText(), colors.white)

    center(16, "ROUTES", colors.gray)

    local routeCount = 0

    for i = 1, #SIDES do
        routeCount = routeCount + routeOutputCount(SIDES[i])
    end

    center(17, tostring(routeCount) .. " CONNECTIONS", colors.white)

    separator(19)

    center(h - 2, "C  CONFIGURATION", colors.white)
    center(h - 1, "Q  EXIT", colors.gray)
end

--------------------------------------------------
-- GUI TASK
--------------------------------------------------

local function guiTask()
    while running do
        if not configOpen then
            drawMain()

            local event, key = os.pullEvent("key")

            if key == keys.c then
                configurationScreen()

                updateOutputs()

            elseif key == keys.q then
                running = false
            end
        end

        sleep(0.05)
    end
end

--------------------------------------------------
-- START
--------------------------------------------------

loadConfig()

for i = 1, #SIDES do
    local side = SIDES[i]

    localStates[side] = false
    outputStates[side] = false

    redstone.setAnalogOutput(side, 0)
end

parallel.waitForAny(
    inputTask,
    receiveTask,
    guiTask
)

running = false

for i = 1, #SIDES do
    redstone.setAnalogOutput(SIDES[i], 0)
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

print("Redstone Communications stopped.")
