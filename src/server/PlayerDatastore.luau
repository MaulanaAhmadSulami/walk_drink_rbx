local PlayerDatastore = game:GetService("DataStoreService"):GetDataStore("PlayerDataStore")
local rs = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local events = rs:WaitForChild("Events")
local statUpdateEvent = events:WaitForChild("StatsUpdateEvent")

local constant = require(rs:WaitForChild("Constants"))
local InventoryManager = require(rs:WaitForChild("Shared"):WaitForChild("InventoryManager"))

local playerData = {}

-- Helpers (can be moved into modules if possible later)
local function serializeVector3(v3)
	if typeof(v3) == "Vector3" then
		return { X = v3.X, Y = v3.Y, Z = v3.Z }
	end
	return nil
end

local function deserializeVector3(t)
	if type(t) == "table" and typeof(t.X) == "number" and typeof(t.Y) == "number" and typeof(t.Z) == "number" then
		return Vector3.new(t.X, t.Y, t.Z)
	end
	return nil
end

local function getGoalParts()
	local parts = {}
	for _, inst in ipairs(CollectionService:GetTagged(constant.GOAL_TAG)) do
		if inst:IsA("BasePart") then table.insert(parts, inst) end
	end

	local named = workspace:FindFirstChild(constant.GOAL_TAG)
	if named and named:IsA("BasePart") then table.insert(parts, named) end
	return parts
end

local function isInsidePartAABB(position: Vector3, part: BasePart): boolean
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5
	local yTolerance = 6
	local withinX = math.abs(localPos.X) <= half.X
	local withinZ = math.abs(localPos.Z) <= half.Z
	local withinY = (localPos.Y >= -half.Y) and (localPos.Y <= (half.Y + yTolerance))
	return withinX and withinZ and withinY
end

local function isInsizeAnyGoal(position: Vector3): boolean
	local parts = getGoalParts()
	if #parts == 0 then
		return false
	end
	for _, part in ipairs(parts) do
		if isInsidePartAABB(position, part) then return true end
	end
	return false
end

-- ==========================================================================================================================================
local function safeGetAsync(key)
	for attemps = 1, constant.MAX_RETRIES do
		local success, data = pcall(function()
			return PlayerDatastore:GetAsync(key)
		end)

		if success then
			return data
		else
			warn(string.format("failed to load attempts %d: %s: ", attemps, tostring(data)))
		end
	end

	return nil
end

local function safeSetAsync(key, value)
	for attemps = 1, constant.MAX_RETRIES do
		local success, err = pcall(function()
			PlayerDatastore:SetAsync(key, value)
		end)
		if success then
			return true
		else
			warn(string.format("failed to save attempts %d: %s ", attemps, tostring(err)))
		end
	end

	return false
end

local function savePlayerData(plr)
	if not playerData[plr.UserId] then return end
	local cache = playerData[plr.UserId]
	cache.Inventory = InventoryManager.serialize(plr)
	print(string.format("[Datastore] Saving %s boosts: b2=%s b3=%s", plr.Name, tostring(cache.Boost2Remaining), tostring(cache.Boost3Remaining)))
	local success = safeSetAsync(plr.UserId, cache)
	if not success then
		warn("failed to save to database for ", plr.Name)
	else
		print("Auto-saved success for ", plr.Name)
	end
end


task.spawn(function()
	while true do
		task.wait(constant.AUTO_SAVE)
		for _, player in pairs(Players:GetPlayers()) do
			if playerData[player.UserId] then
				savePlayerData(player)
				print("Auto save success for ", player.Name)
			end
		end
	end
end)


