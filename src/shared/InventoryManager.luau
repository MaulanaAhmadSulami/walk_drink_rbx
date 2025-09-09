local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InventoryManager = {}

local inventoriesByUser: {[number]: {items: {[number]: boolean}, equippedDrinkId: number? }} = {}

local drinksList = require(ReplicatedStorage.Modules.Drinks)

local function buildIndexById()
	local map: {[number]: any} = {}
	for _, drink in ipairs(drinksList) do
		if type(drink.drinkId) == "number" then
			map[drink.drinkId] = drink
		end
	end
	
	return map
end

local drinksById = buildIndexById()

local function ensureInventory(userId: number)
	if not inventoriesByUser[userId] then
		inventoriesByUser[userId] = { items = {}, equippedDrinkId = nil }
	end
	return inventoriesByUser[userId]
end

function InventoryManager.initPlayer(p: Player, saved)
	local inv = ensureInventory(p.UserId)
	-- load from saved structure if exist
	if type(saved) == "table" then
		inv.items = {}
		if type(saved.items) == "table" then
			for id, owned in pairs(saved.items) do
				local numId = tonumber(id)
				if numId and owned == true then
					inv.items[numId] = true
				end
			end
		end
		inv.equippedDrinkId = tonumber(saved.equippedDrinkId) or nil
	end
	return inv
end

function InventoryManager.get(p: Player)
	return ensureInventory(p.UserId)
end

function InventoryManager.addItem(p: Player, drinkId: number)
	local inv = ensureInventory(p.UserId)
	inv.items[drinkId] = true
	print("Inventory added item", p.Name, drinkId)
	return true
end

function InventoryManager.removeItem(p: Player, drinkId: number)
	local inv = ensureInventory(p.UserId)
	inv.items[drinkId] = nil
	if inv.equippedDrinkId == drinkId then
		inv.equippedDrinkId = nil
	end
	print("Inventory removed item ", p.Name, drinkId)
	return true
end

local function clearAllDrinkTools(p: Player)
	local function purge(container: Instance?)
		if not container then return end
		for _, inst in ipairs(container:GetChildren()) do
			if inst:IsA("Tool") then
				inst:Destroy()
			end
		end
	end
	purge(p:FindFirstChildOfClass("Backpack"))
	purge(p.Character)
	local sg = p:FindFirstChild("StarterGear")
	if sg then purge(sg) end
end

local function cloneDrinkTool(drinkId: number): Tool?
	local drink = drinksById[drinkId]
	if not drink then return nil end
	local item = drink.item
	if typeof(item) == "Instance" and item:IsA("Tool") then
		return item:Clone()
	end
	return nil
end

function InventoryManager.equipDrink(p: Player, drinkId: number)
	local inv = ensureInventory(p.UserId)
	
	if inv.items[drinkId] ~= true then
		warn("player does not own drinkId", p.Name, drinkId)
		return false
	end
	
	local tool = cloneDrinkTool(drinkId)
	if not tool then
		warn("Failed to clone tool for drinkId", drinkId)
	end
	clearAllDrinkTools(p)
	local backpack = p:FindFirstChildOfClass("Backpack")
	if not backpack then
		warn("Backpack not found for ", p.Name)
	end
	
	tool.Parent = backpack
	local humanoid = (p.Character and p.Character:FindFirstChildOfClass("Humanoid"))
	if humanoid then
		pcall(function()
			humanoid:EquipTool(tool)
		end)
	end
	inv.equippedDrinkId = drinkId
	print("equipped drink", p.Name, drinkId)
	return true
end

function InventoryManager.unequipDrink(p: Player)
	local inv = ensureInventory(p.UserId)
	clearAllDrinkTools(p)
	inv.equippedDrinkId = nil
	print("unequipped drink ", p.Name)
	return true
end


function InventoryManager.serialize(p: Player)
	local inv = ensureInventory(p.UserId)
	--compact serializeble form
	local itemsCopy: {[number]: boolean} = {}
	for id, owned in pairs(inv.items) do
		if owned then itemsCopy[id] = true end
	end
	return {
		items = itemsCopy,
		equippedDrinkId = inv.equippedDrinkId,
	}
end

function InventoryManager.playerRemoving(p: Player)
	inventoriesByUser[p.UserId] = inventoriesByUser[p.UserId] or nil
end

return InventoryManager
