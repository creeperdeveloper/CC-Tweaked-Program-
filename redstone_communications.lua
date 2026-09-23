local CONFIG_FILE = "redstone_communications.cfg"
local CHANNEL = 48173
local PROTOCOL = "Redstone Communications"
local VERSION = 8
local REMOTE_TIMEOUT = 3

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
    error("No modem found")
end

if not modem.isOpen(CHANNEL) then
    modem.open(CHANNEL)
end

local computerID = os.getComputerID()
local running = true

local config = {
    key = "",
    routes = {}
}

local localStates = {}
local localOutputs = {}
local remoteStates = {}

local function createRoutes()
    local routes = {}

    for _, inputSide in ipairs(SIDES) do
        routes[inputSide] = {}

        for _, outputSide in ipairs(SIDES) do
            routes[inputSide][outputSide] = false
        end
    end

    return routes
end

local function createOutputs()
    local outputs = {}

    for _, side in ipairs(SIDES) do
        outputs[side] = false
    end

    return outputs
end

local function normalizeConfig(data)
    local result = {
        key = "",
        routes = createRoutes()
    }

    if type(data) ~= "table" then
        return result
    end

    if type(data.key) == "string" then
        result.key = data.key
    end

    if type(data.routes) == "table" then
        for _, inputSide in ipairs(SIDES) do
            if type(data.routes[inputSide]) == "table" then
                for _, outputSide in ipairs(SIDES) do
                    result.routes[inputSide][outputSide] =
                        data.routes[inputSide][outputSide] == true
                end
            end
        end
    end

    return result
end

local function copyConfig(source)
    local result = {
        key = source.key or "",
        routes = createRoutes()
    }

    if type(source.routes) == "table" then
        for _, inputSide in ipairs(SIDES) do
            if type(source.routes[inputSide]) == "table" then
                for _, outputSide in ipairs(SIDES) do
                    result.routes[inputSide][outputSide] =
                        source.routes[inputSide][outputSide] == true
                end
            end
        end
    end

    return result
end

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then
        return {
            key = "",
            routes = createRoutes()
        }
    end

    local file = fs.open(CONFIG_FILE, "r")

    if not file then
        return {
            key = "",
            routes = createRoutes()
        }
    end

    local content = file.readAll()
    file.close()

    local ok, data = pcall(textutils.unserialize, content)

    if not ok or type(data) ~= "table" then
        return {
            key = "",
            routes = createRoutes()
        }
    end

    return normalizeConfig(data)
end

local function saveConfig()
    config = normalizeConfig(config)

    local file = fs.open(CONFIG_FILE, "w")

    if not file then
        return false
    end

    file.write(textutils.serialize(config))
    file.close()

    return true
end

config = loadConfig()

for _, side in ipairs(SIDES) do
    localStates[side] = redstone.getInput(side)
    localOutputs[side] = false
end

local function clearRemoteStates()
    remoteStates = {}
end

local function calculateLocalOutputs(routes)
    local outputs = createOutputs()

    for _, inputSide in ipairs(SIDES) do
        if localStates[inputSide] then
            if type(routes[inputSide]) == "table" then
                for _, outputSide in ipairs(SIDES) do
                    if routes[inputSide][outputSide] then
                        outputs[outputSide] = true
                    end
                end
            end
        end
    end

    return outputs
end

local function updateOutputs()
    local finalOutputs = createOutputs()

    for _, side in ipairs(SIDES) do
        if localOutputs[side] then
            finalOutputs[side] = true
        end
    end

    for _, peer in pairs(remoteStates) do
        if type(peer) == "table"
            and type(peer.outputs) == "table" then

            for _, side in ipairs(SIDES) do
                if peer.outputs[side] then
                    finalOutputs[side] = true
                end
            end
        end
    end

    for _, side in ipairs(SIDES) do
        if finalOutputs[side] then
            redstone.setAnalogOutput(side, 15)
        else
            redstone.setAnalogOutput(side, 0)
        end
    end
