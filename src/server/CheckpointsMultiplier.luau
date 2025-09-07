local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local rs = game:GetService("ReplicatedStorage")
local constant = require(rs:WaitForChild("Constants"))

--events, utils

local events = rs:WaitForChild("Events")
local checkpointHit = events:WaitForChild("CheckpointHitEvent")
local checkpointReset = events:WaitForChild("CheckpointResetEvent")


-- Attribute names
local ATTR_CHECKPOINT_MULT = "CheckpointSpeedMultiplier"
local ATTR_CHECKPOINTS = "CheckpointsPassed"

local touchedByPart: {[Basepart]: {[number]: boolean}} = {}

-- Utilities
local function getHumanoid(plr: Player): Humanoid?
	local char = plr.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function applyMultiplier(plr: Player, count: number)
	local step = constant.CHECKPOINT_MULTIPLIER_STEP or 0.25
	local base = 1.0 + (count * step)
	local maxMult = constant.CHECKPOINT_MULTIPLIER_MAX or 5.0
	local mult = math.clamp(base, 1.0, maxMult)
	local hum = getHumanoid(plr)
	if hum then
		hum:SetAttribute(ATTR_CHECKPOINT_MULT, mult)
	end
	plr:SetAttribute(ATTR_CHECKPOINT_MULT, mult)
end

-- On entering a checkpoint part (tagged)
local function onTouchedCheckpoint(part: BasePart, hit: BasePart)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then return end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	local plr = Players:GetPlayerFromCharacter(model)
	if not plr then return end
	
	--initialize debounce per part bucket
	touchedByPart[part] = touchedByPart[part] or {}
	local seen = touchedByPart[part]
	if seen[plr.UserId] then return end
	seen[plr.UserId] = true
	
	-- Debounce per part per player using attributes on the part
	local flagName = "Hit_" .. tostring(plr.UserId)
	if part:GetAttribute(flagName) then return end
	part:SetAttribute(flagName, true)

	-- Increment count and apply
	local passed = (plr:GetAttribute(ATTR_CHECKPOINTS) :: number) or 0
	passed += 1
	plr:SetAttribute(ATTR_CHECKPOINTS, passed)
	applyMultiplier(plr, passed)

	-- Notify client to hide this checkpoint visual for the player
	checkpointHit:FireClient(plr, part)
end

-- Hook existing and future tagged parts
local function hookPart(part: Instance)
	if not part:IsA("BasePart") then return end
	if CollectionService:HasTag(part, constant.CHECKPOINT_TAG) then
		part.CanTouch = true
		part.Touched:Connect(function(hit)
			onTouchedCheckpoint(part, hit)
		end)
	end
end

local tagged = CollectionService:GetTagged(constant.CHECKPOINT_TAG)
for _, inst in ipairs(tagged) do
	hookPart(inst)
end
CollectionService:GetInstanceAddedSignal(constant.CHECKPOINT_TAG):Connect(hookPart)

-- support folder-based checkpoints (Workspace.Checkpoints/<number>/Checkpoint<number>)
local function hookFolderCheckpoints()
	local folder = workspace:FindFirstChild("Checkpoints")
	if not folder or not folder:IsA("Folder") then
		print("[Checkpoint] No Workspace.Checkpoints folder found")
		return
	end
	local count = 0
	_G.__OrderedCheckpoints = {}
	local startPart = workspace:FindFirstChild(constant.START_PART_NAME)
	local startPos = startPart and startPart:IsA("BasePart") and startPart.Position or Vector3.new()
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") then
			-- Prefer a BasePart starting with "Checkpoint"
			local cp = child:FindFirstChild("Checkpoint" .. child.Name)
			if not (cp and cp:IsA("BasePart")) then
				for _, inst in ipairs(child:GetChildren()) do
					if inst:IsA("BasePart") and string.find(inst.Name, "^Checkpoint") then
						cp = inst
						break
					end
				end
			end
			if cp and cp:IsA("BasePart") then
				cp.CanTouch = true
				cp.Touched:Connect(function(hit)
					onTouchedCheckpoint(cp :: BasePart, hit)
				end)
				count += 1
				table.insert(_G.__OrderedCheckpoints, cp)
			end
		end
	end
	-- sort by distance from start so indices align with progress order
	table.sort(_G.__OrderedCheckpoints, function(a, b)
		return (a.Position - startPos).Magnitude < (b.Position - startPos).Magnitude
	end)
end

hookFolderCheckpoints()

-- clear all server-side flags for a player so they can trigger again
local function clearServerFlagsForPlayer(plr: Player)
	local uid = plr.UserId
	if type(_G.__OrderedCheckpoints) == "table" then
		for _, cp in ipairs(_G.__OrderedCheckpoints) do
			local flagName = "Hit_" .. tostring(uid)
			if cp and cp:IsA("BasePart") then
				if cp:GetAttribute(flagName) ~= nil then cp:SetAttribute(flagName, nil) end
				if touchedByPart[cp] then touchedByPart[cp][uid] = nil end
			end
		end
	end
end

-- Sync already-passed checkpoints to client on join (hide visuals)
Players.PlayerAdded:Connect(function(plr)
	-- wait for datastore restore
	task.delay(2, function()
		local passed = tonumber(plr:GetAttribute(ATTR_CHECKPOINTS)) or 0
		if passed > 0 and type(_G.__OrderedCheckpoints) == "table" then
			for i = 1, math.min(passed, #_G.__OrderedCheckpoints) do
				local cp = _G.__OrderedCheckpoints[i]
				if cp and cp:IsA("BasePart") then
					checkpointHit:FireClient(plr, cp)
				end
			end
		end
	end)
end)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(plr)
	clearServerFlagsForPlayer(plr)
end)


-- Reset logic when player teleports to Start after victory
local VictoryTeleportEvent = events:FindFirstChild("VictoryTeleportEvent")
if VictoryTeleportEvent and VictoryTeleportEvent:IsA("RemoteEvent") then
	VictoryTeleportEvent.OnServerEvent:Connect(function(plr)
		plr:SetAttribute(ATTR_CHECKPOINTS, 0)
		applyMultiplier(plr, 0)
		clearServerFlagsForPlayer(plr)
		checkpointReset:FireClient(plr)
	end)
end