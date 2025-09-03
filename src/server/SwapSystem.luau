local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local MarketPlaceService = game:GetService("MarketplaceService")

local events = rs:WaitForChild("Events")
local module = rs:WaitForChild("Modules")
local Products = require(module:WaitForChild("Products"))
local constant = require(rs:WaitForChild("Constants"))


--get remotes
local swapByUsernameEvent = events:FindFirstChild("SwapByUsernameEvent")
--local swapFeedbackEvent = events:FindFirstChild("SwapFeedbackEvent")
local serverAnnounceEvent = events:FindFirstChild("ServerAnnouncement")

local PRODUCT_ID_SWAP = Products.SWAP -- change later
--local REQUEST_WINDOW_SECONDS = 3
--local COOLDOWN_SECONDS = 60
--local MAX_REQUESTS_PER_WINDOW = 3
local pendingByBuyerUserId: {[number]: {targetUserId: number, expiresAt: number}} = {}
local lastUsedAt: {[number]: number} = {}
local requestWindow = {}

--clean up after player leaving
Players.PlayerRemoving:Connect(function(plr)
	pendingByBuyerUserId[plr.UserId] = nil
	requestWindow[plr.UserId] = nil
end)

local function findPlayerByNameInsensitive(nameText: string): Player?
	if not nameText or nameText == "" then return nil end
	local lower = string.lower(nameText)
	for _, plr in ipairs(Players:GetPlayers()) do
		if string.lower(plr.Name) == lower or string.lower(plr.DisplayName) == lower then
			return plr
		end
	end
	
	return nil
end

local function addForceField(character: Model)
	local existing = character:FindFirstChildOfClass("ForceField")
	if existing then return end
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = character
	task.delay(2, function()
		if ff.Parent then ff:Destroy() end
	end)
end

local function performSwap(playerA : Player, playerB : Player): boolean
	local charA = playerA and playerA.Character
	local charB = playerB and playerB.Character
	
	if not (charA and charB) then return false end
	
	if playerA:GetAttribute("VictoryActive") == true then
		print("Cant swap with player who have finished the run")
		return false
	end
	if playerB:GetAttribute("VictoryActive") == true then
		print("Cant swap with player who have finished the run")
		return false
	end
	
	local hrpA = charA:FindFirstChild("HumanoidRootPart")
	local hrpB = charB:FindFirstChild("HumanoidRootPart")
	local humA = charA:FindFirstChildOfClass("Humanoid")
	local humB = charB:FindFirstChildOfClass("Humanoid")
	
	if not (hrpA and hrpB and humA and humB) then return false end
	if humA.Health <= 0 or humB.Health <= 0 then return false end
	if not charA.Parent or not charB.Parent then return false end
	if hrpA.Anchored or hrpB.Anchored then return false end
	
	--Make sure they are not seated or anything (HINDARI ANCHOR)
	humA.Sit = false
	humB.Sit = false
	
	local pivotA = charA:GetPivot()
	local pivotB = charB:GetPivot()
	-- idk if this works bro fuck it
	local velA = hrpA.AssemblyLinearVelocity
	local velB = hrpB.AssemblyLinearVelocity
	
	
	charA:PivotTo(pivotB)
	charB:PivotTo(pivotA)
	
	hrpA.AssemblyLinearVelocity = velB
	hrpB.AssemblyLinearVelocity = velA
	hrpA.AssemblyAngularVelocity = Vector3.zero
	hrpB.AssemblyAngularVelocity = Vector3.zero
	
	addForceField(charA)
	addForceField(charB)
	
	return true
end

local function canUseSwap(userId: number): (boolean, number)
	local last = lastUsedAt[userId]
	if not last then return true, 0 end
	local now = os.time()
	local remaining = constant.COOLDOWN_SECONDS - (now - last)
	if remaining > 0 then
		return false, remaining
	end
	
	return true, 0
end

