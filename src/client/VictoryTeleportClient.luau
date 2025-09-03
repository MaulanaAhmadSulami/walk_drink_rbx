local players = game:GetService("Players")
local player = players.LocalPlayer:WaitForChild("PlayerGui")
local ts = game:GetService("TweenService")
local rbFrame = player.Rebirth.RebirthHolder
local rbConfirm = player.ConfirmRebirth.RebirthHolder
local yes = rbConfirm.Yes
local no = rbConfirm.No

local rs = game:GetService("ReplicatedStorage")
local clickSound = rs.Sound:WaitForChild("ClickSound")
local events = rs:WaitForChild("Events")
local victory = events:WaitForChild("VictoryTeleportEvent")

local tweenInf = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)


--goalEvent.OnClientEvent:Connect(function()
--	rbFrame.Visible = false
--	rbConfirm.Visible = true
--end)

yes.MouseButton1Click:Connect(function()
	for _, v in pairs(rbConfirm:GetDescendants()) do
		if v:IsA("TextLabel") then
			v.TextTransparency = 0
		elseif v:IsA("ImageLabel") then
			v.ImageTransparency = 0
			v.BackgroundTransparency = 0
		elseif v:IsA("Frame") or v:IsA("ScrollingFrame") then
			v.BackgroundTransparency = 0
		elseif v:IsA("UIStroke") then
			v.Transparency = 0
		elseif v:IsA("TextButton") then
			v.TextTransparency = 0
			v.BackgroundTransparency = 0
		end
	end
	
	for _, v in pairs(rbConfirm:GetDescendants()) do
		if v:IsA("TextLabel") then
			ts:Create(v, tweenInf, {TextTransparency = 1}):Play()
		elseif v:IsA("ImageLabel") then
			ts:Create(v, tweenInf, {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
		elseif v:IsA("Frame") or v:IsA("ScrollingFrame") then
			ts:Create(v, tweenInf, {BackgroundTransparency = 1}):Play()		
		elseif v:IsA("UIStroke") then
			ts:Create(v, tweenInf, {Transparency = 1}):Play()
		elseif v:IsA("TextButton") then
			ts:Create(v, tweenInf, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
		end
	end
	
	ts:Create(rbConfirm, tweenInf, {BackgroundTransparency = 1}):Play()
	clickSound:Play()
	
	-- AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	task.wait(.32)
	victory:FireServer()
	
	rbConfirm.Visible = false
end)

no.MouseButton1Click:Connect(function()
	for _, v in pairs(rbConfirm:GetDescendants()) do
		if v:IsA("TextLabel") then
			ts:Create(v, tweenInf, {TextTransparency = 1}):Play()
		elseif v:IsA("ImageLabel") then
			ts:Create(v, tweenInf, {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
		elseif v:IsA("Frame") or v:IsA("ScrollingFrame") then
			ts:Create(v, tweenInf, {BackgroundTransparency = 1}):Play()		
		elseif v:IsA("UIStroke") then
			ts:Create(v, tweenInf, {Transparency = 1}):Play()
		elseif v:IsA("TextButton") then
			ts:Create(v, tweenInf, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
		end
	end
	
	for _, v in pairs(rbFrame:GetDescendants()) do
		if v:IsA("TextLabel") then
			v.TextTransparency = 1
		elseif v:IsA("ImageLabel") then
			v.ImageTransparency = 1
			v.BackgroundTransparency = 1
		elseif v:IsA("Frame") or v:IsA("ScrollingFrame") then
			v.BackgroundTransparency = 1
		elseif v:IsA("UIStroke") then
			v.Transparency = 1
		elseif v:IsA("TextButton") then
			v.TextTransparency = 1
			v.BackgroundTransparency = 1
		end
	end

	for _, v in pairs(rbFrame:GetDescendants()) do
		if v:IsA("TextLabel") then
			ts:Create(v, tweenInf, {TextTransparency = 0}):Play()
		elseif v:IsA("ImageLabel") then
			ts:Create(v, tweenInf, {ImageTransparency = 0, BackgroundTransparency = 0}):Play()
		elseif v:IsA("Frame") or v:IsA("ScrollingFrame") then
			ts:Create(v, tweenInf, {BackgroundTransparency = 0.65}):Play()		
		elseif v:IsA("UIStroke") then
			ts:Create(v, tweenInf, {Transparency = 0.3}):Play()
		elseif v:IsA("TextButton") then
			ts:Create(v, tweenInf, {TextTransparency = 0, BackgroundTransparency = 0}):Play()
		end
	end
	
	clickSound:Play()
	ts:Create(rbFrame, tweenInf, {BackgroundTransparency = 0}):Play()
	ts:Create(rbConfirm, tweenInf, {BackgroundTransparency = 1}):Play()
	
	-- AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	
	task.wait(0,32)
	rbConfirm.Visible = false
	rbFrame.Visible = true
	rbConfirm.BackgroundTransparency = 0
end)