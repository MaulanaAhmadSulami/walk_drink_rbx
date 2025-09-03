local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

local events = rs:WaitForChild("Events")
local ResetAllDistEvent = events:WaitForChild("ResetDistanceEvent")

local player = Players.LocalPlayer

local button = script.Parent
if not button or not button:IsA("TextButton") then
	local gui = player.PlayerGui:WaitForChild("ShopHUD", 5)
	if not gui then
		warn("[FreezeClient] ShopHUD not found; skipping bind")
		return
	end


	local container_FrameHolder = gui:WaitForChild("FrameHolder")
	local container_MainFrame = container_FrameHolder:WaitForChild("MainFrame")
	local container_TrollFrame = container_MainFrame:WaitForChild("TrollFrame")
	if not container_TrollFrame then return end

	button = container_TrollFrame:WaitForChild("ResetAll")
end

button.MouseButton1Click:Connect(function()
	ResetAllDistEvent:FireServer()
end)
