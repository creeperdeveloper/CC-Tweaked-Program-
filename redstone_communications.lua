local modem = peripheral.find("modem")
if not modem then
  error("No modem found.")
end

local CONFIG_FILE = "config.cfg"
local CHANNEL = 49152

local function loadConfig()
  if fs.exists(CONFIG_FILE) then
    local file = io.open(CONFIG_FILE, "r")
    local data = textutils.unserialize(file:read("*a"))
    file:close()
    if type(data) == "table" then
      return data
    end
  end
  return { key = "default_key", side = "top" }
end

local function saveConfig(config)
  local file = io.open(CONFIG_FILE, "w")
  file:write(textutils.serialize(config))
  file:close()
end

local function drawHeader(title)
  term.clear()
  term.setCursorPos(1, 1)
  local w, h = term.getSize()
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  print(string.rep(" ", w))
  term.setCursorPos(math.floor((w - string.len(title)) / 2) + 1, 1)
  print(title)
  term.setBackgroundColor(colors.black)
  print()
end

local function menuSelect(options)
  local selected = 1
  local w, h = term.getSize()

  while true do
    for i, opt in ipairs(options) do
      term.setCursorPos(3, i + 3)
      if i == selected then
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.yellow)
        print("> " .. opt)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
      else
        print("  " .. opt)
      end
    end

    local event, key = os.pullEvent("key")
    if key == keys.up then
      selected = selected - 1
      if selected < 1 then selected = #options end
    elseif key == keys.down then
      selected = selected + 1
      if selected > #options then selected = 1 end
    elseif key == keys.enter then
      return selected
    end
  end
end

local config = loadConfig()

drawHeader("REDSTONE TRANSCEIVER")
print("  Mode Selection:\n")
local mainOptions = { "Transmitter (TX)", "Receiver (RX)", "Settings / Config" }
local choice = menuSelect(mainOptions)

if choice == 3 then
  drawHeader("SETTINGS")
  print("  Current Key  : " .. config.key)
  print("  Output Side  : " .. config.side)
  print("\n  Edit Settings?")
  
  local editOptions = { "Yes", "No" }
  if menuSelect(editOptions) == 1 then
    term.clear()
    term.setCursorPos(1, 1)
    print("--- Edit Settings ---")
    write("Enter new key [" .. config.key .. "]: ")
    local newKey = read()
    if newKey ~= "" then config.key = newKey end

    print("\nSelect output side:")
    local sides = { "top", "bottom", "left", "right", "front", "back" }
    local sideChoice = menuSelect(sides)
    config.side = sides[sideChoice]

    saveConfig(config)
    print("\nConfig saved successfully! Restarting...")
    os.sleep(1.5)
    os.reboot()
  else
    os.reboot()
  end
  return
end

if choice == 1 then
  drawHeader("TRANSMITTER MODE")
  print("  Key  : " .. config.key)
  print("  State: Monitoring top...\n")
  print("  [Press Ctrl+T to exit]\n")

  modem.open(CHANNEL)
  local lastState = redstone.getInput("top")

  while true do
    local currentState = redstone.getInput("top")
    if currentState ~= lastState then
      lastState = currentState
      modem.transmit(CHANNEL, CHANNEL, { key = config.key, state = currentState })
      term.setCursorPos(3, 7)
      term.clearLine()
      print(string.format("[%s] Sent: %s", textutils.formatTime(os.time(), true), tostring(currentState)))
    end
    os.sleep(0.05)
  end

elseif choice == 2 then
  drawHeader("RECEIVER MODE")
  print("  Key  : " .. config.key)
  print("  Side : " .. config.side)
  print("\n  [Press Ctrl+T to exit]\n")

  modem.open(CHANNEL)

  while true do
    local event, side, replyChannel, replyMessage, message, distance = os.pullEvent("modem_message")
    if type(message) == "table" and message.key == config.key then
      redstone.setOutput(config.side, message.state)
      term.setCursorPos(3, 8)
      term.clearLine()
      print(string.format("[%s] Recv -> %s", textutils.formatTime(os.time(), true), tostring(message.state)))
    end
  end
end
