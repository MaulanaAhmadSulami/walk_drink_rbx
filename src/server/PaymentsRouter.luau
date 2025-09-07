local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local MarketPlaceService = game:GetService("MarketplaceService")

local modules = rs:WaitForChild("Modules")
local Products = require(modules:WaitForChild("Products"))

------------------------------------IMPORTANT-----------------------------------------
-- Feature contract: each feature exposes a BindableFunction for receipt handling
-- Name them as:
--   Swap_HandleReceipt(receipt) -> Enum.ProductPurchaseDecision
--   Freeze_HandleReceipt(receipt) -> Enum.ProductPurchaseDecision
--------------------------------------------------------------------------------------

local productToHandlerName = {
	[Products.SWAP] = "Swap_HandleReceipt",
	[Products.FREEZE] = "Freeze_HandleReceipt",
	[Products.DOUBLE_SPEED] = "Speed_HandleReceipt",
	[Products.THRICE_SPEED] = "Speed_HandleReceipt",
	[Products.PLUS_10K] = "PlusStud_HandleReceipt",
	[Products.MIN_10K] = "MinusStud_HandleReceipt",
	[Products.RESET_DIST] = "ResetAllDist_HandleReceipt",
}

MarketPlaceService.ProcessReceipt = function(receipt)
	local handlerName = productToHandlerName[receipt.ProductId]
	if handlerName then
		-- Resolve handler at runtime to avoid init-order races
		local handler = rs:FindFirstChild(handlerName)
		if not handler then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if handler:IsA("BindableFunction") then
			local ok, decision = pcall(function()
				return handler:Invoke(receipt)
			end)
			if ok and typeof(decision) == "EnumItem" then
				return decision
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Unknown product id; don't charge to avoid unintended grants
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