-- Client -> Server : username intent flow
swapByUsernameEvent.OnServerEvent:Connect(function(buyer: Player, nameText: string)
	if typeof(nameText) ~= "string" then return end

	-- Trim and constrain input
	nameText = string.gsub(nameText, "^%s*(.-)%s*$", "%1")
	if #nameText == 0 then return end
	nameText = string.sub(nameText, 1, 50)

	-- Basic spam throttle per short window
	local now = os.time()
	local bucket = requestWindow[buyer.UserId]
	if not bucket or now - bucket.windowStart > constant.REQUEST_WINDOW_SECONDS then
		requestWindow[buyer.UserId] = { windowStart = now, count = 1 }
	else
		bucket.count += 1
		if bucket.count > constant.MAX_REQUESTS_PER_WINDOW then
			return
		end
	end

	local allowed, remaining = canUseSwap(buyer.UserId)
	if not allowed then
		return
	end

	local target = findPlayerByNameInsensitive(nameText)
	if not target then
		return
	end
	if target == buyer then
		return
	end
	
	--Victory Active validation before proceeding to receipt check
	if buyer:GetAttribute("VictoryActive") == true then
		print(string.format("[Swap] Buyer %s blocked: VictoryActive", buyer.Name))
		return
	end
	if target:GetAttribute("VictoryActive") == true then
		print(string.format("[Swap] Buyer %s blocked: VictoryActive", buyer.Name))
		return
	end
	

	-- Clear expired pending then save new pending intent
	local existing = pendingByBuyerUserId[buyer.UserId]
	if existing and now > existing.expiresAt then
		pendingByBuyerUserId[buyer.UserId] = nil
	end

	-- Save pending for purchase fulfillment
	pendingByBuyerUserId[buyer.UserId] = {
		targetUserId = target.UserId,
		expiresAt = os.time() + 60,
	}

	if PRODUCT_ID_SWAP > 0 then
		local ok, err = pcall(function()
			MarketPlaceService:PromptProductPurchase(buyer, PRODUCT_ID_SWAP)
		end)
		
		if ok then
			--swapFeedbackEvent:FireClient(buyer, "Confirm the purchase to swap troll")
		else
			pendingByBuyerUserId[buyer.UserId] = nil
		end
	else
		-- Testing mode: perform immediately
		local ok = performSwap(buyer, target)
		if ok then
			lastUsedAt[buyer.UserId] = os.time()
		end
		pendingByBuyerUserId[buyer.UserId] = nil
	end
end)

-- purchase fulfillment
local swapReceiptBF = Instance.new("BindableFunction")
swapReceiptBF.Name = "Swap_HandleReceipt"
swapReceiptBF.Parent = rs

swapReceiptBF.OnInvoke = function(receipt)
	if receipt.ProductId ~= PRODUCT_ID_SWAP then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local buyerUserId = receipt.PlayerId
	local buyer = Players:GetPlayerByUserId(buyerUserId)
	local pending = pendingByBuyerUserId[buyerUserId]
	local ok = false
	if buyer and pending and os.time() <= pending.expiresAt then
		local target = Players:GetPlayerByUserId(pending.targetUserId)
		if target then
			-- VictoryActive validation on fulfillment path
			if buyer:GetAttribute("VictoryActive") == true then
				print(string.format("[Swap] Buyer %s blocked: VictoryActive", buyer.Name))
				ok = false
			elseif target:GetAttribute("VictoryActive") == true then
				print(string.format("[Swap] Buyer %s blocked: VictoryActive", buyer.Name))
				ok = false
			else
				ok = performSwap(buyer, target)
			end			
		end
	end
	pendingByBuyerUserId[buyerUserId] = nil
	if buyer then
		if ok then
			lastUsedAt[buyerUserId] = os.time()
			serverAnnounceEvent:FireAllClients(buyer.Name .. " has swapped distance with " .. Players:GetNameFromUserIdAsync(pending and pending.targetUserId or 0) or "?") -- Make a new popup instance and fire it to all clients
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end