end

local function recalculateLocalOutputs()
    localOutputs = calculateLocalOutputs(config.routes)
    updateOutputs()
end

local function sendOutputState()
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
            sender = computerID,
            outputs = localOutputs,
            time = os.epoch("utc")
        }
    )
end

local function inputTask()
    local lastSend = 0

    while running do
        local changed = false

        for _, side in ipairs(SIDES) do
            local state = redstone.getInput(side)

            if localStates[side] ~= state then
                localStates[side] = state
                changed = true
            end
        end

        if changed then
            recalculateLocalOutputs()
            sendOutputState()
        end

        local now = os.epoch("utc") / 1000

        if config.key ~= "" and now - lastSend >= 1 then
            sendOutputState()
            lastSend = now
        end

        local expired = false

        for id, peer in pairs(remoteStates) do
            if now - peer.lastSeen >= REMOTE_TIMEOUT then
                remoteStates[id] = nil
                expired = true
            end
        end

        if expired then
            updateOutputs()
        end

        sleep(0.05)
    end
end

local function receiveTask()
    while running do
        local _, modemSide, channel, replyChannel, message =
            os.pullEvent("modem_message")

        if channel == CHANNEL
            and type(message) == "table"
            and message.protocol == PROTOCOL
            and message.version == VERSION
            and type(message.key) == "string"
            and type(message.sender) == "number"
            and type(message.outputs) == "table"
            and message.sender ~= computerID
            and config.key ~= ""
            and message.key == config.key then

            local outputs = createOutputs()

            for _, side in ipairs(SIDES) do
                outputs[side] =
                    message.outputs[side] == true
            end

            remoteStates[message.sender] = {
                outputs = outputs,
                lastSeen = os.epoch("utc") / 1000
            }

            updateOutputs()
        end
    end
end

