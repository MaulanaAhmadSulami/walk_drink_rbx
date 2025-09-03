local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local events = ReplicatedStorage:WaitForChild("Events")
local SwapByUsernameEvent = events:WaitForChild("SwapByUsernameEvent")
local SwapFeedbackEvent = events:WaitForChild("SwapFeedbackEvent")

local player = Players.LocalPlayer
local gui = player.PlayerGui:WaitForChild("SwapDistanceGUI", 5)
if not gui then return end

local container = gui:WaitForChild("SwapByUsername", 5)
if not container then return end

local textBox: TextBox = container:WaitForChild("TextBox")
local confirmButton: TextButton = container:WaitForChild("ConfirmButton")

local function sendSwapRequest()
    local nameText = textBox.Text
    if typeof(nameText) ~= "string" or nameText == "" then return end
    SwapByUsernameEvent:FireServer(nameText)
end

confirmButton.MouseButton1Click:Connect(sendSwapRequest)
textBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then sendSwapRequest() end
end)

SwapFeedbackEvent.OnClientEvent:Connect(function(message: string)
    -- simple feedback via TextBox placeholder for now
    if textBox and typeof(message) == "string" then
        textBox.PlaceholderText = message
    end
end)


