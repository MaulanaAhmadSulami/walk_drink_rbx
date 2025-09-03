local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local button = script.Parent
local module = rs:WaitForChild("Modules")
local product = require(module:WaitForChild("Products"))
local events = rs:WaitForChild("Events")
local recheck = events:WaitForChild("ThirstPassCheckEvent")
local player = Players.LocalPlayer

button.MouseButton1Click:Connect(function()
	local gamepassId = product.LESS_THIRST or 0
	if type(gamepassId) ~= "number" or gamepassId <= 0 then
		warn("Thirst gamepass ID is not set in Products.LESS_THIRST")
		return
	end
	print("Prompting gamepass purchase for thirst reduction...")
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	end)
	if not ok then
		warn("Failed to prompt gamepass:", tostring(err))
		return
	end
end)

-- When the purchase finishes, ask server to recheck right away
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, gamepassId, wasPurchased)
	if plr ~= player then return end
	if gamepassId ~= (product.LESS_THIRST or 0) then return end
	print("Gamepass purchase finished for thirst pass, purchased:", wasPurchased)
	if wasPurchased then
		recheck:FireServer()
	end
end)