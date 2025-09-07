--2x speed of base and 3x speed of base players
local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local MarketPlaceService = game:GetService("MarketplaceService")

-- utils
local events = rs:WaitForChild("Events")
local modules = rs:WaitForChild("Modules")
local product = require(modules:WaitForChild("Products"))
local constant = require(rs:WaitForChild("Constants"))


local remaining2ByUser: {[number]: number} = {}
local remaining3ByUser: {[number]: number} = {}

--usage
local PlayerMovementEvent = events:WaitForChild("BaseMovementEvent")
local ThriceMovementSpeed = events:WaitForChild("ThriceMovementEvent")
local displayEffect = events:WaitForChild("DisplayStatus")
local boostAnnounce = events:WaitForChild("BoostServerAnnounce")


local PRODUCT_ID_2MOVEMENT = product.DOUBLE_SPEED
local PRODUCT_ID_3MOVEMENT = product.THRICE_SPEED


--Independent Cooldowns per player
local lastUsedAt2: {[number]: number} = {}
local lastUsedAt3: {[number]: number} = {}

local requestWindow2 = {}
local requestWindow3 = {}

--Receipt per product
local pending2: {[number]: {expiresAt: number}} = {}
local pending3: {[number]: {expiresAt: number}} = {}


local pendingProductByBuyer: {[number]: {expiresAt: number}} = {}


--temporary so adjust when reset is disabled
local baseSpeedByUser: {[number]: number} = {}
local characterAddedConnections: {[number]: RBXScriptConnection} = {}

local getActiveBoosts = events:FindFirstChild("GetActiveBoostsFunction")
if not getActiveBoosts then
	getActiveBoosts = Instance.new("RemoteFunction")
	getActiveBoosts.Name = "GetActiveBoostsFunction"
	getActiveBoosts.Parent = events
end

getActiveBoosts.OnServerInvoke = function(plr)
	local r2 = (remaining2ByUser and remaining2ByUser[plr.UserId]) or 0
	local r3 = (remaining3ByUser and remaining3ByUser[plr.UserId]) or 0
	
	if (r2 == 0 or r2 == nil) then
		r2 = tonumber(plr:GetAttribute("Boost2Remaining")) or 0
	end
	if (r3 == 0 or r3 == nil) then
		r3 = tonumber(plr:GetAttribute("Boost3Remaining")) or 0
	end
	return r2, r3
end

local function nowSec()
	return os.time()
end

local function isActive2For(userId: number)
	local r = remaining2ByUser[userId]
	return type(r) == "number" and r > 0
end

local function isActive3For(userId: number)
	local r = remaining3ByUser[userId]
	return type(r) == "number" and r > 0
end

--addictive multiplier to stack (pls work)
local function currMultiplierFor(userId: number): number
	local mult = 1
	--if isActive2() then mult = mult * 2 end
	--if isActive3() then mult = mult * 3 end
	if isActive2For(userId) then mult *= 2 end
	if isActive3For(userId) then mult *= 3 end
	return mult
end


local function applyToPlayer(p: Player)
	if not p.Character then return end
	local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	--Cache normal walkspeed
	if baseSpeedByUser[p.UserId] == nil then
		baseSpeedByUser[p.UserId] = humanoid.WalkSpeed
	end
	
	local base = baseSpeedByUser[p.UserId] or 16
	local mult = currMultiplierFor(p.UserId)

	humanoid:SetAttribute("ProductSpeedMultiplier", mult > 1 and mult or nil)
	humanoid.WalkSpeed = base * mult
end

local function recomputeAll()
	for _, p in ipairs(Players:GetPlayers()) do
		applyToPlayer(p)
		if not characterAddedConnections[p.UserId] then
			characterAddedConnections[p.UserId] = p.CharacterAdded:Connect(function()
				applyToPlayer(p)				
			end)
		end
	end
end

