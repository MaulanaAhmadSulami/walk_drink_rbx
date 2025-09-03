local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local MarketPlaceService = game:GetService("MarketplaceService")

-- utils
local events = rs:WaitForChild("Events")
local modules = rs:WaitForChild("Modules")
local product = require(modules:WaitForChild("Products"))
local constant = require(rs:WaitForChild("Constants"))

-- events
local minusStud = events:WaitForChild("MinusStudEvent")
local displayEffect = events:WaitForChild("DisplayStatus")
local boostAnnounce = events:WaitForChild("BoostServerAnnounce")
local serverAnnouncementEvent = events:WaitForChild("ServerAnnouncement")

local PRODUCT_MINUS_STUD = product.MIN_10K
local lastUsedAt: {[number]: number} = {}
local requestWindow =  {}
local pendingPlusByBuyer: {[number]: {expiresAt: number}} = {}


local characterAddedConnections: {[number]: RBXScriptConnection} = {}


local function buildTrackPoints(): ({Vector3}, number)
	local points = {}
	local startPart = workspace:FindFirstChild(constant.START_PART_NAME)
	if startPart and startPart:IsA("BasePart") then
		table.insert(points, startPart.Position)
	else
		warn("Start part not found", tostring(constant.START_PART_NAME))
		return {}, 0
	end
	
	local checkpointsFolder = workspace:FindFirstChild("Checkpoints")
	if checkpointsFolder and checkpointsFolder:IsA("Folder") then
		for i = 1, 999 do
			local cp = checkpointsFolder:FindFirstChild(tostring(i))
			if cp and cp:IsA("BasePart") then
				table.insert(points, cp.Position)
			else
				break
			end
		end
	end
	local goalPart: BasePart? = nil
	for _, inst in ipairs(game:GetService("CollectionService"):GetTagged(constant.GOAL_TAG)) do
		if inst:IsA("BasePart") then goalPart = inst break end
	end
	
	if not goalPart then
		local named = workspace:FindFirstChild(constant.GOAL_TAG)
		if named and named:IsA("BasePart") then goalPart = named end
	end
	
	if goalPart then
		table.insert(points, goalPart.Position)
	else
		warn("Goal part not found")
		return {}, 0
	end
	
	local cumulative = {0}
	for i = 2, #points do
		local seg = (points[i] - points[i-1]).Magnitude
		cumulative[i] = cumulative[i-1] + seg
	end
	
	return points, cumulative[#cumulative]
end



local function findProgressAlongTrack(points: {Vector3}, totalLen: number, worldPos: Vector3): (number, number, Vector3)
	local closestIdx = 1
	local minDist = math.huge
	local bestProgress = 0
	local bestDir = Vector3.new(0, 0, 1)
	local cumulative = {0}
	
	for i = 2, #points do
		local segLen = (points[i] - points[i-1]).Magnitude
		cumulative[i] = cumulative[i-1] + segLen
	end
	
	for i = 1, #points - 1 do
		local a = points[i]
		local b = points[i + 1]
		local ab = b - a
		local segLen = ab.Magnitude
		if segLen > 0 then
			local dir = ab.Unit
			local ap = worldPos - a
			local proj = math.clamp(ap:Dot(dir), 0, segLen)
			local projPoint = a + dir * proj
			local d = (worldPos - projPoint).Magnitude
			if d < minDist then
				minDist = d
				closestIdx = i
				local segStart = cumulative[i]
				bestProgress = (segStart + proj) / math.max(totalLen, 1)
				bestDir = dir
			end
		end
	end
	return closestIdx, math.clamp(bestProgress, 0, 1), bestDir
end

local function positionAtDistance(points: {Vector3}, distance: number): (Vector3, Vector3)
	if #points < 2 then return points[1] or Vector3.zero, Vector3.new(0, 0, 1) end
	local cumulative = {0}
	for i = 2, #points do
		local segLen = (points[i] - points[i - 1]).Magnitude
		cumulative[i] = cumulative[i - 1] + segLen
	end
	
	local totalLen = cumulative[#cumulative]
	distance = math.clamp(distance, 0, totalLen)
	for i = 1, #points - 1 do
		local segStart = cumulative[i]
		local segEnd = cumulative[i + 1]
		if distance >= segStart and distance <= segEnd then
			local a = points[i]
			local b = points[i + 1]
			local segLen = (b - a).Magnitude
			if segLen <= 0 then return a, Vector3.new(0, 0, 1) end
			local t = (distance - segStart) / segLen
			local pos = a + (b - a) * t
			local dir = (b - a).Unit
			return pos, dir
		end
	end
	
	return points[#points], (points[#points] - points[#points-1]).Unit
end

local function getSafeGroundPosition(pos: Vector3, character: Model?): Vector3
	local origin = pos + Vector3.new(0, 50, 0)
	local direction = Vector3.new(0, -1000, 0)
	local params = RaycastParams.new()
	if character then
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
	end
	local result = workspace:Raycast(origin, direction, params)
	if result and result.Position then
		return Vector3.new(pos.X, result.Position.Y + 5, pos.Z)
	end
	return pos + Vector3.new(0, 5, 0)
end

local function reduceAllPlayersStuds(deltaStuds: number, excludeUserId: number)
	local points, totalLen = buildTrackPoints()
	
	if #points < 2 or totalLen <= 0 then
		warn("Track is not AVAILABLE")
		return
	end
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.UserId == excludeUserId then continue end -- filter buyer biar ga kena efek
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if char and root then
			local idx, progress = findProgressAlongTrack(points, totalLen, root.Position)
			local currDistance = progress * totalLen
			local newDistance = math.max(0, currDistance - deltaStuds)
			local pos, dir = positionAtDistance(points, newDistance)
			local safePos = getSafeGroundPosition(pos, char)
			local look = safePos + dir
			char:PivotTo(CFrame.new(safePos, look))
			
			local ls = plr:FindFirstChild("leaderstats")
			local walked = ls and ls:FindFirstChild("Walked")
			if walked and walked:IsA("NumberValue") then
				walked.Value = math.floor(newDistance)
			end
			
			if displayEffect then
				displayEffect:FireClient(plr, "-" .. tostring(deltaStuds) .. " studs")
			end
		end
	end
	
	if boostAnnounce then
		boostAnnounce:FireAllClients("All players distance reduced by " .. tostring(deltaStuds).. " studs!")
	end
end

local function canUse(userId: number): (boolean, number)
	local last = lastUsedAt[userId]
	if not last then return true, 0 end
	local now = os.time()
	local remaining = constant.COOLDOWN_SECONDS - (now - last)
	if remaining > 0 then
		return false, remaining
	end
	
	return true, 0
end

minusStud.OnServerEvent:Connect(function(buyer: Player)
	if not buyer then return end
	
	local now = os.time()
	local bucket = requestWindow[buyer.UserId]
	if not bucket or now - (bucket.windowStart or 0) > constant.REQUEST_WINDOW_SECONDS then
		requestWindow[buyer.UserId] = { windowStart = now, count = 1}
	else
		bucket.count += 1
		if bucket.count > constant.MAX_REQUESTS_PER_WINDOW then
			return
		end
	end
	
	local allowed, remaining = canUse(buyer.UserId)
	if not allowed then
		return
	end
	
	if(PRODUCT_MINUS_STUD) > 0 then
		pendingPlusByBuyer[buyer.UserId] = { expiresAt = os.time() + 60}
		local ok, err = pcall(function()
			MarketPlaceService:PromptProductPurchase(buyer, PRODUCT_MINUS_STUD)
		end)
		
		if not ok then
			pendingPlusByBuyer[buyer.UserId] = nil
			warn("Prompt to purchase failed!")
		end
		
	else
		local delta = constant.MINUS_STUDS_DELTA
		print("TEST grant")
		reduceAllPlayersStuds(delta, buyer.UserId)
		lastUsedAt[buyer.UserId] = os.time()
	end
end)

local minusStudReceiptBF = Instance.new("BindableFunction")
minusStudReceiptBF.Name = "MinusStud_HandleReceipt"
minusStudReceiptBF.Parent = rs


minusStudReceiptBF.OnInvoke = function(receipt)
	if receipt.ProductId ~= PRODUCT_MINUS_STUD then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	local buyerUserId = receipt.PlayerId
	local buyer = Players:GetPlayerByUserId(buyerUserId)
	local pending = pendingPlusByBuyer[buyerUserId]
	local ok = false
	
	if buyer and pending and os.time() <= pending.expiresAt then
		local delta = constant.MINUS_STUDS_DELTA
		print(string.format("[MinusStud] Receipt grant -%d by %s", delta, buyer.Name))
		reduceAllPlayersStuds(delta, buyerUserId)
		lastUsedAt[buyerUserId] = os.time()
		ok = true
	end
	pendingPlusByBuyer[buyerUserId] = nil
	if ok then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
