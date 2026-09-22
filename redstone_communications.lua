local CONFIG_FILE = "redstone_communications.cfg"

local CHANNEL = 48173
local PROTOCOL = "Redstone Communications"
local VERSION = 2

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

local localStates = {}
local remoteStates = {}
local outputStates = {}

local configSelection = 1
local routeSelection = 1
local outputSelection = 1

--------------------------------------------------
-- UTILITY
--------------------------------------------------

local function copyTable(value)
    local serialized = textutils.serialize(value)
    return textutils.unserialize(serialized)
end

local function isValidSide(side)
    for i = 1, #SIDES do
        if SIDES[i] == side then
            return true
        end
    end

    return false
end

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

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local function createEmptyRoutes()
    return {
        top = {},
        bottom = {},
        left = {},
        right = {},
        front = {},
        back = {}
    }
end

local function normalizeConfig(target)
    if type(target) ~= "table" then
        return
    end

    if type(target.key) ~= "string" then
        target.key = ""
    end

    if type(target.routes) ~= "table" then
        target.routes = createEmptyRoutes()
    end

    for i = 1, #SIDES do
        local inputSide = SIDES[i]

        if type(target.routes[inputSide]) ~= "table" then
            target.routes[inputSide] = {}
        end

        local clean = {}

        for j = 1, #SIDES do
            local outputSide = SIDES[j]

            if target.routes[inputSide][outputSide] == true then
                clean[outputSide] = true
            end
        end

        target.routes[inputSide] = clean
    end
end

local function saveConfig()
    normalizeConfig(config)

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
        normalizeConfig(config)
        saveConfig()
        return
    end

    local file = fs.open(CONFIG_FILE, "r")

    if not file then
        normalizeConfig(config)
        saveConfig()
        return
    end

    local data = file.readAll()
    file.close()

    local ok, result = pcall(
        textutils.unserialize,
        data
    )

    if not ok or type(result) ~= "table" then
        config = {
            key = "",
            routes = createEmptyRoutes()
        }

        saveConfig()
        return
    end

    if type(result.key) == "string" then
        config.key = result.key
    else
        config.key = ""
    end

    if type(result.routes) == "table" then
        config.routes = result.routes
    else
        config.routes = createEmptyRoutes()
    end

    normalizeConfig(config)
    saveConfig()
end

local function resetConfig()
    config = {
        key = "",
        routes = createEmptyRoutes()
    }
end

--------------------------------------------------
-- SCREEN
--------------------------------------------------

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
    term.setBackgroundColor(colors.black)
    term.setTextColor(color or colors.white)
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
    term.setBackgroundColor(colors.black)
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

    if width < 1 then
        return
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

    local value = tostring(text or "")

    if #value > width - 2 then
        value = string.sub(value, 1, width - 2)
    end

    term.setCursorPos(x + 1, y)
    term.write(value)

    term.setBackgroundColor(colors.black)
end

--------------------------------------------------
-- ROUTE COUNT
--------------------------------------------------

local function getRouteCount(target, inputSide)
    if type(target) ~= "table" then
        return 0
    end

    if type(target.routes) ~= "table" then
        return 0
    end

    local routes = target.routes[inputSide]

    if type(routes) ~= "table" then
        return 0
    end

    local count = 0

    for i = 1, #SIDES do
        local outputSide = SIDES[i]

        if routes[outputSide] == true then
            count = count + 1
        end
    end

    return count
end

local function getTotalRoutes(target)
    if type(target) ~= "table" then
        return 0
    end

    local count = 0

    for i = 1, #SIDES do
        count = count + getRouteCount(
            target,
            SIDES[i]
        )
    end

    return count
end

--------------------------------------------------
-- KEY INPUT
--------------------------------------------------

