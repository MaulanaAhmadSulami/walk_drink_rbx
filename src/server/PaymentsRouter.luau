local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Products = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Products"))

-- Map product ids to BindableFunction names
local productToHandlerName = {
    [Products.SWAP] = "Swap_HandleReceipt",
    [Products.FREEZE] = "Freeze_HandleReceipt",
    [Products.DOUBLE_SPEED] = "DoubleSpeed_HandleReceipt",
    [Products.THRICE_SPEED] = "DoubleSpeed_HandleReceipt",
    [Products.PLUS_10K] = "PlusStud_HandleReceipt",
    [Products.MIN_10K] = "MinusStud_HandleReceipt",
    [Products.RESET_DIST] = "ResetAllDist_HandleReceipt",
}

MarketplaceService.ProcessReceipt = function(receipt)
    local handlerName = productToHandlerName[receipt.ProductId]
    if handlerName then
        -- Resolve handler at runtime to avoid init-order races
        local handler = ReplicatedStorage:FindFirstChild(handlerName)
        if not handler then
            warn(string.format("[PaymentsRouter] Handler %s not found yet; retrying later", tostring(handlerName)))
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        if handler:IsA("BindableFunction") then
            local ok, decision = pcall(function()
                return handler:Invoke(receipt)
            end)
            if ok and typeof(decision) == "EnumItem" then
                return decision
            end
            warn(string.format("[PaymentsRouter] Handler %s error; retrying", tostring(handlerName)))
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        warn(string.format("[PaymentsRouter] %s is not a BindableFunction; retrying", tostring(handlerName)))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    -- Unknown product id; don't charge to avoid unintended grants
    warn(string.format("[PaymentsRouter] Unknown productId %s; retrying", tostring(receipt.ProductId)))
    return Enum.ProductPurchaseDecision.NotProcessedYet
end


