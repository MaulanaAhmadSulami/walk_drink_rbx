local PlayerDatastore = game:GetService("DataStoreService"):GetDataStore("PlayerDataStore")
local rs = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local events = rs:WaitForChild("Events")
local statUpdateEvent = events:WaitForChild("StatsUpdateEvent")

local constant = require(rs:WaitForChild("Constants"))

--local GOAL_TAG = "Goal[Example]"
--local START_PART_NAME = "Start"

--local MAX_RETRIES = 3
--local AUTO_SAVE = 300 --Auto save every 60 seconds
local playerData = {}

-- Helpers
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
		--print("[Datastore] No goal parts found for inside-check")
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
			warn(string.format("[Datastore] failed to load attempts %d: %s: ", attemps, tostring(data)))
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
			warn(string.format("[Datastore] failed to save attempts %d: %s ", attemps, tostring(err)))
		end
	end

	return false
end

local function savePlayerData(plr)
	if not playerData[plr.UserId] then return end
	local cache = playerData[plr.UserId]
	print(string.format("[Datastore] Saving %s boosts: b2=%s b3=%s", plr.Name, tostring(cache.Boost2Remaining), tostring(cache.Boost3Remaining)))
	local success = safeSetAsync(plr.UserId, cache)
	if not success then
		warn("[Datastore] failed to save to database for ", plr.Name)
	else
		print("[Datastore] Auto-saved success for ", plr.Name)
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
	}


	if data and type(data) == "table" then
		walked.Value = tonumber(data.Walked) or 0
		wins.Value = tonumber(data.Wins) or 0

		-- Update cache
		playerData[plr.UserId].Walked = walked.Value
		playerData[plr.UserId].Wins = wins.Value
		-- Normalize LastPosition to a serializable table
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
				--print(string.format("[Datastore] Immediate apply x%.2f for %s (passed=%d)", mult, plr.Name, playerData[plr.UserId].CheckpointsPassed))
			end
		end
		--print(string.format("[Datastore] Restored checkpoints=%d mult=x%.2f for %s", playerData[plr.UserId].CheckpointsPassed, mult, plr.Name))

		-- Save position and teleport them upon rejoining
		local lastPosV3 = deserializeVector3(playerData[plr.UserId].LastPosition)
		if lastPosV3 then

			local targetPos = lastPosV3
			if isInsizeAnyGoal(lastPosV3) then
				local startPart = workspace:FindFirstChild(constant.START_PART_NAME)
				if startPart and startPart:IsA("BasePart") then
					targetPos = startPart.Position + Vector3.new(0, 5, 0)
					--print(string.format("[Datastore] %s saved inside goal; teleporting to Start", plr.Name))

					-- Optional: normalize cache so future saves persist Start instead of goal
					playerData[plr.UserId].LastPosition = serializeVector3(targetPos)
				end
			end

			if plr.Character then
				local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					--hrp.CFrame = CFrame.new(lastPosV3)
					hrp.CFrame = CFrame.new(targetPos)
				end
			end

			plr.CharacterAdded:Connect(function(character)
				task.wait(1)
				local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if HumanoidRootPart then
					--HumanoidRootPart.CFrame = CFrame.new(lastPosV3)
					HumanoidRootPart.CFrame = CFrame.new(targetPos)
				end
			end)
		end

	else
		warn(string.format("No saves found or is corrupted for player : %s", plr.Name))
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

	-- Persist checkpoint count on attribute change
	plr:GetAttributeChangedSignal("CheckpointsPassed"):Connect(function()
		local val = tonumber(plr:GetAttribute("CheckpointsPassed")) or 0
		if playerData[plr.UserId] then
			playerData[plr.UserId].CheckpointsPassed = val
		end
	end)
	
	-- Persist product boost duration remainder on attribute change
	plr:GetAttributeChangedSignal("Boost2Remaining"):Connect(function()
		local val = tonumber(plr:GetAttribute("Boost2Remaining")) or 0
		if playerData[plr.UserId] then
			playerData[plr.UserId].Boost2Remaining = val
			--print(string.format("Datastore %s Boost2Remaining -> %d", plr.Name, val))
		end
	end)
	
	plr:GetAttributeChangedSignal("Boost3Remaining"):Connect(function()
		local val = tonumber(plr:GetAttribute("Boost3Remaining")) or 0
		if playerData[plr.UserId] then
			playerData[plr.UserId].Boost3Remaining = val
			--print(string.format("Datastore %s Boost3Remaining -> %d", plr.Name, val))
		end
	end)
	
	-- Persist early rebirth status on attribute change
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
				print(string.format("[Datastore] Reapplied x%.2f for %s (passed=%d)", mult, plr.Name, passed))
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
	
	-- Copy latest boost attributes just before final save
	playerData[plr.UserId].Boost2Remaining = tonumber(plr:GetAttribute("Boost2Remaining")) or playerData[plr.UserId].Boost2Remaining or 0
	playerData[plr.UserId].Boost3Remaining = tonumber(plr:GetAttribute("Boost3Remaining")) or playerData[plr.UserId].Boost3Remaining or 0
	--print(string.format("[Datastore] Finalizing %s boosts: b2=%d b3=%d", plr.Name, playerData[plr.UserId].Boost2Remaining, playerData[plr.UserId].Boost3Remaining))
	
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
	-- Save final data
	local success = safeSetAsync(plr.UserId, playerData[plr.UserId])
	if not success then
		warn("[Datastore] failed to save to database for ", plr.Name)
	end

	playerData[plr.UserId] = nil
end)
