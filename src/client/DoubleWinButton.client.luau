local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local Marketplaceservice = game:GetService("MarketplaceService")

local button = script.Parent
local module = rs:WaitForChild("Modules")
local product = require(module:WaitForChild("Products"))
local events = rs:WaitForChild("Events")
local winsPassCheck = events:WaitForChild("DoubleWinPassEvent")
local player = Players.LocalPlayer

button.MouseButton1Click:Connect(function()
	local gamepassId = product.DOUBLE_COMPLETION or 0 
	if type(gamepassId) ~= "number" or gamepassId <= 0 then
		return
	end
	
	local ok, err = pcall(function()
		Marketplaceservice:PromptGamePassPurchase(player, gamepassId)
	end)
	
	if not ok then
		return
	end
end)

Marketplaceservice.PromptGamePassPurchaseFinished:Connect(function(plr, gamepassId, wasPurchased)
	if plr ~= player then return end
	if gamepassId ~= (product.DOUBLE_COMPLETION or 0) then return end
	print("Gamepass purchase finished, purchased: ", wasPurchased)
	if wasPurchased then
		winsPassCheck:FireServer()
	end
end)