local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("Events")
local checkpointHit = events:WaitForChild("CheckpointHitEvent")
local checkpointReset = events:WaitForChild("CheckpointResetEvent")

local function hideForLocalPlayer(container)
	-- container can be the touched BasePart or its parent Folder/Model
	local root = container
	if root and root.Parent and root.Parent:IsA("Folder") then
		root = root.Parent -- e.g., 250 / 500 folder
	end

	for _, inst in ipairs((root or container):GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Transparency = 1
			inst.CanCollide = false
		end
	end
	print("[Checkpoint] hidden:", (root or container):GetFullName())
end

checkpointHit.OnClientEvent:Connect(function(part)
	if not part then return end
	hideForLocalPlayer(part)
end)

local function restoreAll()
	local folder = workspace:FindFirstChild("Checkpoints")
	if not folder or not folder:IsA("Folder") then return end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") then
			for _, inst in ipairs(child:GetDescendants()) do
				if inst:IsA("BasePart") then
					local isCheckpoint = string.sub(inst.Name, 1, 10) == "Checkpoint"
					if isCheckpoint then
						inst.Transparency = 0.7
						inst.CanCollide = true
					else
						inst.Transparency = 0
					end
				end
			end
		end
	end
	print("[Checkpoint] restored all visuals for local player")
end

checkpointReset.OnClientEvent:Connect(restoreAll)