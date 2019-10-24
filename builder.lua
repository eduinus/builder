local robot = require("robot")
local term = require("term")
local os = require("os")
local component = require("component")
local sides = require("sides")
keyboard = require("keyboard")
local computer = require("computer")
 
--[[
--------------------------INTRO--------------------------
This program builds structures using a robot.

The robot should begin in front of the first layer of your schematic on the far right side, facing the schematic.

e.g. (where X is an element of your schematic in the csv and R is the robot)
R
XXXXXXX
XXXXXXX                                  S
XXXXXXX                                E   W      (This compass is oriented re: the direction the robot faces at start)
XXXXXXX                                  N

Note: you can instruct the robot to place a block on a specific surface by appending a #top/#bottom/#north/#south/#east/#west hashtag on the end of a cell in your .csv. See above for cardinal directions in the CSV file and below for example of an orientation hashtag.
(Note orientation tags may fail unless the relevant surface is available to be placed upon. I recommend you place all oriented blocks from above and check your .csv schematic to make sure the relevant surface will be available to be placed upon)

Place schematics in the same directory as this program before running. This program supports .csv files formatted like this:
 
1,,                  -- note this is the first layer (commas are not optional and need to equal (the width of your schematic)-1)
dirt,dirt,dirt       -- front row
dirt,air,dirt        -- air represents air blocks
dirt,dirt,dirt
2,,                  -- note this is the second layer
sand,sand,sand
sand,air,torch#south  -- Note this torch will be placed in a southerly direction. 
sand,sand,sand       -- back row
 
Slot 1: Diamond Pickaxe (Or a lesser pick if you're cheap)
Slots 2-infinity: As the program tells you based on the schematic.

NOTE: This program assumes you have some means of generating power in the robot - i.e. solar or generator. It will stop to recharge when necessary. This program also assumes that you have installed an inventory controller.

]]
 
-- Read Schematic

function tableLength(table)
  count = 1
  while table[count] ~= nil do
    count=count+1
  end
  return count-1
end

function removeOrientation(nameo)
  nameo = string.gsub(nameo, "#bottom", "")
  nameo = string.gsub(nameo, "#top", "")
  nameo = string.gsub(nameo, "#east", "")
  nameo = string.gsub(nameo, "#west", "")
  nameo = string.gsub(nameo, "#north", "")
  nameo = string.gsub(nameo, "#south", "")
  return nameo
end
 
print("Schematic Name:  (Include any filetype suffix)")
schematicFile = io.read()
 
schHeight = 0
schWidth = 0
schDepth = 0
 
schArray = {}
 
for line in io.lines(/schematics/schematicFile) do
    schWidth = 0
    if tonumber(string.gsub(line, ",", "")) ~= schHeight+1 then
      schDepth=schDepth+1
      schArray[schHeight][schDepth] = {}
    end
  for word in string.gmatch(line, '([^,]+)') do
    if tonumber(word) == schHeight+1 then
      schHeight = schHeight+1
      schArray[schHeight] = {}
      schDepth = 0
      break
    else    
      schWidth = schWidth+1
      schArray[schHeight][schDepth][schWidth] = word
    end
  end
end


-- add top layer of pure air
schArray[schHeight+1] = {}
for row=1, tableLength(schArray[1]) do
    schArray[schHeight+1][row] = {}
  for wid=1, tableLength(schArray[1][1]) do
    schArray[schHeight+1][row][wid] = "air"
  end
end

print("...Schematic Imported.")
print(" ")

-- Analyze Components
 
compArray = {}
emptySlot = 1
name = 1
quantity = 2
 
for a=1, tableLength(schArray) do
  for b=1, tableLength(schArray[1]) do
    for c=1, tableLength(schArray[1][1]) do
      foundIt=false
      for i=1, tableLength(compArray) do  
        if removeOrientation(schArray[a][b][c]) == compArray[i][name] then
          compArray[i][quantity] = compArray[i][quantity]+1
          foundIt = true
          break        
        end
      end
      if foundIt == false then
        compArray[emptySlot] = {}
        compArray[emptySlot][name] = removeOrientation(schArray[a][b][c])
        compArray[emptySlot][quantity] = 1
        emptySlot = emptySlot+1
      end
    end
  end
end
 
above = 0
 
print("Please indicate which items need to be placed from above (y/n):           e.g. torches, ladders")
for i=1, tableLength(compArray) do
    above = "x"
  if compArray[i][1] ~= "air" then
    print(compArray[i][1].."?")
    while above ~="y" and above~="n" do above = io.read() end
    if above == "y" then compArray[i][3] = 1 else compArray[i][3] = 0 end    
  else
    compArray[i][3] = 0
  end
end
 
term.clear()
 
print("Material Confirmation... Note: this program does not yet support items that don't stack to 64.")
  print("One Pickaxe!")
for i=1, tableLength(compArray) do
  iSlots = compArray[i][2]/64
  if compArray[i][3] == 1 then append = "Place from Above" else append = "Place normally" end
  if compArray[i][1]~="air" then print(compArray[i][2].." "..compArray[i][1]..": -"..append..": "..iSlots.." stacks.") end
end
 
print("*Make sure your robot has enough inventory space for this!")
print(" ")
print("--- Press Space For Loading Instructions ---")
print("(Or Press Ctrl+Alt+c to exit)")
while not keyboard.isKeyDown(keyboard.keys.space) do os.sleep(0.1) end
term.clear()
 
-- set up dedicated inventory slots
 
freeSlot=2
 
for i=1, tableLength(compArray) do
  if compArray[i][1]~="air" then compArray[i][4]=freeSlot freeSlot=math.ceil(compArray[i][2]/64)+freeSlot end
end
 
print("Robot Inventory Instructions:")
print("  --> One Pickaxe in slot 1.")
for i=1, tableLength(compArray) do
  if compArray[i][1]~="air" then
  print("  --> "..compArray[i][2].." units of "..compArray[i][1].." in slots "..compArray[i][4].." to "..compArray[i][4]+math.floor(compArray[i][2]/64)..".")
  end
end
 
print(" ")
print("--- Press Enter When Ready to Begin ---")
while not keyboard.isKeyDown(keyboard.keys.enter) do os.sleep(0.1) end
term.clear()
robot.select(1)
component.inventory_controller.equip()
print("Building...")

nextMove = "right"

function place(block) -- checks to see if the slot is empty, if so selects next and ticks item slot, places appropriate block
  z=1
  
  block, pBottom = string.gsub(block, "#bottom", "")
  block, pTop = string.gsub(block, "#top", "")
  block, pEast = string.gsub(block, "#east", "")
  block, pWest = string.gsub(block, "#west", "")
  block, pNorth = string.gsub(block, "#north", "")
  block, pSouth = string.gsub(block, "#south", "")

  while compArray[z][1]~=block do z=z+1 end
 
  if component.inventory_controller.getStackInInternalSlot(compArray[z][4]) == nil then compArray[z][4]=compArray[z][4]+1 end
  robot.select(compArray[z][4])
  
  if pBottom == 1 then 
    robot.place(0)
  elseif pTop == 1 then
    robot.place(1)
  elseif pEast == 1 then
    if nextMove == "right" then robot.place(3) end
    if nextMove == "left" then robot.place(3) print("Can't place on the robot itself! falling back to the opposite side.") end
  elseif pWest == 1 then
    if nextMove == "right" then robot.place(3) print("Can't place on the robot itself! falling back to the opposite side.") end
    if nextMove == "left" then robot.place(3) end
  elseif pNorth == 1 then
    if nextMove == "right" then robot.place(5) end
    if nextMove == "left" then robot.place(4) end
  elseif pSouth == 1 then
    if nextMove == "right" then robot.place(4) end
    if nextMove == "left" then robot.place(5) end
  else
    robot.place()
  end
end
 
function placeDown(block) -- same but down
  z=1

  block, pBottom = string.gsub(block, "#bottom", "")
  block, pTop = string.gsub(block, "#top", "")
  block, pEast = string.gsub(block, "#east", "")
  block, pWest = string.gsub(block, "#west", "")
  block, pNorth = string.gsub(block, "#north", "")
  block, pSouth = string.gsub(block, "#south", "")

  while compArray[z][1]~=block do z=z+1 end
 
  if component.inventory_controller.getStackInInternalSlot(compArray[z][4]) == nil then compArray[z][4]=compArray[z][4]+1 end
  robot.select(compArray[z][4])

  if pBottom == 1 then 
    robot.placeDown(0)
  elseif pTop == 1 then
    robot.placeDown(1)
  elseif pEast == 1 then
    if nextMove == "right" then robot.placeDown(3) end
    if nextMove == "left" then robot.placeDown(2) end
  elseif pWest == 1 then
    if nextMove == "right" then robot.placeDown(2) end
    if nextMove == "left" then robot.placeDown(3) end
  elseif pNorth == 1 then
    if nextMove == "right" then robot.placeDown(5) end
    if nextMove == "left" then robot.placeDown(4) end
  elseif pSouth == 1 then
    if nextMove == "right" then robot.placeDown(4) end
    if nextMove == "left" then robot.placeDown(5) end
  else
    robot.placeDown()
  end
end

function move() -- checks to see if robot can move, if not, break block
  if computer.energy() < 1000 then print("Charging...") while computer.energy() < computer.maxEnergy() do os.sleep(10) end end
  if robot.back() == nil then
    robot.turnAround()
	robot.select(1)
    robot.swing()
    if component.inventory_controller.getStackInInternalSlot(1) ~= nil then
      trashSlot = robot.inventorySize()
      slotAdequate = false
      while slotAdequate == false do
		if component.inventory_controller.getStackInInternalSlot(trashSlot) == nil then slotAdequate = true break end
        if robot.compareTo(trashSlot) == true and component.inventory_controller.getStackInInternalSlot(trashSlot).size <64 then slotAdequate = true break end
		trashSlot=trashSlot-1
        if trashSlot == 1 then robot.drop() break end
      end
	  if slotAdequate == true then robot.transferTo(trashSlot) end
    end
    while robot.forward() == nil do
      os.sleep(2)
      robot.select(1)
      robot.swing()
      if component.inventory_controller.getStackInInternalSlot(1) ~= nil then
        trashSlot = robot.inventorySize()
        slotAdequate = false
        while slotAdequate == false do
		  if component.inventory_controller.getStackInInternalSlot(trashSlot) == nil then slotAdequate = true break end
          if robot.compareTo(trashSlot) == true and component.inventory_controller.getStackInInternalSlot(trashSlot).size <64 then slotAdequate = true break end
		  trashSlot=trashSlot-1
          if trashSlot == 1 then robot.drop() break end
        end
	    if slotAdequate == true then robot.transferTo(trashSlot) end
      end
    end
    robot.turnAround()
  end
end
 
function moveUp()
  if computer.energy() < 1000 then print("Charging...") while computer.energy() < computer.maxEnergy() do os.sleep(10) end end
  if robot.up() == nil then
    robot.select(1)
    robot.swingUp()
    if component.inventory_controller.getStackInInternalSlot(1) ~= nil then
      trashSlot = robot.inventorySize()
      slotAdequate = false
      while slotAdequate == false do
		if component.inventory_controller.getStackInInternalSlot(trashSlot) == nil then slotAdequate = true break end
        if robot.compareTo(trashSlot) == true and component.inventory_controller.getStackInInternalSlot(trashSlot).size <64 then slotAdequate = true break end
		trashSlot=trashSlot-1
        if trashSlot == 1 then robot.drop() break end
      end
	  if slotAdequate == true then robot.transferTo(trashSlot) end
    end
    while robot.up() == nil do
      os.sleep(2)
      robot.select(1)
      robot.swingUp()
      if component.inventory_controller.getStackInInternalSlot(1) ~= nil then
        trashSlot = robot.inventorySize()
        slotAdequate = false
        while slotAdequate == false do
		  if component.inventory_controller.getStackInInternalSlot(trashSlot) == nil then slotAdequate = true break end
          if robot.compareTo(trashSlot) == true and component.inventory_controller.getStackInInternalSlot(trashSlot).size <64 then slotAdequate = true break end
		  trashSlot=trashSlot-1
          if trashSlot == 1 then robot.drop() break end
        end
	    if slotAdequate == true then robot.transferTo(trashSlot) end
      end
    end
  end
end
 
function moveDown()
  if computer.energy() < 1000 then print("Charging...") while computer.energy() < computer.maxEnergy() do os.sleep(10) end end
  if robot.down() == nil then
    robot.select(1)
    robot.swingDown()
    if component.inventory_controller.getStackInInternalSlot(1) ~= nil then
      trashSlot = robot.inventorySize()
      slotAdequate = false
      while slotAdequate == false do
		if component.inventory_controller.getStackInInternalSlot(trashSlot) == nil then slotAdequate = true break end
        if robot.compareTo(trashSlot) == true and component.inventory_controller.getStackInInternalSlot(trashSlot).size <64 then slotAdequate = true break end
		trashSlot=trashSlot-1
        if trashSlot == 1 then robot.drop() break end
      end
	  if slotAdequate == true then robot.transferTo(trashSlot) end
    end
    while robot.down() == nil do
      os.sleep(2)
      robot.select(1)
      robot.swingDown()
      if component.inventory_controller.getStackInInternalSlot(1) ~= nil then
        trashSlot = robot.inventorySize()
        slotAdequate = false
        while slotAdequate == false do
		  if component.inventory_controller.getStackInInternalSlot(trashSlot) == nil then slotAdequate = true break end
          if robot.compareTo(trashSlot) == true and component.inventory_controller.getStackInInternalSlot(trashSlot).size <64 then slotAdequate = true break end
		  trashSlot=trashSlot-1
          if trashSlot == 1 then robot.drop() break end
        end
	    if slotAdequate == true then robot.transferTo(trashSlot) end
      end
    end
  end
end
 
function shouldBPD(block)
  block = string.gsub(block, "#bottom", "")
  block = string.gsub(block, "#top", "")
  block = string.gsub(block, "#east", "")
  block = string.gsub(block, "#west", "")
  block = string.gsub(block, "#north", "")
  block = string.gsub(block, "#south", "")
  
  should = false
  z=1
  while compArray[z][1]~=block do z=z+1 end
 
  if compArray[z][3] == 1 then should = true end
 
  return should
end
 
-- Build Program
 
robot.turnAround() -- Turn Around
move()            -- get in chunk
robot.turnLeft() -- face widthways
 
for h=1, tableLength(schArray) do
  nextMove ="right"
  for d=1, tableLength(schArray[1]) do
    if nextMove == "right" then
    for w=1, tableLength(schArray[1][1]), 1 do  -- left to right
        if h~=1 then if schArray[h-1][d][w] ~= "air" and schArray[h-1][d][w] ~= nil then if shouldBPD(schArray[h-1][d][w]) then placeDown(schArray[h-1][d][w]) end end end
        if w~=1 then if schArray[h][d][w-1] ~= "air" and schArray[h][d][w-1] ~= nil then if shouldBPD(schArray[h][d][w-1]) == false then place(schArray[h][d][w-1]) end end end
        if w~=tableLength(schArray[1][1]) then move() else
      if d~= tableLength(schArray[1]) then
            robot.turnRight()
        move()
        if schArray[h][d][w] ~= "air" and schArray[h][d][w] ~= nil then if shouldBPD(schArray[h][d][w]) == false then place(schArray[h][d][w]) end end
        robot.turnRight()
      else
        moveUp()
      if schArray[h][d][w] ~= "air" and schArray[h][d][w] ~= nil then placeDown(schArray[h][d][w]) end
      for i=1, tableLength(schArray[1][1])-1 do move() end robot.turnRight() for i=1, tableLength(schArray[1])-1 do move() end robot.turnLeft()
      end
    end
    end
  end
  if nextMove == "left" then
    for w=tableLength(schArray[1][1]), 1, -1  do  -- right to left
        if h~=1 then if schArray[h-1][d][w] ~= "air" and schArray[h-1][d][w] ~= nil then if shouldBPD(schArray[h-1][d][w]) then placeDown(schArray[h-1][d][w]) end end end
        if w~=tableLength(schArray[1][1]) then if schArray[h][d][w+1] ~= "air" and schArray[h][d][w+1] ~= nil then if shouldBPD(schArray[h][d][w+1]) == false then place(schArray[h][d][w+1]) end end end
        if w~=1 then move() else
      if d~= tableLength(schArray[1]) then
            robot.turnLeft()
        move()
        if schArray[h][d][w] ~= "air" and schArray[h][d][w] ~= nil then if shouldBPD(schArray[h][d][w]) == false then place(schArray[h][d][w]) end end
        robot.turnLeft()
      else
        moveUp()
      if schArray[h][d][w] ~= "air" and schArray[h][d][w] ~= nil then placeDown(schArray[h][d][w]) end
      robot.turnRight() for i=1, tableLength(schArray[1])-1 do move() end robot.turnRight()
      end
    end
    end
  end
      if nextMove == "right" then nextMove = "left" else nextMove = "right" end
  end
  if h~=tableLength(schArray) then print("Layer "..tostring(h).." complete.") end
end
 
robot.turnLeft()
move()
for i=1, tableLength(schArray) do
  moveDown()
end
 
print(" ")
print("Done!")
