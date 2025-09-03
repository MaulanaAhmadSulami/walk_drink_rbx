local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local rs = game:GetService("ReplicatedStorage")
local events = rs:WaitForChild("Events")

local player = Players.LocalPlayer

--Call ui
local WalkBarUI = script.Parent
local framebar = WalkBarUI:WaitForChild("Frame")
local WalkBarText = WalkBarUI:WaitForChild("WalkBar")

--Placeholder
local StatsUpdateEvent = events:WaitForChild("StatsUpdateEvent")


--Get checkpoints, start and goal
local startPart = workspace:WaitForChild("StarterPartStarting")
local endPart = workspace:WaitForChild("Goal[Example]")
local checkpointsFolder = workspace:WaitForChild("Checkpoints")

local checkpointPositions = {startPart.Position} -- Start position is 0

-- Build checkpoints from folder structure (250/500/...) → look for a BasePart named "Checkpoint<folderName>"
for _, child in ipairs(checkpointsFolder:GetChildren()) do
	if child:IsA("Folder") then
		local nameNum = tonumber(child.Name)
		if nameNum then
			local cp = child:FindFirstChild("Checkpoint" .. child.Name)
			if cp and cp:IsA("BasePart") then
				table.insert(checkpointPositions, cp.Position)
				print("[WalkBar] Added checkpoint:", cp:GetFullName())
			end
		end
	end
end
-- sort checkpoints by distance from start along X/Z (simple heuristic)
table.sort(checkpointPositions, function(a, b)
	return (a - startPart.Position).Magnitude < (b - startPart.Position).Magnitude
end)


table.insert(checkpointPositions, endPart.Position)

--Calculate cumulative distance to each checkpoints

local cumulativeDistances = {0} --Start at 0


for i = 2, #checkpointPositions do
	local segmentDistance = (checkpointPositions[i] - checkpointPositions[i-1]).Magnitude
	local totalDistance = cumulativeDistances[i-1] + segmentDistance
	table.insert(cumulativeDistances, totalDistance)
end


local totalTrackDistance = cumulativeDistances[#cumulativeDistances]
local currSegment = 1

--print("[WalkBar] Total track distance:", totalTrackDistance)
--print("[WalkBar] Checkpoint distances:", cumulativeDistances)

local function calculateProgress(playerPosition)
	local closestSegment = 1
	local minDistance = math.huge
	local bestProgress = 0


	--Check each segment to find where player current POS is
	for i = 1, #checkpointPositions - 1 do
		local segmentStart = checkpointPositions[i]
		local segmentEnd = checkpointPositions[i + 1]
		local segmentVector = segmentEnd - segmentStart
		local segmentLength = segmentVector.Magnitude

		if segmentLength > 0 then
			local segmentDirection = segmentVector.Unit
			local playerVector = playerPosition - segmentStart
			local projectedDistance = playerVector:Dot(segmentDirection)

			--Clamp the segment bounds
			projectedDistance = math.clamp(projectedDistance, 0, segmentLength)
			local projectedPoint = segmentStart + (segmentDirection * projectedDistance)
			local distanceToSegment = (playerPosition - projectedPoint).Magnitude

			if distanceToSegment < minDistance then
				minDistance = distanceToSegment
				closestSegment = i


				--calculate progress within segment
				local segmentProgress = projectedDistance / segmentLength
				local segmentStartDistance = cumulativeDistances[i]
				local segmentEndDistance = cumulativeDistances[i + 1]
				local currDistance = segmentStartDistance + (segmentProgress * (segmentEndDistance - segmentStartDistance))

				bestProgress = currDistance / totalTrackDistance
			end
		end
	end


	return closestSegment, math.clamp(bestProgress, 0, 1)
end


--Update text label
local function updateDistanceDisplay(currDistance, segmentIndex)
	segmentIndex = math.clamp(segmentIndex or 1, 1, math.max(1, #cumulativeDistances - 1))
	local segStart = cumulativeDistances[segmentIndex]
	local segEnd = cumulativeDistances[segmentIndex + 1]
	local segLen = math.max(0, (segEnd - segStart))
	local withinSeg = math.clamp(currDistance - segStart, 0, segLen)

	local roundedWithin = math.floor(withinSeg)
	local roundedSegLen = math.floor(segLen)

	local mult = 1
	local character = player.Character
	if character then
		local hum = character:FindFirstChild("Humanoid")
		if hum then
			local m = hum:GetAttribute("SpeedBoostMultiplier")
			if typeof(m) == "number" then mult = m end
		end
	end
	if mult == 1 then
		local pm = player:GetAttribute("SpeedBoostMultiplier")
		if typeof(pm) == "number" then mult = pm end
	end

	local multText = string.format("x%.2f", mult)
	WalkBarText.Text = "Walked " .. roundedWithin .. "/" .. roundedSegLen .. " for " .. multText .. " multiplier"
end


local function updateWalkBar()
	local character = player.Character
	if not character or not character.Parent then return end


	local HumanoidRootPart  = character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return
	end


	local currPosition = HumanoidRootPart.Position


	--Calculate current segment and progress
	local segment, progress = calculateProgress(currPosition)
	local currDistance = progress * totalTrackDistance

	--Update segment
	if segment ~= currSegment then
		currSegment = segment
	end

	updateDistanceDisplay(currDistance, segment)

	-- Throttled remote update to server
	local now = tick()
	local shouldSend = false
	if not script:FindFirstChild("_LastSentAt") then
		local t = Instance.new("NumberValue")
		t.Name = "_LastSentAt"
		t.Value = 0
		t.Parent = script
	end
	if not script:FindFirstChild("_LastReported") then
		local n = Instance.new("NumberValue")
		n.Name = "_LastReported"
		n.Value = 0
		n.Parent = script
	end

	local lastSentAt = script._LastSentAt.Value
	local lastReported = script._LastReported.Value

	local SEND_INTERVAL = 0.5 -- seconds
	local MIN_DELTA = 1 -- studs
	if (now - lastSentAt) >= SEND_INTERVAL and math.abs(currDistance - lastReported) >= MIN_DELTA then
		shouldSend = true
	end

	if shouldSend then
		script._LastSentAt.Value = now
		script._LastReported.Value = currDistance
		StatsUpdateEvent:FireServer("Walked", math.floor(currDistance), currPosition)
	end
end


player.CharacterAdded:Connect(function()

	currSegment = 1
	updateDistanceDisplay(0, 1)
	task.wait(1)
end)


updateDistanceDisplay(0, 1)

RunService.RenderStepped:Connect(updateWalkBar)