game.Players.PlayerAdded:Connect(function(plr)
	local leaderstats = Instance.new("Folder", plr)
	leaderstats.Name = "leaderstats"

	local walked = Instance.new("NumberValue", leaderstats)
	walked.Name = "Walked"
	walked.Value = 0

	local wins = Instance.new("NumberValue", leaderstats)
	wins.Name = "Wins"
	wins.Value = 0

	local data = safeGetAsync(plr.UserId)

	--Setup cache
	playerData[plr.UserId] = {
		Walked = 0,
		Wins = 0,
		LastPosition = nil,
		Progress = 0, -- for saving progress removeable
		CheckpointsPassed = 0,
		Boost2Remaining = 0,
		Boost3Remaining = 0,
		isEarlyRebirth = false,
		BaseSpeed = nil,
		RebirthCount = 0,
		Inventory = nil,
	}


	if data and type(data) == "table" then
		walked.Value = tonumber(data.Walked) or 0
		wins.Value = tonumber(data.Wins) or 0

		-- Update cache
		playerData[plr.UserId].Walked = walked.Value
		playerData[plr.UserId].Wins = wins.Value
		if data.LastPosition then
			if typeof(data.LastPosition) == "Vector3" then
				playerData[plr.UserId].LastPosition = serializeVector3(data.LastPosition)
			elseif type(data.LastPosition) == "table" then
				playerData[plr.UserId].LastPosition = data.LastPosition
			end
		end
		playerData[plr.UserId].Progress = data.Progress or 0
		playerData[plr.UserId].CheckpointsPassed = data.CheckpointsPassed or 0
		playerData[plr.UserId].Boost2Remaining = data.Boost2Remaining or 0
		playerData[plr.UserId].Boost3Remaining = data.Boost3Remaining or 0
		playerData[plr.UserId].isEarlyRebirth = data.isEarlyRebirth or false
		playerData[plr.UserId].BaseSpeed = data.BaseSpeed or nil
		playerData[plr.UserId].RebirthCount = data.RebirthCount or 0
		
		plr:SetAttribute("CheckpointsPassed", playerData[plr.UserId].CheckpointsPassed)
		plr:SetAttribute("Boost2Remaining", playerData[plr.UserId].Boost2Remaining)
		plr:SetAttribute("Boost3Remaining", playerData[plr.UserId].Boost3Remaining)
		plr:SetAttribute("isEarlyRebirth", playerData[plr.UserId].isEarlyRebirth)
		plr:SetAttribute("BaseSpeed", playerData[plr.UserId].BaseSpeed)
		plr:SetAttribute("RebirthCount", playerData[plr.UserId].RebirthCount)
		
		local step = constant.CHECKPOINT_MULTIPLIER_STEP or 0.25
		local maxMult = constant.CHECKPOINT_MULTIPLIER_MAX or 5.0
		local mult = math.clamp(1 + (playerData[plr.UserId].CheckpointsPassed * step), 1, maxMult)
		plr:SetAttribute("CheckpointSpeedMultiplier", mult)
		-- Apply immediately if character already exists
		local currChar = plr.Character
		if currChar then
			local humNow = currChar:FindFirstChildOfClass("Humanoid") or currChar:FindFirstChild("Humanoid")
			if humNow then
				humNow:SetAttribute("CheckpointSpeedMultiplier", mult)
			end
		end

		-- Initialize and optionally auto-equip saved inventory
		local savedInv = data.Inventory or data.inventory
		local inv = InventoryManager.initPlayer(plr, savedInv)
		playerData[plr.UserId].Inventory = InventoryManager.serialize(plr)
		if inv and inv.equippedDrinkId then
			task.defer(function()
				InventoryManager.equipDrink(plr, inv.equippedDrinkId)
			end)
		end

		local lastPosV3 = deserializeVector3(playerData[plr.UserId].LastPosition)
		if lastPosV3 then

			local targetPos = lastPosV3
			if isInsizeAnyGoal(lastPosV3) then
				local startPart = workspace:FindFirstChild(constant.START_PART_NAME)
				if startPart and startPart:IsA("BasePart") then
					targetPos = startPart.Position + Vector3.new(0, 5, 0)

					playerData[plr.UserId].LastPosition = serializeVector3(targetPos)
				end
			end

			if plr.Character then
				local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.CFrame = CFrame.new(targetPos)
				end
			end

			plr.CharacterAdded:Connect(function(character)
				task.wait(1)
				local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if HumanoidRootPart then
					HumanoidRootPart.CFrame = CFrame.new(targetPos)
				end
			end)
		end

	else
		warn(string.format("No saves found or is corrupted for player : %s", plr.Name))
		-- Ensure inventory is at least initialized empty for new players
		InventoryManager.initPlayer(plr, { items = {}, equippedDrinkId = nil })
		playerData[plr.UserId].Inventory = InventoryManager.serialize(plr)
	end

	walked.Changed:Connect(function(newValue)
		if playerData[plr.UserId] then
			playerData[plr.UserId].Walked = newValue
		end
	end)

	wins.Changed:Connect(function(newValue)
		if playerData[plr.UserId] then
			playerData[plr.UserId].Wins = newValue
		end
	end)
	
	plr:GetAttributeChangedSignal("CheckpointsPassed"):Connect(function()
		local val = tonumber(plr:GetAttribute("CheckpointsPassed")) or 0
		if playerData[plr.UserId] then
			playerData[plr.UserId].CheckpointsPassed = val
		end
	end)
	
	plr:GetAttributeChangedSignal("Boost2Remaining"):Connect(function()
		local val = tonumber(plr:GetAttribute("Boost2Remaining")) or 0
		if playerData[plr.UserId] then
			playerData[plr.UserId].Boost2Remaining = val
		end
	end)
	
	plr:GetAttributeChangedSignal("Boost3Remaining"):Connect(function()
		local val = tonumber(plr:GetAttribute("Boost3Remaining")) or 0
		if playerData[plr.UserId] then
			playerData[plr.UserId].Boost3Remaining = val
		end
	end)
	
	plr:GetAttributeChangedSignal("isEarlyRebirth"):Connect(function()
		local val = plr:GetAttribute("isEarlyRebirth")
		if val ~= nil and playerData[plr.UserId] then
			playerData[plr.UserId].isEarlyRebirth = val
		end
	end)
	
	plr:GetAttributeChangedSignal("BaseSpeed"):Connect(function()
		local val = plr:GetAttribute("BaseSpeed")
		if playerData[plr.UserId] then
			playerData[plr.UserId].BaseSpeed = val
		end
	end)

	plr:GetAttributeChangedSignal("RebirthCount"):Connect(function()
		local val = tonumber(plr:GetAttribute("RebirthCount")) or 0
		if playerData[plr.UserId] then
			playerData[plr.UserId].RebirthCount = val
		end
	end)

	-- Re-apply multiplier to humanoid on spawn
	plr.CharacterAdded:Connect(function(character)
		task.defer(function()
			local hum = character:WaitForChild("Humanoid", 5)
			if hum then
				local passed = tonumber(plr:GetAttribute("CheckpointsPassed")) or 0
				local step = constant.CHECKPOINT_MULTIPLIER_STEP or 0.25
				local maxMult = constant.CHECKPOINT_MULTIPLIER_MAX or 5.0
				local mult = math.clamp(1 + (passed * step), 1, maxMult)
				hum:SetAttribute("CheckpointSpeedMultiplier", mult)
			end
		end)
	end)
end)


