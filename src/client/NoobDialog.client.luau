local players = game:GetService("Players")
local plr = players.LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local sound = rs.Sound:WaitForChild("TalkSound")

local textHolder = script.Parent.TextHolder:WaitForChild("TextBox")
local gui = script.Parent
local avName = gui.Avatar:WaitForChild("Name")
local yesOpt = script.Parent.Yes
local NoOpt = script.Parent.No
local multCounter = plr.PlayerGui:WaitForChild("WalkBar")
local events = rs.Events:WaitForChild("EarlyRebirthEvent")

--Dialogs
local noobRoot = workspace.EarlyRebirths.Noob.HumanoidRootPart
local noobDialog = workspace.EarlyRebirths.Noob.ProximityPrompt


gui.Enabled = false
talking = false
yesOpt.Visible = false
NoOpt.Visible = false

local function getText(text,time)
	gui.Enabled = true
	textHolder.Text = text
	sound:Play()
	task.wait(time)
end


local function endDialog()
	multCounter.Enabled = true
	gui.Enabled = false
	textHolder.Text = ""
	talking = false
	yesOpt.Visible = false
	NoOpt.Visible = false
	noobDialog.Enabled = true
end

noobDialog.Triggered:Connect(function()	
	if talking then return end
	talking = true
	multCounter.Enabled = false
	noobDialog.Enabled = false
	avName.Text = "Noob"
	getText("Hello I Am Noob!", 2)
	getText("I know a way to gain extra speed to make you faster..", 2)
	getText("But it'll cost something, do you want to take the offer?")
	
	
	yesOpt.Visible = true
	NoOpt.Visible = true
	
	yesOpt.MouseButton1Click:Once(function()
		yesOpt.Visible = false
		NoOpt.Visible = false
		getText("Okay, I'll give you the offer.", 2)
		getText("I gave you +2 base spd but you have to start over.", 2)
		task.wait(1)
		events:FireServer()
		endDialog()
	end)
	
	NoOpt.MouseButton1Click:Once(function()
		yesOpt.Visible = false
		NoOpt.Visible = false
		getText("Okay then..", 1)
		endDialog()
	end)
	
	task.spawn(function()
		while talking do
			task.wait(0.5)
			local char = plr.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local dist = (char.HumanoidRootPart.Position - noobRoot.Position).Magnitude
				if dist > 12 then
					endDialog()
				end
			end
		end
	end)
	
end)
