local players = game:GetService("Players")
local player = players.LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local displayEvent = rs.Events:WaitForChild("DisplayStatus")
local runService = game:GetService("RunService")

local statusContainer = player.PlayerGui.StatusEffects:WaitForChild("Container")
local imgToCopy = rs.PlayerContainerBtn:WaitForChild("StatusTemplate")

local activeEffects = {}

local function addEffect(statusName, duration, iconId)
	if activeEffects[statusName] then
		-- extend existing timer
		activeEffects[statusName].Timer += duration
		return
	end
	local getLabel = imgToCopy:Clone()
	getLabel.Parent = statusContainer
	getLabel.Name = statusName
	getLabel.Visible = true
	getLabel.Image = iconId
	local onHoverName = getLabel:WaitForChild("StatusName")
	local onHoverTime = getLabel:WaitForChild("TimeLeft")
	getLabel.MouseEnter:Connect(function()
		onHoverName.Visible = true
		onHoverTime.Visible = true
	end)
	getLabel.MouseLeave:Connect(function()
		onHoverName.Visible = false
		onHoverTime.Visible = false
	end)
	activeEffects[statusName] = {
		Icon = getLabel,
		Timer = tick() + duration,
		EffectName = onHoverName,
		TimeLeft = onHoverTime,
	}
end

-- Seed existing boosts on spawn
local function seedBoostUI()
	local rf = rs.Events:FindFirstChild("GetActiveBoostsFunction")
	if not rf then
		warn("[StatusEffect] GetActiveBoostsFunction not found")
		return
	end
	local r2, r3 = rf:InvokeServer()
	print(string.format("[StatusEffect] Seed boosts: 2x=%s 3x=%s", tostring(r2), tostring(r3)))
	if typeof(r2) == "number" and r2 > 0 and not activeEffects["2x Speed"] then
		addEffect("2x Speed", r2, "rbxassetid://87808357606141")
	end
	if typeof(r3) == "number" and r3 > 0 and not activeEffects["3x Speed"] then
		addEffect("3x Speed", r3, "rbxassetid://140208976440752")
	end
end

player.CharacterAdded:Connect(function()
	print("[StatusEffect] CharacterAdded -> seed boosts")
	task.delay(0.5, seedBoostUI)
end)

-- Also seed immediately if character already exists (rejoins where script loads after spawn)
if player.Character then
	task.delay(0.5, seedBoostUI)
end

runService.Heartbeat:Connect(function()
	local rn = tick()
	for name, data in pairs(activeEffects) do
		local remaining = math.max(0, math.floor(data.Timer - rn))
		local hours = math.floor(remaining / 3600)
		local minutes = math.floor((remaining % 3600) / 60)
		local seconds = remaining % 60
		local formattedTime = string.format("%02d:%02d:%02d", hours, minutes, seconds)
		data.EffectName.Text = name
		data.TimeLeft.Text = formattedTime .. "s"
		if remaining <= 0 then
			data.Icon:Destroy()
			activeEffects[name] = nil
		end
	end
end)

displayEvent.OnClientEvent:Connect(function(name, duration, iconId)
	addEffect(name, duration, iconId)
end)

