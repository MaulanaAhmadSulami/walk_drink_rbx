local rs = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")

local events = rs:WaitForChild("Events")
local PlayerMarkerEvent = events:WaitForChild("PlayerMarkerEvent")
local PlayerMarkerRegisterEvent = events:WaitForChild("PlayerMarkerRegisterEvent")
local PlayerMarkerBatchEvent = events:WaitForChild("PlayerMarkerBatchEvent")
local constant = require(rs:WaitForChild("Constants"))

local playerProgress = {}
local lastBroadCastAt = {}
local lastProgressSent = {}

--Flag to find dupe
local emitterRegistered = {}
local registeredAt = {}
local lastReceiveAt = {}
local windowStart = {}
local windowCount = {}



PlayerMarkerEvent.OnServerEvent:Connect(function(player, progress)
	if typeof(progress) ~= "number" then return end
	progress = math.clamp(progress, 0, 1)

	local uid = player.UserId
	local now = tick()

	-- Only accept from registered emitter
	if not emitterRegistered[uid] then return end

	-- Debounce after registration
	local regAt = registeredAt[uid]
	if regAt and (now - regAt) < constant.FIRST_JOIN_DEBOUNCE then return end

	-- Per-player receive rate limit
	local lastRx = lastReceiveAt[uid]
	if lastRx and (now - lastRx) < constant.MIN_RECEIVE_INTERVAL then return end
	lastReceiveAt[uid] = now

	local ws = windowStart[uid]
	if not ws or (now - ws) >= 1 then
		windowStart[uid] = now
		windowCount[uid] = 1
	else
		windowCount[uid] = (windowCount[uid] or 0) + 1
		if windowCount[uid] > 6 then
			--warn(string.format("[PlayerMarker] High event rate for %s (%d/sec). Possible duplicate client emitters.", player.Name, windowCount[uid]))
		end
	end

	local lastProg = lastProgressSent[uid]
	local lastTime = lastBroadCastAt[uid] or 0
	if lastProg and math.abs(progress - lastProg) < constant.MIN_DELTA and (now - lastTime) < constant.BROADCAST_INTERVAL then
		return
	end

	playerProgress[uid] = progress
	lastProgressSent[uid] = progress
	lastBroadCastAt[uid] = now

end)

-- Client declares intent to be the sole emitter
PlayerMarkerRegisterEvent.OnServerEvent:Connect(function(player)
	local uid = player.UserId
	if emitterRegistered[uid] then
		--warn(string.format("[PlayerMarker] Duplicate registration from %s. Ensure only one script emits PlayerMarkerEvent.", player.Name))
		print("Duplicate detected")
	else
		emitterRegistered[uid] = true
		registeredAt[uid] = tick()
	end
end)

--remove players from progress bar when they leave
Players.PlayerRemoving:Connect(function(onPlayerLeaving)
	playerProgress[onPlayerLeaving.UserId] = nil
	lastBroadCastAt[onPlayerLeaving.UserId] = nil
	lastProgressSent[onPlayerLeaving.UserId] = nil
	emitterRegistered[onPlayerLeaving.UserId] = nil
	registeredAt[onPlayerLeaving.UserId] = nil
	lastReceiveAt[onPlayerLeaving.UserId] = nil
	windowStart[onPlayerLeaving.UserId] = nil
	windowCount[onPlayerLeaving.UserId] = nil
	PlayerMarkerEvent:FireAllClients(onPlayerLeaving, nil)
end)

task.spawn(function()
	while true do
		task.wait(constant.BROADCAST_INTERVAL)
		if next(playerProgress) ~= nil then
			local snapshot = {}
			for uid, prog in pairs(playerProgress) do
				snapshot[uid] = prog
			end
			PlayerMarkerBatchEvent:FireAllClients(snapshot)
		end
	end
end)