--real time stat changing
statUpdateEvent.OnServerEvent:Connect(function(player, statType, value, position)
	if not playerData[player.UserId] then return end


	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	if statType == "Walked" then
		local walkedStat = leaderstats:FindFirstChild("Walked")
		if walkedStat then
			walkedStat.Value = value
			playerData[player.UserId].Walked = value
		end

	elseif statType == "Wins" then
		local winsStat = leaderstats:FindFirstChild("Wins")
		if winsStat then
			winsStat.Value = value
			playerData[player.UserId].Wins = value
		end
	end


	--UPDATE player Position
	if position then
		playerData[player.UserId].LastPosition = serializeVector3(position)
	end
end)


game.Players.PlayerRemoving:Connect(function(plr)

	if not playerData[plr.UserId] then return end

	-- Get current character position before saving
	if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
		playerData[plr.UserId].LastPosition = serializeVector3(plr.Character.HumanoidRootPart.Position)
	end
	
	playerData[plr.UserId].Boost2Remaining = tonumber(plr:GetAttribute("Boost2Remaining")) or playerData[plr.UserId].Boost2Remaining or 0
	playerData[plr.UserId].Boost3Remaining = tonumber(plr:GetAttribute("Boost3Remaining")) or playerData[plr.UserId].Boost3Remaining or 0
	
	local earlyRebirthStatus = plr:GetAttribute("isEarlyRebirth")
	if earlyRebirthStatus ~= nil then
		playerData[plr.UserId].isEarlyRebirth = earlyRebirthStatus
	end
	local baseSpeed = plr:GetAttribute("BaseSpeed")
	if baseSpeed ~= nil then
		playerData[plr.UserId].BaseSpeed = baseSpeed
	end
	local rebirthCount = tonumber(plr:GetAttribute("RebirthCount"))
	if rebirthCount ~= nil then
		playerData[plr.UserId].RebirthCount = rebirthCount
	end
	
	-- Ensure latest inventory is captured on leave
	playerData[plr.UserId].Inventory = InventoryManager.serialize(plr)
	local success = safeSetAsync(plr.UserId, playerData[plr.UserId])
	if not success then
		warn("failed to save to database for ", plr.Name)
	end

	playerData[plr.UserId] = nil
end)

