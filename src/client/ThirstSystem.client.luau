local players = game:GetService("Players")
local rs = game:GetService("RunService")
local rst = game:GetService("ReplicatedStorage")
local constant = require(rst:WaitForChild("Constants"))

local player = players.LocalPlayer
local plrGUI = player.PlayerGui
local events = rst:WaitForChild("Events")
local thirstUpdate = events:WaitForChild("ThirstUpdateEvent")

local char = nil
local hmd = nil
local capacity = nil
local thirstPercent = nil

local function getThirstUI()
	local playerGUI = player.PlayerGui
	if not playerGUI then return nil end
	local thirstBar = plrGUI:WaitForChild("ThirstBar")
	local canvasGroup1 = thirstBar:WaitForChild("CanvasGroup")
	local canvasGroup = canvasGroup1:WaitForChild("Thirst")
	thirstPercent = thirstBar:FindFirstChild("Percentage")
	return canvasGroup
end

local function setUIPercent(percent: number)
	if not capacity then return end
	capacity.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
	if thirstPercent then
		thirstPercent.Text = tostring(math.floor(percent * 100)) .. "%"
	end
end

local function setupCharacter(character)
	char = character
	hmd = char:WaitForChild("Humanoid", 5)
	capacity = getThirstUI()
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

thirstUpdate.OnClientEvent:Connect(function(percent)
	if typeof(percent) == "number" then setUIPercent(percent) end
end)