local rs = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local earlyEvent = rs.Events:WaitForChild("EarlyRebirthEvent")


-------------------------------------------------

earlyEvent.OnServerEvent:Connect(function(plr)
	local char = plr.Character
	if not char then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- Check if player has already taken early rebirth
	if plr:GetAttribute("isEarlyRebirth") == true then
		return
	end

	-- Calculate total base speed including rebirth bonuses
	local rebirthCount = tonumber(plr:GetAttribute("RebirthCount")) or 0
	local rebirthBonus = rebirthCount * 2
	local defaultWalkSpeed = 16 -- Default Roblox walkspeed
	local earlyRebirthBonus = 2 -- +2 for early rebirth
	local newBaseSpeed = defaultWalkSpeed + earlyRebirthBonus + rebirthBonus

	plr:SetAttribute("BaseSpeed", newBaseSpeed)
	plr:SetAttribute("isEarlyRebirth", true)

	print(plr.Name, "Early Rebirth taken - new base speed:", plr:GetAttribute("BaseSpeed"))
end)

-- Handle character spawning to apply base speed
players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid") :: Humanoid

		-- Wait a bit for PlayerDatastore to load attributes
		task.wait(0.1)

		-- Initialize attributes for new players
		if plr:GetAttribute("isEarlyRebirth") == nil then
			plr:SetAttribute("isEarlyRebirth", false)
		end

		if plr:GetAttribute("RebirthCount") == nil then
			plr:SetAttribute("RebirthCount", 0)
		end

		-- Calculate total base speed from all sources
		local earlyRebirthBonus = plr:GetAttribute("isEarlyRebirth") and 2 or 0
		local rebirthCount = tonumber(plr:GetAttribute("RebirthCount")) or 0
		local rebirthBonus = rebirthCount * 2
		local defaultWalkSpeed = 16 -- Default Roblox walkspeed
		local totalBaseSpeed = defaultWalkSpeed + earlyRebirthBonus + rebirthBonus

		plr:SetAttribute("BaseSpeed", totalBaseSpeed)

		print(string.format("Set for %s: %d (Early: %d, Rebirths: %d)", 
			plr.Name, totalBaseSpeed, earlyRebirthBonus, rebirthBonus))
	end)
end)