local function extendBoostFor(userId: number,mult: number, duration: number)
	if mult == 2 then
		remaining2ByUser[userId] = math.max(0, (remaining2ByUser[userId] or 0)) + duration
	elseif mult == 3 then
		remaining3ByUser[userId] = math.max(0, (remaining3ByUser[userId] or 0)) + duration
	end
	
	local p = Players:GetPlayerByUserId(userId)
	if p then
		p:SetAttribute("Boost2Remaining", remaining2ByUser[userId] or 0)
		p:SetAttribute("Boost3Remaining", remaining3ByUser[userId] or 0)
	end
end

local function addBoostToAll(mult: number, duration: number)
	for _, p in ipairs(Players:GetPlayers()) do
		extendBoostFor(p.UserId, mult, duration)
	end
	
	if mult == 2 then
		displayEffect:FireAllClients("2x Speed", duration, "rbxassetid://87808357606141")
		boostAnnounce:FireAllClients("A Player has bought 2x Speed for 5 minutes!")
	elseif mult == 3 then
		displayEffect:FireAllClients("3x Speed", duration, "rbxassetid://140208976440752")
		boostAnnounce:FireAllClients("A Player has bought 3x Speed for 5 minutes!")
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, p in ipairs(Players:GetPlayers()) do
			local uid = p.UserId
			local r2 = remaining2ByUser[uid]
			local r3 = remaining3ByUser[uid]
			local changed = false
			if type(r2) == "number" and r2 > 0 then
				r2 -= 1
				remaining2ByUser[uid] = r2
				p:SetAttribute("Boost2Remaining", r2)
				changed = true
			end
			if type(r3) == "number" and r3 > 0 then
				r3 -= 1
				remaining3ByUser[uid] = r3
				p:SetAttribute("Boost3Remaining", r3)
				changed = true
			end
			if changed then applyToPlayer(p) end
		end
	end
end)

-- Seed per-player timers from datastore-provided
Players.PlayerAdded:Connect(function(p)
	local function resync()
		remaining2ByUser[p.UserId] = tonumber(p:GetAttribute("Boost2Remaining")) or 0
		remaining3ByUser[p.UserId] = tonumber(p:GetAttribute("Boost3Remaining")) or 0
		applyToPlayer(p)
	end
	resync()
	p:GetAttributeChangedSignal("Boost2Remaining"):Connect(function()
		remaining2ByUser[p.UserId] = tonumber(p:GetAttribute("Boost2Remaining")) or 0
		applyToPlayer(p)
	end)
	p:GetAttributeChangedSignal("Boost3Remaining"):Connect(function()
		remaining3ByUser[p.UserId] = tonumber(p:GetAttribute("Boost3Remaining")) or 0
		applyToPlayer(p)
	end)
	-- Send existing effects to UI on join so timers appear
	local r2 = remaining2ByUser[p.UserId] or 0
	local r3 = remaining3ByUser[p.UserId] or 0
	if r2 > 0 then
		print(string.format("[Speed] Send UI 2x to %s with %ds", p.Name, r2))
		displayEffect:FireClient(p, "2x Speed", r2, "rbxassetid://87808357606141")
	end
	if r3 > 0 then
		print(string.format("[Speed] Send UI 3x to %s with %ds", p.Name, r3))
		displayEffect:FireClient(p, "3x Speed", r3, "rbxassetid://140208976440752")
	end
end)

local function canUse2(userId: number): (boolean, number)
	local now = nowSec()
	local last = lastUsedAt2[userId]
	if not last then return true, 0 end
	local remain = constant.COOLDOWN_SECONDS - (now - last)
	if remain > 0 then 
		return false, remain 
	end
	return true, 0
end

local function canUse3(userId: number): (boolean, number)
	local now = nowSec()
	local last = lastUsedAt3[userId]
	if not last then return true, 0 end
	
	local remain = constant.COOLDOWN_SECONDS - (now - last)
	if remain > 0 then 
		return false, remain 
	end
	return true, 0
end

