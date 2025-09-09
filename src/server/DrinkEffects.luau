local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local drinksList = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Drinks"))

local function normalizeName(name: string): string
	local lower = string.lower(name)
	lower = string.gsub(lower, "%s+", "")
	lower = string.gsub(lower, "[^%w]", "")
	return lower
end

type DrinkInfo = {
	bonusSpeed: number,
}

local drinkIndexByName: {[string]: DrinkInfo} = {}

local function buildDrinkIndex()
	local index: {[string]: DrinkInfo} = {}
	if type(drinksList) ~= "table" then
		warn("DrinkEffects buildDrinkIndex: expected table from Shared/Drinks module, got", typeof(drinksList))
		return index
	end
	for _, drink in ipairs(drinksList) do
		print("[DrinkEffects] Register drink:", drink.name)
		local names: {string} = {}
		-- Prefer the referenced tool's actual name if available
		local item = drink.item
		if typeof(item) == "Instance" and item.Name then
			table.insert(names, item.Name)
		elseif type(item) == "string" then
			table.insert(names, item)
		end
		-- Also include the display name as a fallback
		if type(drink.name) == "string" then
			table.insert(names, drink.name)
		end

		local bonus = 0
		if type(drink.effect) == "table" and type(drink.effect.BonusSpeed) == "number" then
			bonus = drink.effect.BonusSpeed
		end

		for _, n in ipairs(names) do
			local key = normalizeName(n)
			index[key] = { bonusSpeed = bonus }
			print("DrinkEffects   -> alias:", n, "key:", key, "bonus:", bonus)
		end
	end
	return index
end

drinkIndexByName = buildDrinkIndex()

local function collectToolNamesFrom(container: Instance?): {[string]: boolean}
	local owned: {[string]: boolean} = {}
	if not container then return owned end
	for _, inst in ipairs(container:GetChildren()) do
		if inst:IsA("Tool") then
			owned[normalizeName(inst.Name)] = true
		end
	end
	return owned
end

local function recomputeDrinkBonus(p: Player)
	-- Priority 1: any equipped drink (in Character)
	local selectedBonus = 0
	local char = p.Character
	if char then
		local equippedNames = collectToolNamesFrom(char)
		for key, _ in pairs(equippedNames) do
			local info = drinkIndexByName[key]
			if info and type(info.bonusSpeed) == "number" then
				selectedBonus = math.max(selectedBonus, info.bonusSpeed)
				print("DrinkEffects Equipped match:", key, "bonus:", info.bonusSpeed)
			end
		end
	end

	-- Set attributes
	selectedBonus = math.max(0, selectedBonus)
	p:SetAttribute("DrinkBonusSpeed", selectedBonus)
	print("DrinkEffects Result bonus for", p.Name, selectedBonus)
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:SetAttribute("DrinkBonusSpeed", selectedBonus)
		end
	end
end

local playerConnections: {[number]: {RBXScriptConnection}} = {}

local function trackPlayer(p: Player)
	playerConnections[p.UserId] = {}

	-- Initial compute after a tiny defer to allow character/backpack to populate
	task.defer(function()
		recomputeDrinkBonus(p)
	end)

	-- Backpack tool changes
	local backpack = p:FindFirstChildOfClass("Backpack")
	if backpack then
		local c1 = backpack.ChildAdded:Connect(function()
			task.defer(function()
				recomputeDrinkBonus(p)
			end)
		end)
		local c2 = backpack.ChildRemoved:Connect(function()
			task.defer(function()
				recomputeDrinkBonus(p)
			end)
		end)
		table.insert(playerConnections[p.UserId], c1)
		table.insert(playerConnections[p.UserId], c2)
	end

	-- StarterGear changes (saved loadout)
	local starterGear = p:FindFirstChild("StarterGear")
	if starterGear then
		local c3 = starterGear.ChildAdded:Connect(function()
			recomputeDrinkBonus(p)
		end)
		local c4 = starterGear.ChildRemoved:Connect(function()
			recomputeDrinkBonus(p)
		end)
		table.insert(playerConnections[p.UserId], c3)
		table.insert(playerConnections[p.UserId], c4)
	end

	-- Character spawns and tool moves between Backpack <-> Character
	local c5 = p.CharacterAdded:Connect(function(character)
		local function hookCharacter(char: Model)
			local cA = char.ChildAdded:Connect(function()
				recomputeDrinkBonus(p)
			end)
			local cR = char.ChildRemoved:Connect(function()
				recomputeDrinkBonus(p)
			end)
			table.insert(playerConnections[p.UserId], cA)
			table.insert(playerConnections[p.UserId], cR)
			-- Recompute once the humanoid exists
			char:WaitForChild("Humanoid", 5)
			recomputeDrinkBonus(p)
		end
		hookCharacter(character)
	end)
	table.insert(playerConnections[p.UserId], c5)
end

local function untrackPlayer(p: Player)
	local conns = playerConnections[p.UserId]
	if conns then
		for _, c in ipairs(conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		playerConnections[p.UserId] = nil
	end
end

Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(p)
	untrackPlayer(p)
	-- Clear attribute on leave to avoid saving stale to datastore mirrors
	p:SetAttribute("DrinkBonusSpeed", nil)
end)

-- For studio test when script runs after some players already exist
for _, p in ipairs(Players:GetPlayers()) do
	trackPlayer(p)
end


