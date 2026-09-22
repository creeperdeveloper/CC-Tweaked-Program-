local CONFIG_FILE = "redstone_communications.cfg"

local CHANNEL = 48173
local PROTOCOL = "Redstone Communications"

local SIDES = {
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

local running = true
local configOpen = false
local selected = 1

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local function saveConfig()
    local file = fs.open(CONFIG_FILE, "w")

    if file then
        file.write(textutils.serialize(config))
        file.close()
    end
end

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then
        saveConfig()
        return
    end

    local file = fs.open(CONFIG_FILE, "r")

    if not file then
        return
    end

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

    if config.input == config.output then
        config.output = "bottom"

        if config.input == config.output then
            config.input = "top"
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
    for i = 1, #SIDES do
        if SIDES[i] == side then
            return i
        end
    end

    return 1
end

--------------------------------------------------
-- TERMINAL
--------------------------------------------------

local function screenSize()
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
    local w, h = screenSize()

    if type(y) ~= "number" then
        return
    end

    if type(text) ~= "string" then
        text = tostring(text or "")
    end

    if y < 1 then
        y = 1
    end

    if y > h then
        y = h
    end

    if #text > w then
        text = string.sub(text, 1, w)
    end

    local x = math.floor((w - #text) / 2) + 1

    if x < 1 then
        x = 1
    end

    if x > w then
        x = w
    end

    term.setCursorPos(x, y)
    term.setTextColor(color or colors.white)
    term.write(text)
end

local function line(y, color)
    local w, h = screenSize()

    local length = w - 8

    if length < 1 then
        length = 1
    end

    term.setTextColor(color or colors.gray)
    term.setCursorPos(1, y)
    term.write(string.rep("-", length))
end

local function box(y, text, selected)
    local w, h = screenSize()

    local width = math.min(40, w - 6)

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

    local output = text

    if #output > width - 2 then
        output = string.sub(output, 1, width - 2)
    end

    term.setCursorPos(x + 1, y)
    term.write(output)

    term.setBackgroundColor(colors.black)
end

--------------------------------------------------
-- SIDE SELECTION
--------------------------------------------------

local function changeInput(direction)
    local index = sideIndex(config.input)

    for i = 1, #SIDES do
        index = index + direction

        if index > #SIDES then
            index = 1
        end

        if index < 1 then
            index = #SIDES
        end

        local candidate = SIDES[index]

        if candidate ~= config.output then
            config.input = candidate
            saveConfig()
            return
        end
    end
end

local function changeOutput(direction)
    local index = sideIndex(config.output)

    for i = 1, #SIDES do
        index = index + direction

        if index > #SIDES then
            index = 1
        end

        if index < 1 then
            index = #SIDES
        end

        local candidate = SIDES[index]

        if candidate ~= config.input then
            config.output = candidate
            saveConfig()
            return
        end
    end
end

--------------------------------------------------
-- KEY INPUT SCREEN
--------------------------------------------------

local function keyInputScreen()
    clearScreen()

    local w, h = screenSize()

    center(3, "COMMUNICATION KEY", colors.white)
    center(4, "ENTER A SHARED KEY", colors.gray)

    line(6, colors.gray)

    local width = math.min(36, w - 6)

    if width < 10 then
        width = w - 2
    end

    local x = math.floor((w - width) / 2) + 1

    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)

    term.setCursorPos(x, 8)
    term.write(string.rep(" ", width))

    term.setCursorPos(x + 1, 8)
    term.setCursorBlink(true)

    local value = config.key

    term.write(value)

    while true do
        local event, a = os.pullEvent()

        if event == "char" then
            if #value < width - 2 then
                value = value .. a

                term.setCursorPos(x + 1, 8)
                term.write(string.rep(" ", width - 2))

                term.setCursorPos(x + 1, 8)
                term.write(value)
            end

        elseif event == "key" then

            if a == keys.backspace then
                if #value > 0 then
                    value = string.sub(value, 1, #value - 1)

                    term.setCursorPos(x + 1, 8)
                    term.write(string.rep(" ", width - 2))

                    term.setCursorPos(x + 1, 8)
                    term.write(value)
                end

            elseif a == keys.enter then
                config.key = value
                saveConfig()

                term.setCursorBlink(false)

                return

            elseif a == keys.escape then
                term.setCursorBlink(false)

                return
            end
        end
    end
end

--------------------------------------------------
-- CONFIGURATION UI
--------------------------------------------------

local function drawConfig()
    clearScreen()

    local w, h = screenSize()

    center(2, "REDSTONE COMMUNICATIONS", colors.white)
    center(3, "CONFIGURATION", colors.gray)

    line(5, colors.gray)

    local keyText = config.key

    if keyText == "" then
        keyText = "NOT SET"
    end

    box(7, "KEY       " .. keyText, selected == 1)
    box(9, "INPUT     < " .. config.input .. " >", selected == 2)
    box(11, "OUTPUT    < " .. config.output .. " >", selected == 3)

    line(13, colors.gray)

    local state = redstone.getInput(config.input)

    if state then
        center(15, "INPUT SIGNAL   ON", colors.white)
    else
        center(15, "INPUT SIGNAL   OFF", colors.gray)
    end

    box(17, "RESET CONFIGURATION", selected == 4)

    if h >= 20 then
        center(h - 2, "UP / DOWN  SELECT", colors.gray)
        center(h - 1, "LEFT / RIGHT  CHANGE   ENTER  OPEN", colors.gray)
    else
        center(h - 1, "UP DOWN SELECT | LEFT RIGHT CHANGE | ENTER", colors.gray)
    end
end

local function configurationScreen()
    configOpen = true
    selected = 1

    while configOpen do
        drawConfig()

        local event, key = os.pullEvent("key")

        if key == keys.up then
            selected = selected - 1

            if selected < 1 then
                selected = 4
            end

        elseif key == keys.down then
            selected = selected + 1

            if selected > 4 then
                selected = 1
            end

        elseif key == keys.left then

            if selected == 2 then
                changeInput(-1)

            elseif selected == 3 then
                changeOutput(-1)
            end

        elseif key == keys.right then

            if selected == 2 then
                changeInput(1)

            elseif selected == 3 then
                changeOutput(1)
            end

        elseif key == keys.enter then

            if selected == 1 then
                keyInputScreen()

            elseif selected == 4 then
                resetConfig()
            end

        elseif key == keys.escape then
            configOpen = false
        end
    end
end

--------------------------------------------------
-- MAIN SCREEN
--------------------------------------------------

local function drawMain()
    clearScreen()

    local w, h = screenSize()

    center(2, "REDSTONE COMMUNICATIONS", colors.white)
    center(3, "LEVEL SYSTEM", colors.gray)

    line(5, colors.gray)

    local keyState = "NOT SET"

    if config.key ~= "" then
        keyState = "CONFIGURED"
    end

    center(7, "COMMUNICATION", colors.gray)
    center(8, keyState, colors.white)

    center(10, "INPUT", colors.gray)
    center(11, config.input, colors.white)

    center(13, "OUTPUT", colors.gray)
    center(14, config.output, colors.white)

    local inputState = redstone.getInput(config.input)

    if inputState then
        center(16, "SIGNAL  ON", colors.white)
    else
        center(16, "SIGNAL  OFF", colors.gray)
    end

    line(18, colors.gray)

    if h >= 21 then
        center(h - 2, "C  CONFIGURATION", colors.white)
        center(h - 1, "Q  EXIT", colors.gray)
    else
        center(h - 1, "C CONFIGURATION   Q EXIT", colors.gray)
    end
end

--------------------------------------------------
-- COMMUNICATION
--------------------------------------------------

local function transmitState(state)
    if config.key == "" then
        return
    end

    modem.transmit(
        CHANNEL,
        CHANNEL,
        {
            protocol = PROTOCOL,
            key = config.key,
            state = state
        }
    )
end

local function inputTask()
    local lastState = redstone.getInput(config.input)

    while running do
        local currentState = redstone.getInput(config.input)

        if currentState ~= lastState then
            lastState = currentState

            transmitState(currentState)
        end

        sleep(0.05)
    end
end

local function receiveTask()
    modem.open(CHANNEL)

    while running do
        local event,
              side,
              channel,
              replyChannel,
              message,
              distance = os.pullEvent("modem_message")

        if channel == CHANNEL then

            if type(message) == "table" then

                if message.protocol == PROTOCOL then

                    if config.key ~= ""
                    and message.key == config.key then

                        if message.state == true then

                            redstone.setAnalogOutput(
                                config.output,
                                15
                            )

                        elseif message.state == false then

                            redstone.setAnalogOutput(
                                config.output,
                                0
                            )
                        end
                    end
                end
            end
        end
    end
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

redstone.setAnalogOutput(config.output, 0)

parallel.waitForAny(
    inputTask,
    receiveTask,
    guiTask
)

redstone.setAnalogOutput(config.output, 0)

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

print("Redstone Communications stopped.")
