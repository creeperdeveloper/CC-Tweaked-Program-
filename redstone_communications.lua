local CONFIG_FILE = "redstone_communications.cfg"
local CHANNEL = 48173
local PROTOCOL = "Redstone Communications"

local sides = {
    "top",
    "bottom",
    "left",
    "right",
    "front",
    "back"
}

local config = {
    key = "",
    input = "top",
    output = "bottom"
}

local modem = peripheral.find("modem")

if not modem then
    term.clear()
    term.setCursorPos(1, 1)
    print("Redstone Communications")
    print("")
    print("ERROR")
    print("Modem not found.")
    print("")
    print("Please connect a modem.")
    return
end

local modemName = peripheral.getName(modem)

local function saveConfig()
    local file = fs.open(CONFIG_FILE, "w")
    file.write(textutils.serialize(config))
    file.close()
end

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then
        return
    end

    local file = fs.open(CONFIG_FILE, "r")
    local data = file.readAll()
    file.close()

    local ok, result = pcall(textutils.unserialize, data)

    if ok and type(result) == "table" then
        if type(result.key) == "string" then
            config.key = result.key
        end

        if type(result.input) == "string" then
            config.input = result.input
        end

        if type(result.output) == "string" then
            config.output = result.output
        end
    end
end

local function resetConfig()
    config.key = ""
    config.input = "top"
    config.output = "bottom"
    saveConfig()
end

local function sideIndex(side)
    for i, v in ipairs(sides) do
        if v == side then
            return i
        end
    end

    return 1
