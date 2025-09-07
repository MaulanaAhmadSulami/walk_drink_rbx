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

	local rebirthCount = tonumber(plr:GetAttribute("RebirthCount")) or 0
	local rebirthBonus = rebirthCount * 2
	local defaultWalkSpeed = 16
	local earlyRebirthBonus = 2 -- +2 for early rebirth
	local newBaseSpeed = defaultWalkSpeed + earlyRebirthBonus + rebirthBonus

	plr:SetAttribute("BaseSpeed", newBaseSpeed)
	plr:SetAttribute("isEarlyRebirth", true)

end)

-- Handle character spawning to apply base speed
players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid") :: Humanoid

		task.wait(0.1)

		-- Initialize attributes for new players
		if plr:GetAttribute("isEarlyRebirth") == nil then
			plr:SetAttribute("isEarlyRebirth", false)
		end

		if plr:GetAttribute("RebirthCount") == nil then
			plr:SetAttribute("RebirthCount", 0)
		end

		local earlyRebirthBonus = plr:GetAttribute("isEarlyRebirth") and 2 or 0
		local rebirthCount = tonumber(plr:GetAttribute("RebirthCount")) or 0
		local rebirthBonus = rebirthCount * 2
		local defaultWalkSpeed = 16 
		local totalBaseSpeed = defaultWalkSpeed + earlyRebirthBonus + rebirthBonus

		plr:SetAttribute("BaseSpeed", totalBaseSpeed)
	end)
end)