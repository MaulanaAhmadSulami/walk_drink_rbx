local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local DatastoreService = game:GetService("DataStoreService")
local Marketplaceservice = game:GetService("MarketplaceService")

local module = rs:WaitForChild("Modules")
local constant = require(rs:WaitForChild("Constants"))
local product = require(module:WaitForChild("Products"))
--local GOAL_TAG = "Goal[Example]"
--local START_PART = "StartPartStarting"

local events = rs:WaitForChild("Events")
local GoalReached = events:WaitForChild("GoalReachedEvent")
local VictoryTeleportEvent = events:WaitForChild("VictoryTeleportEvent")


-- UI

-- References
local StartSpawn = workspace:WaitForChild("Start") :: BasePart

local inside: {[Player]: boolean} = {}
local touchCounters: {[BasePart]: {[Player]: number}} = {}
local hookedParts: {[BasePart]: boolean} = {}
local isOwnGamepass: {[number]: number} = {}

local winsPassCheck = events:FindFirstChild("DoubleWinPassEvent")
if not winsPassCheck then
	winsPassCheck = Instance.new("RemoteEvent")
	winsPassCheck.Name = "DoubleWinPassEvent"
	winsPassCheck.Parent = events
end

-- Helpers

local function checkOwnership(p: Player)
	local id = product.DOUBLE_COMPLETION
	if type(id) ~= "number" or id <= 0 then
		isOwnGamepass[p.UserId] = false
		return
	end
	
	local ok, owns = pcall(Marketplaceservice.UserOwnsGamePassAsync, Marketplaceservice, p.UserId, id)
	isOwnGamepass[p.UserId] = (ok and owns == true)
	if ok then
		if owns then
			print(p.Name .. " owns double win gamepass")
		else
			print(p.Name .. " does not own the double wins gamepass")
		end
	else
		warn("Ownership check error for ", p.Name)
	end
end

local function getWinsObject(plr: Player): NumberValue?
	local ls = plr:FindFirstChild("leaderstats") or plr:FindFirstChildOfClass("Folder")
	if not ls then return nil end
	
	local wins = ls:FindFirstChild("Wins")
	if wins and wins:IsA("NumberValue") then
		return wins
	end
	
	return nil
end


local function awardWin(plr: Player)
	local wins = getWinsObject(plr)
	if wins then
		local before = wins.Value
		if isOwnGamepass[plr.UserId] then
			wins.Value += 2
		else
			wins.Value += 1
		end
	end
end


--Flag
local function stillTouchingAnyZone(plr: Player): boolean
	for _, counters in pairs(touchCounters) do
		if counters[plr] and counters[plr] > 0 then
			return true
		end
	end
	
	return false
end


local function forceLeave(plr: Player)
	for _, counters in pairs(touchCounters) do
		if counters[plr] then
			counters[plr] = nil
		end
	end
	
	inside[plr] = nil
	plr:SetAttribute("InGoal", false)
end


local function tryEnterZone(plr: Player)
	if inside[plr] then return end
	inside[plr] = true
	plr:SetAttribute("InGoal", true)
	
	--Flag players INSIDE the part
	task.delay(constant.DWELL_TIME, function()
		if not inside[plr] then return end
		
		--flag with UI
		if not plr:GetAttribute("VictoryActive") then
			plr:SetAttribute("VictoryActive", true)
			GoalReached:FireClient(plr)
		end
	end)
end

local function leaveZone(plr: Player)
	if not inside[plr] then return end
	inside[plr] = nil
	
	plr:SetAttribute("InGoal", false)
	--print(string.format("[Goal] %s left goal zone", plr.Name))
end

-- Hook all parts with GoalZone Tag
local function HookZonePart(part: BasePart)
	if hookedParts[part] then return end
	hookedParts[part] = true
	--print(string.format("[Goal] Hooking goal part: %s", part:GetFullName()))
	
	part.CanTouch = true
	touchCounters[part] = {}
	
	part.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character or not character:FindFirstChildOfClass("Humanoid") then return end
		local plr = Players:GetPlayerFromCharacter(character)
		if not plr then return end
		
		local counter = touchCounters[part]
		counter[plr] = (counter[plr] or 0) + 1
		--print(string.format("[Goal] Touched %s (count=%d) on %s", plr.Name, counter[plr], part.Name))
		tryEnterZone(plr)
	end)
	
	
	part.TouchEnded:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		
		local plr = Players:GetPlayerFromCharacter(character)
		if not plr then return end
		
		local counter = touchCounters[part]
		counter[plr] = math.max(0, (counter[plr] or 1) - 1)
		--print(string.format("[Goal] TouchEnded %s (count=%d) on %s", plr.Name, counter[plr], part.Name))
		
		if not stillTouchingAnyZone(plr) then
			leaveZone(plr)
		end
	end)
	
	
	-- Initial overlap detection: if players are already inside the part when hooked, count them
	local half = part.Size * 0.5
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local localPos = part.CFrame:PointToObjectSpace(root.Position)
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				local counter = touchCounters[part]
				counter[plr] = (counter[plr] or 0) + 1
				--print(string.format("[Goal] %s already inside %s at hook time", plr.Name, part.Name))
				tryEnterZone(plr)
			end
		end
	end
end


for _, inst in ipairs(CollectionService:GetTagged(constant.GOAL_TAG)) do
	if inst:IsA("BasePart") then
		HookZonePart(inst)
	end
end

-- hook by name if a part is named like the tag
local namedGoal = workspace:FindFirstChild(constant.GOAL_TAG)
if namedGoal and namedGoal:IsA("BasePart") then
	HookZonePart(namedGoal)
end

CollectionService:GetInstanceAddedSignal(constant.GOAL_TAG):Connect(function(inst)
	if inst:IsA("BasePart") then
		HookZonePart(inst)
	end
end)


workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("BasePart") and inst.Name == constant.GOAL_TAG then
		HookZonePart(inst)
	end
end)

-- Players lifecycle
Players.PlayerAdded:Connect(function(plr)
	plr:SetAttribute("InGoal", false)
	plr:SetAttribute("VictoryActive", false)
	
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		
		-- clear upon respawn or death (this shouldnt be possible since reset btn is disabled but safety)
		plr:SetAttribute("VictoryActive", false)
		forceLeave(plr)
		
		hum.Died:Connect(function()
			forceLeave(plr)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	forceLeave(plr)
end)

winsPassCheck.OnServerEvent:Connect(function(p)
	if Marketplaceservice:UserOwnsGamePassAsync(p.UserId, product.DOUBLE_COMPLETION) then
		isOwnGamepass[p.UserId] = true
		checkOwnership(p)
	end
end)

Marketplaceservice.PromptGamePassPurchaseFinished:Connect(function(p, gamePassId, wasPurchased)
	local id = product.DOUBLE_COMPLETION
	if p and type(id) == "number" and id > 0 and gamePassId == id and wasPurchased then
		isOwnGamepass[p.UserId] = true
		print(p.Name .. " purchase of gamepass confirmed")
	end
end)


VictoryTeleportEvent.OnServerEvent:Connect(function(plr)
	
	
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not(char and hum and root and StartSpawn) then return end
	
	local victoryAtr = plr:GetAttribute("VictoryActive")
	
	if victoryAtr == true then
		awardWin(plr)
	end
	
	
	forceLeave(plr)
	plr:SetAttribute("VictoryActive", false)
	
	--reset phsyics
	hum.Sit = false
	hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	
	--tp players
	local pos = StartSpawn.Position + Vector3.new(0, 5, 0)
	local look = StartSpawn.CFrame.LookVector
	char:PivotTo(CFrame.new(pos, pos + look))
end)