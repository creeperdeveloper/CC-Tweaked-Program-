local modem = peripheral.find("modem")
if not modem then
  error("No modem found. Please attach a modem.")
end

local CHANNEL = 49152

print("=== Redstone Transceiver ===")
print("1: Transmitter (TX)")
print("2: Receiver (RX)")
write("Select mode (1 or 2): ")
local modeInput = read()

if modeInput == "1" then
  print("\n--- Transmitter Mode ---")
  write("Enter communication key: ")
  local key = read()
  
  modem.open(CHANNEL)
  print("\nStarted: Monitoring top redstone input...")
  print("Press Ctrl + T to exit.")

  local lastState = redstone.getInput("top")

  while true do
    local currentState = redstone.getInput("top")
    
    if currentState ~= lastState then
      lastState = currentState
      local message = {
        key = key,
        state = currentState
      }
      modem.transmit(CHANNEL, CHANNEL, message)
      print(string.format("[%s] Signal Sent: %s", textutils.formatTime(os.time(), true), tostring(currentState)))
    end
    
    os.sleep(0.05)
  end

elseif modeInput == "2" then
  print("\n--- Receiver Mode ---")
  write("Enter communication key: ")
  local key = read()
  
  write("Select output side (top, bottom, left, right, front, back): ")
  local outputSide = read()
  
  local validSides = {top=true, bottom=true, left=true, right=true, front=true, back=true}
  if not validSides[outputSide] then
    error("Invalid side specified.")
  end

  modem.open(CHANNEL)
  print(string.format("\nStarted: Listening on channel (Output side: %s)...", outputSide))
  print("Press Ctrl + T to exit.")

  while true do
    local event, side, replyChannel, replyMessage, message, distance = os.pullEvent("modem_message")
    
    if type(message) == "table" and message.key == key then
      local rsState = message.state
      redstone.setOutput(outputSide, rsState)
      print(string.format("[%s] Received: RS Output (%s) -> %s", textutils.formatTime(os.time(), true), outputSide, tostring(rsState)))
    end
  end

else
  print("Invalid selection. Please restart the program.")
end
