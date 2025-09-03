local Players = game:GetService("Players")

-- Wait for goal part (finish line)
local goalPart = workspace:WaitForChild("Goal[Example]")

-- Track players who have already won this round (prevent multiple wins)
local playersWhoWon = {}

-- Handle player touching the goal
local function onGoalTouched(hit)
	local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end
	
	-- Check if player already won this round
	if playersWhoWon[player.UserId] then return end
	
	-- Mark player as winner for this round
	playersWhoWon[player.UserId] = true
	
	-- Get current wins and update directly
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local winsValue = leaderstats:FindFirstChild("Wins")
		if winsValue then
			-- Increment wins directly on server
			winsValue.Value = winsValue.Value + 1
			
			-- Announce the win
			print(player.Name .. " reached the goal! Total wins: " .. winsValue.Value)
			
			-- Optional: Add celebration effects here
		end
	end
end

goalPart.Touched:Connect(onGoalTouched)

-- Reset win tracking when needed (example: every 5 minutes)
spawn(function()
	while true do
		wait(300) -- 5 minutes
		playersWhoWon = {}
		print("[GameLogic] Win tracking reset - players can win again!")
	end
end) 