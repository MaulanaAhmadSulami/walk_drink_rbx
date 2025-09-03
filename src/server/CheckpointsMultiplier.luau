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

-- Debounce table: part -> set(userId)
local touchedByPart: {[BasePart]: {[number]: boolean}} = {}

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

local function onTouchedCheckpoint(part: BasePart, hit: BasePart)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then return end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	local plr = Players:GetPlayerFromCharacter(model)
	if not plr then return end

	-- Init debounce bucket
	touchedByPart[part] = touchedByPart[part] or {}
	local seen = touchedByPart[part]
	if seen[plr.UserId] then return end
	seen[plr.UserId] = true

	local flagName = "Hit_" .. tostring(plr.UserId)
	if part:GetAttribute(flagName) then return end
	part:SetAttribute(flagName, true)

	local passed = (plr:GetAttribute(ATTR_CHECKPOINTS) :: number) or 0
	passed += 1
	plr:SetAttribute(ATTR_CHECKPOINTS, passed)
	applyMultiplier(plr, passed)

	print(string.format("[Checkpoint] %s touched %s → passed=%d chkMult=%.2f",
		plr.Name, part:GetFullName(), passed, (plr:GetAttribute(ATTR_CHECKPOINT_MULT) :: number) or 1))

	checkpointHit:FireClient(plr, part)
end

local function hookPart(part: Instance)
	if not part:IsA("BasePart") then return end
	if CollectionService:HasTag(part, constant.CHECKPOINT_TAG) then
		part.CanTouch = true
		part.Touched:Connect(function(hit)
			onTouchedCheckpoint(part, hit)
		end)
		print("[Checkpoint] Hooked tagged part:", part:GetFullName())
	end
end

local tagged = CollectionService:GetTagged(constant.CHECKPOINT_TAG)
for _, inst in ipairs(tagged) do
	hookPart(inst)
end
print(string.format("[Checkpoint] Tagged parts found: %d", #tagged))
CollectionService:GetInstanceAddedSignal(constant.CHECKPOINT_TAG):Connect(hookPart)

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
				print("[Checkpoint] Hooked folder checkpoint:", cp:GetFullName())
			end
		end
	end
	table.sort(_G.__OrderedCheckpoints, function(a, b)
		return (a.Position - startPos).Magnitude < (b.Position - startPos).Magnitude
	end)
	print(string.format("[Checkpoint] Folder checkpoints hooked: %d", count))
end

hookFolderCheckpoints()

-- Helper: clear all server-side flags for a player so they can trigger again
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

Players.PlayerAdded:Connect(function(plr)
	task.delay(2, function()
		local passed = tonumber(plr:GetAttribute(ATTR_CHECKPOINTS)) or 0
		print(string.format("[Checkpoint] Sync for %s passed=%d", plr.Name, passed))
		if passed > 0 and type(_G.__OrderedCheckpoints) == "table" then
			for i = 1, math.min(passed, #_G.__OrderedCheckpoints) do
				local cp = _G.__OrderedCheckpoints[i]
				if cp and cp:IsA("BasePart") then
					checkpointHit:FireClient(plr, cp)
					print(string.format("[Checkpoint] Sync hide → %s", cp:GetFullName()))
				end
			end
		end
	end)
end)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(plr)
	clearServerFlagsForPlayer(plr)
end)

local VictoryTeleportEvent = events:FindFirstChild("VictoryTeleportEvent")
if VictoryTeleportEvent and VictoryTeleportEvent:IsA("RemoteEvent") then
	VictoryTeleportEvent.OnServerEvent:Connect(function(plr)
		plr:SetAttribute(ATTR_CHECKPOINTS, 0)
		applyMultiplier(plr, 0)
		clearServerFlagsForPlayer(plr)
		checkpointReset:FireClient(plr)
		print(string.format("[Checkpoint] Reset visuals & flags for %s after victory", plr.Name))
	end)
end