--2x Boost
PlayerMovementEvent.OnServerEvent:Connect(function(buyer: Player)
	local now = nowSec()
	local bucket = requestWindow2[buyer.UserId]
	if not bucket or now - bucket.windowStart > constant.REQUEST_WINDOW_SECONDS then
		requestWindow2[buyer.UserId] = {windowStart = now, count = 1}
	else
		bucket.count += 1
		if bucket.count > constant.MAX_REQUESTS_PER_WINDOW then return end
	end
	
	local allowed, remaining = canUse2(buyer.UserId)
	if not allowed then return end
	
	pending2[buyer.UserId] = {expiresAt = nowSec() + 60}
	if PRODUCT_ID_2MOVEMENT > 0 then
		local ok, err = pcall(function()
			MarketPlaceService:PromptProductPurchase(buyer, PRODUCT_ID_2MOVEMENT)
		end)
		
		if not ok then pending2[buyer.UserId] = nil return end
	else
		--extendBoost(2, constant.SPEED_DURATION)
		addBoostToAll(2, constant.SPEED_DURATION)
		lastUsedAt2[buyer.UserId] = nowSec()
		pending2[buyer.UserId] = nil
	end
end)

if ThriceMovementSpeed then
	ThriceMovementSpeed.OnServerEvent:Connect(function(buyer: Player)
		local now = nowSec()
		local bucket = requestWindow3[buyer.UserId]
		if not bucket or now - bucket.windowStart > constant.REQUEST_WINDOW_SECONDS then
			requestWindow3[buyer.UserId] = {windowStart = now, count = 1}
		else
			bucket.count += 1
			if bucket.count > constant.MAX_REQUESTS_PER_WINDOW then return end
		end
		
		local allowed, remaining = canUse3(buyer.UserId)
		if not allowed then return end
		
		pending3[buyer.UserId] = {expiresAt = nowSec() + 60}
		if PRODUCT_ID_3MOVEMENT > 0 then
			local ok, err = pcall(function()
				MarketPlaceService:PromptProductPurchase(buyer, PRODUCT_ID_3MOVEMENT)
			end)
			
			if not ok then pending3[buyer.user] = nil return end
		else
			addBoostToAll(3, constant.SPEED_DURATION)
			lastUsedAt3[buyer.UserId] = nowSec()
			pending3[buyer.UserId] = nil
		end
	end)
end


local speedReceiptBF = Instance.new("BindableFunction")
speedReceiptBF.Name = "Speed_HandleReceipt"
speedReceiptBF.Parent = rs

speedReceiptBF.OnInvoke = function(receipt)
	local mult
	
	if receipt.ProductId == PRODUCT_ID_2MOVEMENT then
		mult = 2	
	elseif receipt.ProductId == PRODUCT_ID_3MOVEMENT then	
		mult = 3	
	else
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	local buyerUserId = receipt.PlayerId
	local buyer = Players:GetPlayerByUserId(buyerUserId)
	local pending = (mult == 2) and pending2[buyerUserId] or pending3[buyerUserId]
	local ok = false
	
	if buyer and pending and nowSec() <= pending.expiresAt then
		--extendBoost(mult, constant.SPEED_DURATION)
		addBoostToAll(mult, constant.SPEED_DURATION)
		if mult == 2 then 
			lastUsedAt2[buyerUserId] = nowSec()
		else
			lastUsedAt3[buyerUserId] = nowSec()
		end
		ok = true
	end
	if mult == 2 then 
		pending2[buyerUserId] = nil 
	else
		pending3[buyerUserId] = nowSec()
	end
	
	return ok and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(plr)
	requestWindow2[plr.UserId] = nil
	requestWindow3[plr.UserId] = nil
	pending2[plr.UserId] = nil
	pending3[plr.UserId] = nil
	baseSpeedByUser[plr.UserId] = nil
	remaining2ByUser[plr.UserId] = nil
	remaining3ByUser[plr.UserId] = nil
	if characterAddedConnections[plr.UserId] then
		local c = characterAddedConnections[plr.UserId]
		if c.Connected then c:Disconnect() end
		characterAddedConnections[plr.UserId] = nil
	end
end)