local function clearScreen()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function centerText(y, text, color)
    local w = term.getSize()

    if #text > w then
        text = text:sub(1, w)
    end

    term.setCursorPos(
        math.max(1, math.floor((w - #text) / 2) + 1),
        y
    )

    term.setTextColor(color or colors.white)
    term.write(text)
end

local function drawTitle(title)
    local w = term.getSize()

    centerText(2, title, colors.white)

    term.setCursorPos(2, 3)
    term.setTextColor(colors.gray)
    term.write(string.rep("-", math.max(1, w - 2)))
end

local function drawButton(x, y, text, selected)
    term.setCursorPos(x, y)

    if selected then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    term.write("[ " .. text .. " ]")

    term.setBackgroundColor(colors.black)
end

local function remoteCount()
    local count = 0

    for _ in pairs(remoteStates) do
        count = count + 1
    end

    return count
end

local function drawMainScreen()
    clearScreen()
    drawTitle("REDSTONE COMMUNICATIONS")

    term.setCursorPos(3, 5)
    term.setTextColor(colors.gray)
    term.write("COMPUTER")

    term.setTextColor(colors.white)
    term.write(" #" .. tostring(computerID))

    term.setCursorPos(3, 6)
    term.setTextColor(colors.gray)
    term.write("KEY")

    term.setTextColor(colors.white)

    if config.key == "" then
        term.write(" NOT SET")
    else
        term.write(" " .. config.key)
    end

    term.setCursorPos(3, 7)
    term.setTextColor(colors.gray)
    term.write("MODEM")

    term.setTextColor(colors.lime)
    term.write(" CONNECTED")

    term.setCursorPos(3, 8)
    term.setTextColor(colors.gray)
    term.write("REMOTE")

    local count = remoteCount()

    if count > 0 then
        term.setTextColor(colors.lime)
    else
        term.setTextColor(colors.gray)
    end

    term.write(" " .. tostring(count) .. " PC")

    term.setCursorPos(3, 10)
    term.setTextColor(colors.gray)
    term.write("LOCAL INPUT")

    local positions = {
        {3, 12, "top"},
        {3, 13, "bottom"},
        {3, 14, "left"},
        {28, 12, "right"},
        {28, 13, "front"},
        {28, 14, "back"}
    }

    for _, p in ipairs(positions) do
        term.setCursorPos(p[1], p[2])

        term.setTextColor(colors.white)
        term.write(string.format("%-7s", string.upper(p[3])))

        if localStates[p[3]] then
            term.setTextColor(colors.lime)
            term.write("[ON ]")
        else
            term.setTextColor(colors.gray)
            term.write("[OFF]")
        end
    end

    term.setCursorPos(3, 18)
    term.setTextColor(colors.white)
    term.write("[C] CONFIG")

    term.setCursorPos(18, 18)
    term.write("[Q] QUIT")
end

local function waitKeyOrChar()
    local result

    parallel.waitForAny(
        function()
            local _, key = os.pullEvent("key")

            result = {
                type = "key",
                value = key
            }
        end,

        function()
            local _, character = os.pullEvent("char")

            result = {
                type = "char",
                value = character
            }
        end
    )

    return result.type, result.value
end

local function keyInputScreen(workingConfig)
    local value = workingConfig.key
    local selected = 1

    while true do
        clearScreen()
        drawTitle("COMMUNICATION KEY")

        term.setCursorPos(4, 6)
        term.setTextColor(colors.gray)
        term.write("KEY")

        term.setCursorPos(4, 8)
        term.setTextColor(colors.white)
        term.write(value)

        term.setTextColor(colors.gray)
        term.write("_")

        drawButton(4, 11, "SAVE", selected == 1)
        drawButton(15, 11, "CANCEL", selected == 2)

        term.setCursorPos(4, 14)
        term.setTextColor(colors.gray)
        term.write("TYPE TO EDIT")

        term.setCursorPos(4, 15)
        term.write("UP / DOWN: SELECT")

        term.setCursorPos(4, 16)
        term.write("ENTER: CONFIRM")

        local eventType, valueOrKey = waitKeyOrChar()

        if eventType == "char" then
            if type(valueOrKey) == "string" then
                value = value .. valueOrKey
            end

        elseif eventType == "key" then
            local key = valueOrKey

            if key == keys.backspace then
                if #value > 0 then
                    value = value:sub(1, -2)
                end

            elseif key == keys.up then
                selected = selected - 1

                if selected < 1 then
                    selected = 2
                end

            elseif key == keys.down then
                selected = selected + 1

                if selected > 2 then
                    selected = 1
                end

            elseif key == keys.enter then
                if selected == 1 then
                    workingConfig.key = value
                end

                return
            end
        end
    end
end

local function routeOutputScreen(workingConfig, inputSide)
    local selected = 1

    local items = {
        "TOP",
        "BOTTOM",
        "LEFT",
        "RIGHT",
        "FRONT",
        "BACK",
        "BACK"
    }

    while true do
        clearScreen()
        drawTitle("OUTPUT ROUTES")

        term.setCursorPos(3, 5)
        term.setTextColor(colors.gray)
        term.write("INPUT: ")

        term.setTextColor(colors.white)
        term.write(string.upper(inputSide))

        for i, item in ipairs(items) do
            local y = 7 + i

            term.setCursorPos(4, y)

            if i == selected then
                term.setBackgroundColor(colors.white)
                term.setTextColor(colors.black)
            else
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
            end

            if i <= 6 then
                local outputSide = SIDES[i]
                local enabled =
                    workingConfig.routes[inputSide][outputSide]

                term.write(
                    string.format(
                        " %-4s %s ",
                        enabled and "ON" or "OFF",
                        item
                    )
                )
            else
                term.write(" BACK ")
            end

            term.setBackgroundColor(colors.black)
        end

        local _, key = os.pullEvent("key")

        if key == keys.up then
            selected = selected - 1

            if selected < 1 then
                selected = 7
            end

        elseif key == keys.down then
            selected = selected + 1

            if selected > 7 then
                selected = 1
            end

        elseif key == keys.enter then
            if selected == 7 then
                return
            end

            local outputSide = SIDES[selected]

            workingConfig.routes[inputSide][outputSide] =
                not workingConfig.routes[inputSide][outputSide]
        end
    end
end

local function routeInputScreen(workingConfig)
    local selected = 1

    local items = {
        "TOP",
        "BOTTOM",
        "LEFT",
        "RIGHT",
        "FRONT",
        "BACK",
        "BACK"
    }

    while true do
        clearScreen()
        drawTitle("INPUT ROUTES")

        term.setCursorPos(3, 5)
        term.setTextColor(colors.gray)
        term.write("SELECT INPUT SIDE")

        for i, item in ipairs(items) do
            term.setCursorPos(4, 6 + i)

            if i == selected then
                term.setBackgroundColor(colors.white)
                term.setTextColor(colors.black)
            else
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
            end

            term.write(" " .. item .. " ")

            term.setBackgroundColor(colors.black)
        end

        local _, key = os.pullEvent("key")

        if key == keys.up then
            selected = selected - 1

            if selected < 1 then
                selected = 7
            end

        elseif key == keys.down then
            selected = selected + 1

            if selected > 7 then
                selected = 1
            end

        elseif key == keys.enter then
            if selected == 7 then
                return
            end

            routeOutputScreen(
                workingConfig,
                SIDES[selected]
            )
        end
    end
end

local function configurationScreen()
    local workingConfig = copyConfig(config)
    local selected = 1

    local items = {
        "KEY",
        "ROUTES",
        "RESET",
        "SAVE & EXIT",
        "CANCEL"
    }

    while true do
        clearScreen()
        drawTitle("CONFIGURATION")

        for i, item in ipairs(items) do
            drawButton(
                5,
                5 + i * 2,
                item,
                i == selected
            )
        end

        term.setCursorPos(5, 17)
        term.setTextColor(colors.gray)
        term.write("UP / DOWN: SELECT")

        term.setCursorPos(5, 18)
        term.write("ENTER: OPEN")

        local _, key = os.pullEvent("key")

        if key == keys.up then
            selected = selected - 1

            if selected < 1 then
                selected = #items
            end

        elseif key == keys.down then
            selected = selected + 1

            if selected > #items then
                selected = 1
            end

        elseif key == keys.enter then
            if selected == 1 then
                keyInputScreen(workingConfig)

            elseif selected == 2 then
                routeInputScreen(workingConfig)

            elseif selected == 3 then
                workingConfig = {
                    key = "",
                    routes = createRoutes()
                }

            elseif selected == 4 then
                config = normalizeConfig(workingConfig)

                saveConfig()

                clearRemoteStates()

                recalculateLocalOutputs()

                sendOutputState()

                return

            elseif selected == 5 then
                return
            end
        end
    end
end

local function mainScreen()
    while running do
        drawMainScreen()

        local action = nil
        local timerID = os.startTimer(0.2)

        parallel.waitForAny(
            function()
                local _, key = os.pullEvent("key")

                action = {
                    type = "key",
                    value = key
                }
            end,

            function()
                while true do
                    local _, id = os.pullEvent("timer")

                    if id == timerID then
                        action = {
                            type = "timer"
                        }

                        return
                    end
                end
            end
        )

        if action and action.type == "key" then
            if action.value == keys.c then
                configurationScreen()

            elseif action.value == keys.q then
                running = false
            end
        end
    end
end

recalculateLocalOutputs()

parallel.waitForAny(
    inputTask,
    receiveTask,
    mainScreen
)

running = false

for _, side in ipairs(SIDES) do
    redstone.setAnalogOutput(side, 0)
end

if modem.isOpen(CHANNEL) then
    modem.close(CHANNEL)
end

clearScreen()

term.setCursorPos(1, 1)
term.setTextColor(colors.white)

print("Redstone Communications stopped.")
