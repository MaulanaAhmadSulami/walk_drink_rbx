local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local rs = game:GetService("ReplicatedStorage")
local constant = require(rs:WaitForChild("Constants"))
local products = require(rs:WaitForChild("Modules"):WaitForChild("Products"))
local MarketplaceService = game:GetService("MarketplaceService")
local events = rs:WaitForChild("Events")

local thirstUpdate = events:FindFirstChild("ThirstUpdateEvent")
if not thirstUpdate then
	thirstUpdate = Instance.new("RemoteEvent")
	thirstUpdate.Name = "ThirstUpdateEvent"
	thirstUpdate.Parent = events
end

local thirstPassCheck = events:FindFirstChild("ThirstPassCheckEvent")
if not thirstPassCheck then
	thirstPassCheck = Instance.new("RemoteEvent")
	thirstPassCheck.Name = "ThirstPassCheckEvent"
	thirstPassCheck.Parent = events
end

local thirstByUser: {[number]: number} = {}
local lastMoveAt: {[number]: number} = {}
local drainAccum: {[number]: number} = {}
local isOwnThirstPass: {[number]: boolean} = {}
local lastSentPercentAt: {[number]: number} = {}
local lastSentPercent: {[number]: number} = {}

local function getHumanoid(p: Player): Humanoid?
	local char = p.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function isRootAnchored(p: Player): boolean
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return (hrp and hrp.Anchored) == true
end

local function recomputeSpeed(p: Player)
	local hum = getHumanoid(p)
	if not hum then return end
	if isRootAnchored(p) then return end
	local product = hum:GetAttribute("ProductSpeedMultiplier") or p:GetAttribute("ProductSpeedMultiplier") or 1
	local checkpoint = hum:GetAttribute("CheckpointSpeedMultiplier") or p:GetAttribute("CheckpointSpeedMultiplier") or 1
	local mult = 1
	if typeof(product) == "number" then mult *= product end
	if typeof(checkpoint) == "number" then mult *= checkpoint end
	local thirst = thirstByUser[p.UserId] or constant.INITIAL_THIRST
	
	local baseSpeed = p:GetAttribute("BaseSpeed") or constant.NORMAL_WALKSPEED
	
	if thirst <= 0 then
		hum.WalkSpeed = constant.EXHAUSTED_WALKSPEED
	else
		hum.WalkSpeed = baseSpeed * mult
	end
end

local function sendPercentIfNeeded(p: Player)
	local now = os.clock()
	local lastAt = lastSentPercentAt[p.UserId] or 0
	if (now - lastAt) < 0.2 then return end
	local curr = thirstByUser[p.UserId] or constant.INITIAL_THIRST
	local percent = math.clamp(curr / constant.MAX_THIRST, 0, 1)
	if lastSentPercent[p.UserId] ~= percent then
		thirstUpdate:FireClient(p, percent)
		lastSentPercent[p.UserId] = percent
		lastSentPercentAt[p.UserId] = now
	end
end

local function checkOwnership(p: Player)
	local id = products.LESS_THIRST
	if type(id) ~= "number" or id <= 0 then
		isOwnThirstPass[p.UserId] = false
		return
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, p.UserId, id)
	isOwnThirstPass[p.UserId] = (ok and owns == true)
	if not ok then
		warn("Ownership check errored for", p.Name)
	end
end

local function seedPlayer(p: Player)
	thirstByUser[p.UserId] = constant.INITIAL_THIRST
	lastMoveAt[p.UserId] = os.clock()
	drainAccum[p.UserId] = 0
	task.spawn(function()
		checkOwnership(p)
	end)
	if not p.Character then return end
	recomputeSpeed(p)
	sendPercentIfNeeded(p)
end

Players.PlayerAdded:Connect(function(p)
	seedPlayer(p)
	p.CharacterAdded:Connect(function()
		seedPlayer(p)
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	thirstByUser[p.UserId] = nil
	lastMoveAt[p.UserId] = nil
	drainAccum[p.UserId] = nil
	isOwnThirstPass[p.UserId] = nil
	lastSentPercent[p.UserId] = nil
	lastSentPercentAt[p.UserId] = nil
end)

thirstPassCheck.OnServerEvent:Connect(function(p)
	if MarketplaceService:UserOwnsGamePassAsync(p.UserId, products.LESS_THIRST) then
		isOwnThirstPass[p.UserId] = true
		checkOwnership(p)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, gamePassId, wasPurchased)
	local id = products.LESS_THIRST
	if p and type(id) == "number" and id > 0 and gamePassId == id and wasPurchased then
		isOwnThirstPass[p.UserId] = true
		print(p.Name .. " purchases of gamepass confirmed")
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for _, p in ipairs(Players:GetPlayers()) do
		local hum = getHumanoid(p)
		if not hum then continue end
		if isRootAnchored(p) then
			lastMoveAt[p.UserId] = os.clock()
			drainAccum[p.UserId] = 0
			sendPercentIfNeeded(p)
			continue
		end
		local moving = hum.MoveDirection.Magnitude > 0
		local thirst = thirstByUser[p.UserId] or constant.INITIAL_THIRST
		local interval = (isOwnThirstPass[p.UserId] and (constant.DRAIN_INTERVAL_GAMEPASS or constant.DRAIN_INTERVAL)) or constant.DRAIN_INTERVAL
		if moving then
			drainAccum[p.UserId] = (drainAccum[p.UserId] or 0) + dt
			while drainAccum[p.UserId] >= interval and thirst > 0 do
				thirst = math.max(0, thirst - 1)
				drainAccum[p.UserId] -= interval
			end
			lastMoveAt[p.UserId] = os.clock()
		else
			drainAccum[p.UserId] = 0
			if os.clock() - (lastMoveAt[p.UserId] or 0) >= constant.RESTORE_DELAY and thirst < constant.MAX_THIRST then
				thirst = math.min(constant.MAX_THIRST, thirst + constant.REGEN_RATE * dt)
			end
		end
		thirstByUser[p.UserId] = thirst
		recomputeSpeed(p)
		sendPercentIfNeeded(p)
	end
end)