local function keyInputScreen()
    clearScreen()

    local w = getScreenSize()

    center(
        3,
        "COMMUNICATION KEY",
        colors.white
    )

    center(
        4,
        "ENTER SHARED KEY",
        colors.gray
    )

    separator(6)

    local width = math.min(38, w - 6)

    if width < 12 then
        width = w - 2
    end

    local x = math.floor((w - width) / 2) + 1

    local value = workingConfig.key or ""

    if #value > width - 2 then
        value = string.sub(
            value,
            1,
            width - 2
        )
    end

    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)

    term.setCursorPos(x, 8)
    term.write(string.rep(" ", width))

    term.setCursorPos(x + 1, 8)
    term.write(value)

    term.setCursorBlink(true)

    while true do
        local event, input = os.pullEvent()

        if event == "char" then

            if #value < width - 2 then
                value = value .. input

                term.setCursorPos(
                    x + 1,
                    8
                )

                term.write(
                    string.rep(
                        " ",
                        width - 2
                    )
                )

                term.setCursorPos(
                    x + 1,
                    8
                )

                term.write(value)
            end

        elseif event == "key" then

            if input == keys.backspace then

                if #value > 0 then
                    value = string.sub(
                        value,
                        1,
                        #value - 1
                    )

                    term.setCursorPos(
                        x + 1,
                        8
                    )

                    term.write(
                        string.rep(
                            " ",
                            width - 2
                        )
                    )

                    term.setCursorPos(
                        x + 1,
                        8
                    )

                    term.write(value)
                end

            elseif input == keys.enter then

                workingConfig.key = value
                term.setCursorBlink(false)

                return

            elseif input == keys.escape then

                term.setCursorBlink(false)

                return
            end
        end
    end
end

--------------------------------------------------
-- OUTPUT ROUTE SCREEN
--------------------------------------------------

local function drawOutputScreen(inputSide)
    clearScreen()

    center(
        2,
        "ROUTE SETTING",
        colors.white
    )

    center(
        3,
        "INPUT: " .. string.upper(inputSide),
        colors.gray
    )

    separator(5)

    local y = 7

    for i = 1, #SIDES do
        local outputSide = SIDES[i]

        local enabled = false

        if type(
            workingConfig.routes[inputSide]
        ) == "table" then

            enabled =
                workingConfig
                .routes[inputSide]
                [outputSide] == true
        end

        local text

        if enabled then
            text =
                string.upper(outputSide)
                .. "    [ON]"
        else
            text =
                string.upper(outputSide)
                .. "    [OFF]"
        end

        menuLine(
            y,
            text,
            i == outputSelection
        )

        y = y + 1
    end

    separator(y + 1)

    center(
        y + 3,
        "ENTER  ASSIGN / REMOVE",
        colors.white
    )

    center(
        y + 4,
        "UP / DOWN  SELECT",
        colors.gray
    )

    center(
        y + 5,
        "BACKSPACE / ESC  RETURN",
        colors.gray
    )
end

local function outputScreen(inputSide)
    outputSelection = 1

    while true do

        drawOutputScreen(inputSide)

        local event, key =
            os.pullEvent("key")

        if key == keys.up then

            outputSelection =
                outputSelection - 1

            if outputSelection < 1 then
                outputSelection = #SIDES
            end

        elseif key == keys.down then

            outputSelection =
                outputSelection + 1

            if outputSelection > #SIDES then
                outputSelection = 1
            end

        elseif key == keys.enter then

            local outputSide =
                SIDES[outputSelection]

            if type(
                workingConfig.routes[inputSide]
            ) ~= "table" then

                workingConfig.routes[inputSide] = {}
            end

            local current =
                workingConfig
                .routes[inputSide]
                [outputSide] == true

            workingConfig
                .routes[inputSide]
                [outputSide] =
                not current

        elseif key == keys.backspace
        or key == keys.escape then

            return
        end
    end
end

--------------------------------------------------
-- ROUTE INPUT SCREEN
--------------------------------------------------

local function drawRouteScreen()
    clearScreen()

    center(
        2,
        "ROUTE SETTING",
        colors.white
    )

    center(
        3,
        "SELECT INPUT",
        colors.gray
    )

    separator(5)

    local y = 7

    for i = 1, #SIDES do

        local inputSide = SIDES[i]

        local count =
            getRouteCount(
                workingConfig,
                inputSide
            )

        local text =
            string.upper(inputSide)
            .. "    OUTPUTS: "
            .. tostring(count)

        menuLine(
            y,
            text,
            i == routeSelection
        )

        y = y + 1
    end

    separator(y + 1)

    center(
        y + 3,
        "ENTER  OPEN OUTPUTS",
        colors.white
    )

    center(
        y + 4,
        "UP / DOWN  SELECT",
        colors.gray
    )

    center(
        y + 5,
        "BACKSPACE / ESC  RETURN",
        colors.gray
    )
