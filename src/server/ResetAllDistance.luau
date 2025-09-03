local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local MarketPlaceService = game:GetService("MarketplaceService")
local Module = rs:WaitForChild("Modules")
local Products = require(Module:WaitForChild("Products"))
local constant = require(rs:WaitForChild("Constants"))
-- get remotes
local events = rs:WaitForChild("Events")
local ResetAllDistEvent = events:WaitForChild("ResetDistanceEvent")
local displayEffect = events:WaitForChild("DisplayStatus")
local serverAnnouncementEvent = events:WaitForChild("ServerAnnouncement")


local PRODUCT_ID_RESET = Products.RESET_DIST

local lastUsedAt: {[number]: number} = {}
local requestWindow = {}
local pendingByBuyer: {[number]: {expiresAt: number}} = {}

local characterAddedConnections: {[number]: RBXScriptConnection} = {}

local function nowSec()
	return os.time()
end

local function canUse(userId: number): (boolean, number)
	local last = lastUsedAt[userId]
	if not last then return true, 0 end
	local remain = constant.COOLDOWN_SECONDS - (nowSec() - last)
	if remain > 0 then return false, remain end
	return true, 0
end

local function getStartSpawn(): BasePart?
	local s = workspace:FindFirstChild(constant.START_PART_NAME)
	if s and s:IsA("BasePart") then return s end
	return nil
end

local function resetOne(player: Player, startSpawn: BasePart)
	local char = player.Character
	if not char then print("ResetDistance: skip", player.Name, "no character") return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then print("ResetDistance: skip", player.Name, "no humanoid/root") return end
	-- reset physics
	hum.Sit = false
	hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	-- target cframe
	local pos = startSpawn.Position + Vector3.new(0, 5, 0)
	local look = startSpawn.CFrame.LookVector
	char:PivotTo(CFrame.new(pos, pos + look))
	-- reset leaderstats Walked if present
	local ls = player:FindFirstChild("leaderstats")
	local walked = ls and ls:FindFirstChild("Walked")
	if walked and walked:IsA("NumberValue") then
		walked.Value = 0
	end
	print("ResetDistance: teleported", player.Name, "to start")
end

local function resetAllDistance(buyer: Player)
	local startSpawn = getStartSpawn()
	if not startSpawn then print("ResetDistance: Start part not found:", tostring(constant.START_PART_NAME)) return end
	print("ResetDistance: running, buyer:", buyer and buyer.Name or "?", "start:", startSpawn:GetFullName())
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == buyer then
			print("ResetDistance: skip buyer", plr.Name)
		elseif plr:GetAttribute("VictoryActive") == true then
			print("ResetDistance: skip victory", plr.Name)
		else
			resetOne(plr, startSpawn)
			if displayEffect then
				displayEffect:FireClient(plr, "Reset to start", 3, "rbxassetid://14142131512")
			end
		end
	end
	if serverAnnouncementEvent then
		serverAnnouncementEvent:FireAllClients((buyer and buyer.Name or "A player") .. " has reset everyone's distance!")
	end
end

ResetAllDistEvent.OnServerEvent:Connect(function(buyer: Player)
	print("ResetDistance: request from", buyer and buyer.Name or "?")
	local now = nowSec()
	local bucket = requestWindow[buyer.UserId]
	if not bucket or now - (bucket.windowStart or 0) > constant.REQUEST_WINDOW_SECONDS then
		requestWindow[buyer.UserId] = { windowStart = now, count = 1}
	else
		bucket.count += 1
		if bucket.count > constant.MAX_REQUESTS_PER_WINDOW then print("ResetDistance: throttled", buyer.Name) return end
	end
	local allowed, remaining = canUse(buyer.UserId)
	if not allowed then print("ResetDistance: cooldown", buyer.Name, remaining .. "s left") return end
	pendingByBuyer[buyer.UserId] = { expiresAt = nowSec() + 60}
	if PRODUCT_ID_RESET > 0 then
		local ok, err = pcall(function()
			MarketPlaceService:PromptProductPurchase(buyer, PRODUCT_ID_RESET)
		end)
		if not ok then pendingByBuyer[buyer.UserId] = nil print("ResetDistance: prompt failed", tostring(err)) end
	else
		resetAllDistance(buyer)
		lastUsedAt[buyer.UserId] = nowSec()
		pendingByBuyer[buyer.UserId] = nil
	end
end)

-- Receipt handler for PaymentsRouter
local resetReceiptBF = Instance.new("BindableFunction")
resetReceiptBF.Name = "ResetAllDist_HandleReceipt"
resetReceiptBF.Parent = rs

resetReceiptBF.OnInvoke = function(receipt)
	if receipt.ProductId ~= PRODUCT_ID_RESET then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local buyerUserId = receipt.PlayerId
	local buyer = Players:GetPlayerByUserId(buyerUserId)
	local pending = pendingByBuyer[buyerUserId]
	local ok = false
	print("ResetDistance: receipt for", buyer and buyer.Name or buyerUserId)
	if buyer and pending and nowSec() <= pending.expiresAt then
		resetAllDistance(buyer)
		lastUsedAt[buyerUserId] = nowSec()
		ok = true
	else
		print("ResetDistance: receipt not processed yet or pending missing")
	end
	pendingByBuyer[buyerUserId] = nil
	return ok and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
end