local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local rs = game:GetService("ReplicatedStorage")
local events = rs:WaitForChild("Events")
local ContentProvider = game:GetService("ContentProvider")


local player = Players.LocalPlayer

--local progressUI = script.Parent
--local startFrame = progressUI:WaitForChild("Start")
--local endFrame = progressUI:WaitForChild("End")
--local PlayerMarker = progressUI:WaitForChild("PlayerMarker")

local progressUI: ScreenGui? = nil
local startFrame: Frame? = nil
local endFrame: Frame? = nil
local PlayerMarker: ImageLabel? = nil

task.spawn(function()
	local pg = player:WaitForChild("PlayerGui")
	progressUI = pg:FindFirstChild("ProgressBar") or script.Parent
	if progressUI then
		startFrame = progressUI:WaitForChild("Start")
		endFrame = progressUI:WaitForChild("End")
		PlayerMarker = progressUI:WaitForChild("PlayerMarker")
		PlayerMarker.Visible = false
	end
end)
--PlayerMarker.Visible = false

local otherMarkers = {}

-- Call event and parts for track
local PlayerMarkerEvent = events:WaitForChild("PlayerMarkerEvent")
local PlayerMarkerRegisterEvent = events:WaitForChild("PlayerMarkerRegisterEvent")
local PlayerMarkerBatchEvent = events:WaitForChild("PlayerMarkerBatchEvent")
local startPart = workspace:WaitForChild("Start")
local endPart = workspace:WaitForChild("Goal[Example]")

-- get player movement track
local totalDistance = (endPart.Position - startPart.Position).Magnitude
local unitDirection = (endPart.Position - startPart.Position).Unit

local lastPosition = nil
local totalWalkedDistance = 0



-- player icon
local thumbnailCache = {}
local function setPlayerThumbnail(marker, targetPlayer)
	coroutine.wrap(function()
		if not marker or not targetPlayer then return end
		local uid = targetPlayer.UserId
		if thumbnailCache[uid] ~= nil then
			marker.Image = thumbnailCache[uid]
			return
		end

		local retries = 0
		local MAX_RETIRES = 3
		local validThumbnail = nil
		while retries < MAX_RETIRES do
			local success, thumb = pcall(function()
				return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if success and thumb and not string.find(string.lower(thumb), "not ready") then
				validThumbnail = thumb
				break
			end
			retries += 1
			task.wait(2)
		end

		validThumbnail = validThumbnail or 79503310036101
		thumbnailCache[uid] = validThumbnail
		marker.Image = validThumbnail
	end)()
end

local lastSentTime = 0
local lastSentProgress = nil
local SEND_INTERVAL = 0.5 -- ~2 Hz send to server
local UI_UPDATE_INTERVAL = 0.1 -- 10 Hz local UI update
local PROGRESS_EPSILON = 0.01

local lastUiUpdate = 0
local function updateLocalMarker()
	-- Get current character and HumanoidRootPart (handles respawning)
	local character = player.Character
	if not character or not character.Parent then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		PlayerMarker.Image = 79503310036101
		PlayerMarker.Visible = true
		return	
	end


	local getPlayerPos = humanoidRootPart.Position
	local distanceFromStart = (getPlayerPos - startPart.Position):Dot(unitDirection)
	local progress = math.clamp(distanceFromStart /  totalDistance, 0, 1)

	if startFrame and endFrame and PlayerMarker then
		local now = tick()
		if (now - lastUiUpdate) >= UI_UPDATE_INTERVAL then
			local startYScale = startFrame.Position.Y.Scale
			local endYScale = endFrame.Position.Y.Scale
			local markerYScale = startYScale + progress * (endYScale - startYScale)

			-- Get the mean of scale by Y axis
			markerYScale = math.clamp(markerYScale, math.min(startYScale, endYScale), math.max(startYScale, endYScale))

			PlayerMarker.Position = UDim2.new(PlayerMarker.Position.X.Scale, PlayerMarker.Position.X.Offset, markerYScale, 0)
			PlayerMarker.Visible = true
			setPlayerThumbnail(PlayerMarker, player)
			lastUiUpdate = now
		end

	end

	-- Throttle client -> server updates
	local now = tick()
	if (lastSentProgress == nil or math.abs(progress - lastSentProgress) >= PROGRESS_EPSILON or (now - lastSentTime) >= SEND_INTERVAL) then
		lastSentTime = now
		lastSentProgress = progress
		PlayerMarkerEvent:FireServer(progress)
	end
end


pcall(function()
	PlayerMarkerRegisterEvent:FireServer()
end)
-- Attach the render loop after a short delay to avoid spawn spikes
local function attachLoop()
	RunService.RenderStepped:Connect(updateLocalMarker)
end

task.delay(2.0, attachLoop)


local function handleMarkerUpdate(updatedPlayer, progress)
	if updatedPlayer == player then return end
	local playerUID = updatedPlayer.UserId

	if progress == nil then
		if otherMarkers[playerUID] then
			otherMarkers[playerUID]:Destroy()
			otherMarkers[playerUID] = nil
		end
		return
	end

	local otherMarker = otherMarkers[playerUID]
	if not otherMarker then
		if not PlayerMarker or not progressUI then return end
		otherMarker = PlayerMarker:Clone()
		otherMarker.Visible = true
		otherMarker.Name = tostring(playerUID)
		otherMarker.Parent = progressUI
		otherMarkers[playerUID] = otherMarker
	end

	if updatedPlayer.Character then
		local otherHumanoid = updatedPlayer.Character:FindFirstChildOfClass("Humanoid")

		if otherHumanoid and otherHumanoid.Health > 0 then
			setPlayerThumbnail(otherMarker, updatedPlayer)
		else
			otherMarker.Image = 79503310036101
		end

	else
		otherMarker.Image = 79503310036101
	end

	if not startFrame or not endFrame then return end
	local startYScale = startFrame.Position.Y.Scale
	local endYScale = endFrame.Position.Y.Scale
	local markerYScale = startYScale + progress * (endYScale - startYScale)
	markerYScale = math.clamp(markerYScale, math.min(startYScale, endYScale), math.max(startYScale, endYScale))
	otherMarker.Position = UDim2.new(otherMarker.Position.X.Scale, otherMarker.Position.X.Offset, markerYScale, 0)
end

PlayerMarkerEvent.OnClientEvent:Connect(handleMarkerUpdate)

-- Receive batched progresses for all players
PlayerMarkerBatchEvent.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then return end
	for userId, progress in pairs(snapshot) do
		local otherPlayer = Players:GetPlayerByUserId(tonumber(userId))
		if otherPlayer and otherPlayer ~= player then
			handleMarkerUpdate(otherPlayer, progress)
		end
	end
end)


Players.PlayerRemoving:Connect(function(onPlayerLeaving)
	local playerUID = onPlayerLeaving.UserId
	if otherMarkers[playerUID] then
		otherMarkers[playerUID]:Destroy()
		otherMarkers[playerUID] = nil
	end
end)