end

local function routeScreen()
    routeSelection = 1

    while true do

        drawRouteScreen()

        local event, key =
            os.pullEvent("key")

        if key == keys.up then

            routeSelection =
                routeSelection - 1

            if routeSelection < 1 then
                routeSelection = #SIDES
            end

        elseif key == keys.down then

            routeSelection =
                routeSelection + 1

            if routeSelection > #SIDES then
                routeSelection = 1
            end

        elseif key == keys.enter then

            local inputSide =
                SIDES[routeSelection]

            outputScreen(inputSide)

        elseif key == keys.backspace
        or key == keys.escape then

            return
        end
    end
end

--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------

local function drawConfiguration()
    clearScreen()

    center(
        2,
        "REDSTONE COMMUNICATIONS",
        colors.white
    )

    center(
        3,
        "CONFIGURATION",
        colors.gray
    )

    separator(5)

    local keyText =
        workingConfig.key

    if keyText == "" then
        keyText = "NOT SET"
    end

    menuLine(
        7,
        "KEY       " .. keyText,
        configSelection == 1
    )

    local routeCount =
        getTotalRoutes(
            workingConfig
        )

    menuLine(
        9,
        "ROUTES    "
        .. tostring(routeCount)
        .. " CONNECTIONS",
        configSelection == 2
    )

    separator(11)

    menuLine(
        13,
        "SAVE & EXIT",
        configSelection == 3
    )

    menuLine(
        15,
        "RESET",
        configSelection == 4
    )

    menuLine(
        17,
        "CANCEL",
        configSelection == 5
    )

    center(
        19,
        "UP / DOWN  SELECT",
        colors.gray
    )

    center(
        20,
        "ENTER  OPEN / CONFIRM",
        colors.gray
    )

    center(
        21,
        "ESC  CANCEL",
        colors.gray
    )
end

local function configurationScreen()
    workingConfig =
        copyTable(config)

    normalizeConfig(
        workingConfig
    )

    configSelection = 1
    configOpen = true

    while configOpen do

        drawConfiguration()

        local event, key =
            os.pullEvent("key")

        if key == keys.up then

            configSelection =
                configSelection - 1

            if configSelection < 1 then
                configSelection = 5
            end

        elseif key == keys.down then

            configSelection =
                configSelection + 1

            if configSelection > 5 then
                configSelection = 1
            end

        elseif key == keys.enter then

            if configSelection == 1 then

                keyInputScreen()

            elseif configSelection == 2 then

                routeScreen()

            elseif configSelection == 3 then

                config =
                    copyTable(
                        workingConfig
                    )

                normalizeConfig(config)
                saveConfig()

                workingConfig = nil
                configOpen = false

            elseif configSelection == 4 then

                resetConfig()

                workingConfig =
                    copyTable(config)

                normalizeConfig(
                    workingConfig
                )

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
-- COMMUNICATION
--------------------------------------------------

local function ensureRemote(sender)
    if type(remoteStates[sender]) ~= "table" then

        remoteStates[sender] = {}

        for i = 1, #SIDES do
            remoteStates[sender][SIDES[i]] = false
        end
    end
end

local function setRemoteState(
    sender,
    inputSide,
    state
)

    if not isValidSide(inputSide) then
        return
    end

    ensureRemote(sender)

    remoteStates[sender][inputSide] =
        state
end

local function isInputActive(inputSide)
    if localStates[inputSide] == true then
        return true
    end

    for _, states in pairs(remoteStates) do

        if states[inputSide] == true then
            return true
        end
    end

    return false
end

--------------------------------------------------
-- OUTPUT
--------------------------------------------------

local function shouldOutput(outputSide)

    for i = 1, #SIDES do

        local inputSide =
            SIDES[i]

        local routes =
            config.routes[inputSide]

        if type(routes) == "table" then

            if routes[outputSide] == true then

                if isInputActive(inputSide) then
                    return true
                end
            end
        end
    end

    return false
end

