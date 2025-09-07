-- Just set everybody walkspeed to 0
local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local MarketPlaceService = game:GetService("MarketplaceService")
local Module = rs:WaitForChild("Modules")
local Products = require(Module:WaitForChild("Products"))
local archive = rs:WaitForChild("Archive")
local iceBlock = archive:WaitForChild("Frozen")
local constant = require(rs:WaitForChild("Constants"))


--get remotes
local events = rs:WaitForChild("Events")
local FreezeAllEvent = events:WaitForChild("FreezeAllEvent")
local displayEffect = events:WaitForChild("DisplayStatus")
local serverAnnouncementEvent = events:WaitForChild("ServerAnnouncement")


local PRODUCT_ID_FREEZE = Products.FREEZE -- change later


local lastUsedAt: {[number]: number} = {}
local requestWindow = {}
local pendingFreezeByBuyer: {[number]: {expiresAt: number}} = {}

-- Runtime freeze tracking to handle respawns during freeze window (just disable reset later)
local activeFreezeUntil: number? = nil
local frozenUserIdToOrigSpeed: {[number]: number} = {}
local frozenUserIdToOrigAnchored: {[number]: boolean} = {}
local characterAddedConnections: {[number]: RBXScriptConnection} = {}

local function isFreezeActive(): boolean
	return activeFreezeUntil ~= nil and (os.time() < (activeFreezeUntil :: number))
end

local function applyFreezeToPlayer(plr: Player)
	if plr == nil or plr.Character == nil then return end
	local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if frozenUserIdToOrigSpeed[plr.UserId] == nil then
		frozenUserIdToOrigSpeed[plr.UserId] = humanoid.WalkSpeed
	end
	
	humanoid.WalkSpeed = 0
	
	--Anchor root to prevent thirst from overriding
	local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
	if hrp and frozenUserIdToOrigAnchored[plr.UserId] == nil then
		frozenUserIdToOrigAnchored[plr.UserId] = hrp.Anchored
	end
	if hrp then
		local block = iceBlock:Clone()
		block.CFrame = hrp.CFrame
		block.Parent = hrp
		
		local weldConst = Instance.new("WeldConstraint")
		weldConst.Parent = block
		weldConst.Part0 = block
		weldConst.Part1 = hrp
		hrp.Anchored = true
	end
end

local function unfreezeAll()
	for userId, speed in pairs(frozenUserIdToOrigSpeed) do
		local p = Players:GetPlayerByUserId(userId)
		if p and p.Character then
			local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
			local checkhrp = p.Character:WaitForChild("HumanoidRootPart")
			local block = checkhrp:WaitForChild("Frozen")
			
			if block and block.Parent then
				block:Destroy()
			end
			
			if humanoid then
				humanoid.WalkSpeed = speed
				humanoid.JumpPower = 50
			end
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and frozenUserIdToOrigAnchored[userId] ~= nil then
				hrp.Anchored = frozenUserIdToOrigAnchored[userId]
			end
		end
	end
	
	frozenUserIdToOrigSpeed = {}
	frozenUserIdToOrigAnchored = {}
	for userId, conn in pairs(characterAddedConnections) do
		if conn.Connected then conn:Disconnect() end
		characterAddedConnections[userId] = nil
	end
	activeFreezeUntil = nil
end

local function performFreezeAll(excludePlayer : Player): boolean
	-- Global freeze window
	activeFreezeUntil = os.time() + constant.FREEZE_DURATION
	
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= excludePlayer then
			applyFreezeToPlayer(plr)
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.JumpPower = 0 end
			--Keep them frozen on respawn during the window (for now)
			if not characterAddedConnections[plr.UserId] then
				characterAddedConnections[plr.UserId] = plr.CharacterAdded:Connect(function()
					if isFreezeActive() then
						applyFreezeToPlayer(plr)
						local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
						if h then h.JumpPower = 0 end
					end
				end)
			end
		end
	end
	
	--Schedule freezenya
	task.delay(constant.FREEZE_DURATION, function()
		unfreezeAll()
	end)
	
	return true
end


local function canUseFreeze(userId: number): (boolean, number)
	local last = lastUsedAt[userId]
	if not last then return true, 0 end
	local now = os.time()
	local remaining = constant.COOLDOWN_SECONDS - (now - last)
	if remaining > 0 then
		return false, remaining
	end
	
	return true, 0
end

FreezeAllEvent.OnServerEvent:Connect(function(buyer: Player)
	local now = os.time()
	local bucket = requestWindow[buyer.UserId]
	if not bucket or now - bucket.windowStart > constant.REQUEST_WINDOW_SECONDS then
		requestWindow[buyer.UserId] = {windowStart = now, count = 1}
	else
		bucket.count += 1
		if bucket.count > constant.MAX_REQUESTS_PER_WINDOW then
			return 
		end
	end
	
	
	-- Cooldown
	local allowed, remaining = canUseFreeze(buyer.UserId)
	if not allowed then 
		return 
	end
	
	-- Save pending
	pendingFreezeByBuyer[buyer.UserId] = {expiresAt = os.time() + 60}
	
	if PRODUCT_ID_FREEZE > 0 then
		local ok, err = pcall(function()
			MarketPlaceService:PromptProductPurchase(buyer, PRODUCT_ID_FREEZE)
		end)
		if not ok then
			pendingFreezeByBuyer[buyer.UserId] = nil
			return
		end
	else
		--testing env
		if performFreezeAll(buyer) then
			lastUsedAt[buyer.UserId] = os.time()
		end
		pendingFreezeByBuyer[buyer.UserId] = nil
	end
end)

-- purchase fulfillment
local freezeReceiptBF = Instance.new("BindableFunction")
freezeReceiptBF.Name = "Freeze_HandleReceipt"
freezeReceiptBF.Parent = rs

freezeReceiptBF.OnInvoke = function(receipt)
	if receipt.ProductId ~= PRODUCT_ID_FREEZE then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	local buyerUserId = receipt.PlayerId
	local buyer = Players:GetPlayerByUserId(buyerUserId)
	local pending = pendingFreezeByBuyer[buyerUserId]
	local ok = false
	if buyer and pending and os.time() <= pending.expiresAt then
		ok = performFreezeAll(buyer)
	end
	
	pendingFreezeByBuyer[buyerUserId] = nil
	if buyer then
		if ok then
			serverAnnouncementEvent:FireAllClients(buyer.Name .. " has purchased freeze all (1minute)")
			displayEffect:FireAllClients("Freeze All", 60, "rbxassetid://115673118749377")
			lastUsedAt[buyerUserId] = os.time()
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(plr)
	requestWindow[plr.UserId] = nil
	pendingFreezeByBuyer[plr.UserId] = nil
	if characterAddedConnections[plr.UserId] then
		local c = characterAddedConnections[plr.UserId]
		if c.Connected then c:Disconnect() end
		characterAddedConnections[plr.UserId] = nil
	end
	frozenUserIdToOrigSpeed[plr.UserId] = nil
end)