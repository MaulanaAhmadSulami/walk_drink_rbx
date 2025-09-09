local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local events = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder")
events.Name = "Events"
events.Parent = ReplicatedStorage

local inventoryFolder = events:FindFirstChild("Inventory") or Instance.new("Folder")
inventoryFolder.Name = "Inventory"
inventoryFolder.Parent = events

local equipEvent = inventoryFolder:FindFirstChild("Equip") or Instance.new("RemoteEvent")
equipEvent.Name = "Equip"
equipEvent.Parent = inventoryFolder

local unequipEvent = inventoryFolder:FindFirstChild("Unequip") or Instance.new("RemoteEvent")
unequipEvent.Name = "Unequip"
unequipEvent.Parent = inventoryFolder

local getStateFunction = inventoryFolder:FindFirstChild("GetState") or Instance.new("RemoteFunction")
getStateFunction.Name = "GetState"
getStateFunction.Parent = inventoryFolder

local updatedEvent = inventoryFolder:FindFirstChild("Updated") or Instance.new("RemoteEvent")
updatedEvent.Name = "Updated"
updatedEvent.Parent = inventoryFolder

local InventoryManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InventoryManager"))

local function publish(p: Player)
	local state = InventoryManager.serialize(p)
	updatedEvent:FireClient(p, state)
end

equipEvent.OnServerEvent:Connect(function(p: Player, drinkId)
	if typeof(drinkId) ~= "number" then return end
	local ok = InventoryManager.equipDrink(p, drinkId)
	if ok then
		publish(p)
	end
end)

unequipEvent.OnServerEvent:Connect(function(p: Player)
	local ok = InventoryManager.unequipDrink(p)
	if ok then
		publish(p)
	end
end)

function getStateFunction.OnServerInvoke(p: Player)
	return InventoryManager.serialize(p)
end

Players.PlayerAdded:Connect(function(p)
	-- send initial state to client after join
	task.defer(function()
		publish(p)
	end)
end)