local function updateOutputs()

    for i = 1, #SIDES do

        local outputSide =
            SIDES[i]

        local active =
            shouldOutput(outputSide)

        outputStates[outputSide] =
            active

        if active then

            redstone.setAnalogOutput(
                outputSide,
                15
            )

        else

            redstone.setAnalogOutput(
                outputSide,
                0
            )
        end
    end
end

--------------------------------------------------
-- TRANSMIT
--------------------------------------------------

local function transmitState(
    inputSide,
    state
)

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

--------------------------------------------------
-- INPUT
--------------------------------------------------

local function inputTask()

    for i = 1, #SIDES do

        local side =
            SIDES[i]

        localStates[side] =
            redstone.getInput(side)
    end

    updateOutputs()

    while running do

        for i = 1, #SIDES do

            local side =
                SIDES[i]

            local current =
                redstone.getInput(side)

            local previous =
                localStates[side]

            if current ~= previous then

                localStates[side] =
                    current

                updateOutputs()

                transmitState(
                    side,
                    current
                )
            end
        end

        sleep(0.05)
    end
end

--------------------------------------------------
-- RECEIVE
--------------------------------------------------

local function receiveTask()

    modem.open(CHANNEL)

    while running do

        local event,
            side,
            channel,
            replyChannel,
            message,
            distance =
            os.pullEvent(
                "modem_message"
            )

        if channel == CHANNEL
        and type(message) == "table"
        and message.protocol == PROTOCOL
        and message.version == VERSION
        and type(message.key) == "string"
        and message.key == config.key
        and type(message.sender) == "number"
        and message.sender ~= COMPUTER_ID
        and type(message.input) == "string"
        and isValidSide(message.input)
        and type(message.state) == "boolean" then

            setRemoteState(
                tostring(message.sender),
                message.input,
                message.state
            )

            updateOutputs()
        end
    end
end

--------------------------------------------------
-- MAIN
--------------------------------------------------

local function getLocalInputText()
    local active = {}

    for i = 1, #SIDES do

        local side =
            SIDES[i]

        if localStates[side] then

            table.insert(
                active,
                string.upper(side)
            )
        end
    end

    if #active == 0 then
        return "NONE"
    end

    return table.concat(
        active,
        ", "
    )
end

local function drawMain()

    clearScreen()

    local w, h =
        getScreenSize()

    center(
        2,
        "REDSTONE COMMUNICATIONS",
        colors.white
    )

    center(
        3,
        "LEVEL SYSTEM",
        colors.gray
    )

    separator(5)

    local keyStatus

    if config.key == "" then
        keyStatus = "NOT SET"
    else
        keyStatus = "CONFIGURED"
    end

    center(
        7,
        "COMMUNICATION",
        colors.gray
    )

    center(
        8,
        keyStatus,
        colors.white
    )

    center(
        10,
        "COMPUTER ID",
        colors.gray
    )

    center(
        11,
        tostring(COMPUTER_ID),
        colors.white
    )

    center(
        13,
        "LOCAL INPUT",
        colors.gray
    )

    center(
        14,
        getLocalInputText(),
        colors.white
    )

    center(
        16,
        "ROUTES",
        colors.gray
    )

    center(
        17,
        tostring(
            getTotalRoutes(config)
        )
        .. " CONNECTIONS",
        colors.white
    )

    separator(19)

    if h >= 21 then

        center(
            h - 2,
            "C  CONFIGURATION",
            colors.white
        )

        center(
            h - 1,
            "Q  EXIT",
            colors.gray
        )

    else

        center(
            h - 1,
            "C CONFIGURATION   Q EXIT",
            colors.gray
        )
    end
end

local function guiTask()

    while running do

        if not configOpen then

            drawMain()

            local event, key =
                os.pullEvent("key")

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

    local side =
        SIDES[i]

    localStates[side] = false
    outputStates[side] = false

    redstone.setAnalogOutput(
        side,
        0
    )
end

parallel.waitForAny(
    inputTask,
    receiveTask,
    guiTask
)

running = false

for i = 1, #SIDES do

    redstone.setAnalogOutput(
        SIDES[i],
        0
    )
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

term.clear()
term.setCursorPos(1, 1)

print("Redstone Communications stopped.")