end

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function centerText(y, text, color)
    local w = term.getSize()
    local x = math.floor((w - #text) / 2) + 1

    term.setCursorPos(x, y)
    term.setTextColor(color or colors.white)
    term.write(text)
end

local function drawBox(x1, y1, x2, y2, bg)
    term.setBackgroundColor(bg)
    for y = y1, y2 do
        term.setCursorPos(x1, y)
        term.write(string.rep(" ", x2 - x1 + 1))
    end
end

local function drawArrowRow(y, label, value, selected)
    local w = term.getSize()

    local x1 = math.floor(w / 2) - 18
    local x2 = math.floor(w / 2) + 18

    if selected then
        drawBox(x1, y, x2, y, colors.white)
        term.setTextColor(colors.black)
    else
        drawBox(x1, y, x2, y, colors.black)
        term.setTextColor(colors.white)
    end

    term.setCursorPos(x1 + 2, y)
    term.write(label)

    local valueText = "< " .. value .. " >"
    term.setCursorPos(x2 - #valueText - 1, y)
    term.write(valueText)
end

local function drawKeyRow(y, selected)
    local w = term.getSize()

    local x1 = math.floor(w / 2) - 18
    local x2 = math.floor(w / 2) + 18

    if selected then
        drawBox(x1, y, x2, y, colors.white)
        term.setTextColor(colors.black)
    else
        drawBox(x1, y, x2, y, colors.black)
        term.setTextColor(colors.white)
    end

    term.setCursorPos(x1 + 2, y)
    term.write("Communication Key")

    local value = config.key

    if value == "" then
        value = "NOT SET"
    end

    local valueText = value

    if #valueText > 17 then
        valueText = string.sub(valueText, 1, 17)
    end

    term.setCursorPos(x2 - #valueText - 1, y)
    term.write(valueText)
end

local function drawReset(y, selected)
    local w = term.getSize()

    local text = "[ RESET CONFIGURATION ]"
    local x = math.floor((w - #text) / 2) + 1

    if selected then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    term.setCursorPos(x, y)
    term.write(text)
end

local function drawStatus(y)
    local w = term.getSize()

    local inputState = redstone.getInput(config.input)

    local stateText

    if inputState then
        stateText = "RS INPUT: ON"
    else
        stateText = "RS INPUT: OFF"
    end

    local text = stateText
    local x = math.floor((w - #text) / 2) + 1

    term.setCursorPos(x, y)

    if inputState then
        term.setTextColor(colors.white)
    else
        term.setTextColor(colors.gray)
    end

    term.write(text)
end

local function drawUI(selected)
    clear()

    local w, h = term.getSize()

    centerText(2, "REDSTONE COMMUNICATIONS", colors.white)
    centerText(3, "LEVELOS COMMUNICATION SYSTEM", colors.gray)

    local line = string.rep("-", math.min(w - 10, 42))
    centerText(5, line, colors.gray)

    drawKeyRow(7, selected == 1)
    drawArrowRow(9, "INPUT", config.input, selected == 2)
    drawArrowRow(11, "OUTPUT", config.output, selected == 3)

    local mode = "READY"

    if config.key == "" then
        mode = "KEY REQUIRED"
    end

    centerText(13, "STATUS  " .. mode, colors.gray)

    drawStatus(15)

    drawReset(18, selected == 4)

    centerText(h - 2, "↑ ↓ SELECT     ← → CHANGE     ENTER EDIT", colors.gray)
    centerText(h - 1, "R RESET     ESC EXIT", colors.gray)
end

local function editKey()
    local oldCursor = term.getCursorPos()

    term.setCursorBlink(true)
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)

    local w = term.getSize()
    local x1 = math.floor(w / 2) - 18
    local y = 7

    drawBox(x1, y, math.floor(w / 2) + 18, y, colors.white)

    term.setCursorPos(x1 + 20, y)

    local value = config.key

    while true do
        local event, a = os.pullEvent()

        if event == "char" then
            if #value < 32 then
                value = value .. a
            end
        elseif event == "key" then
            if a == keys.backspace then
                value = string.sub(value, 1, -2)
            elseif a == keys.enter then
                config.key = value
                saveConfig()
                break
            elseif a == keys.escape then
                break
            end
        end

        drawUI(1)

        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)

        term.setCursorPos(x1 + 20, y)
        term.write(value)

        term.setCursorBlink(true)
    end

    term.setCursorBlink(false)

    term.setCursorPos(oldCursor)
end

local function changeSide(current, direction)
    local index = sideIndex(current)

    for _ = 1, #sides do
        index = index + direction

        if index > #sides then
            index = 1
        elseif index < 1 then
            index = #sides
        end

        local newSide = sides[index]

        if newSide ~= config.input or newSide ~= config.output then
            return newSide
        end
    end

    return current
end

local function changeInput(direction)
    local current = sideIndex(config.input)

    for _ = 1, #sides do
        current = current + direction

        if current > #sides then
            current = 1
        elseif current < 1 then
            current = #sides
        end

        if sides[current] ~= config.output then
            config.input = sides[current]
            saveConfig()
            return
        end
    end
end

local function changeOutput(direction)
    local current = sideIndex(config.output)

    for _ = 1, #sides do
        current = current + direction

        if current > #sides then
            current = 1
        elseif current < 1 then
            current = #sides
        end

        if sides[current] ~= config.input then
            config.output = sides[current]
            saveConfig()
            return
        end
    end
end

local function configuration()
    local selected = 1

    while true do
        drawUI(selected)

        local event, a, b, c, d = os.pullEvent()

        if event == "key" then
            if a == keys.up then
                selected = selected - 1

                if selected < 1 then
                    selected = 4
                end

            elseif a == keys.down then
                selected = selected + 1

                if selected > 4 then
                    selected = 1
                end

            elseif a == keys.left then
                if selected == 2 then
                    changeInput(-1)
                elseif selected == 3 then
                    changeOutput(-1)
                end

            elseif a == keys.right then
                if selected == 2 then
                    changeInput(1)
                elseif selected == 3 then
                    changeOutput(1)
                end

            elseif a == keys.enter then
                if selected == 1 then
                    editKey()

                elseif selected == 4 then
                    resetConfig()
                end

            elseif a == keys.r then
                resetConfig()

            elseif a == keys.escape then
                return
            end

        elseif event == "mouse_click" then
            local button = a
            local x = b
            local y = c

            if y == 7 then
                selected = 1
                editKey()

            elseif y == 9 then
                selected = 2

            elseif y == 11 then
                selected = 3

            elseif y == 18 then
                selected = 4
                resetConfig()
            end
        end
    end
end

local function sendState(state)
    if config.key == "" then
        return
    end

    modem.transmit(
        CHANNEL,
        CHANNEL,
        {
            protocol = PROTOCOL,
            key = config.key,
            state = state,
            input = config.input
        }
    )
end

local function receiveLoop()
    modem.open(CHANNEL)

    while true do
        local event, side, channel, replyChannel, message = os.pullEvent("modem_message")

        if channel == CHANNEL and type(message) == "table" then
            if message.protocol == PROTOCOL
                and message.key == config.key
                and config.key ~= "" then

                if message.state == true then
                    redstone.setOutput(config.output, true)
                elseif message.state == false then
                    redstone.setOutput(config.output, false)
                end
            end
        end
    end
end

local function inputLoop()
    local lastState = redstone.getInput(config.input)

    while true do
        local currentState = redstone.getInput(config.input)

        if currentState ~= lastState then
            lastState = currentState
            sendState(currentState)
        end

        sleep(0.05)
    end
end

local function guiLoop()
    while true do
        configuration()
        sleep(0.1)
    end
end

loadConfig()

redstone.setOutput(config.output, false)

parallel.waitForAny(
    receiveLoop,
    inputLoop,
    guiLoop
)
