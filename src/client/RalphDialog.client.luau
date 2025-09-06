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
local ralphRoot = workspace.EarlyRebirths.Ralph.Handle
local ralphDialog = workspace.EarlyRebirths.Ralph.Proximity.ProximityPrompt


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
	ralphDialog.Enabled = true
end

ralphDialog.Triggered:Connect(function()	
	if talking then return end
	talking = true
	multCounter.Enabled = false
	ralphDialog.Enabled = false
	avName.Text = "Ralph"
	getText("#!!313237&#&&!!@&*!@!", 2)
	getText("Oh sorry, didn't know you're here..", 2)
	getText("@!@!#!@##$$@$@!!$$%%%@", 2)
	getText("I have some speed I don't mind giving away, you want it?", 2)
	getText("I'm sure you have met my cousin Noob, he also likes to give out speeds!", 3)
	getText("Anyway, do you want to take my offer?")
	
	
	yesOpt.Visible = true
	NoOpt.Visible = true
	
	yesOpt.MouseButton1Click:Once(function()
		yesOpt.Visible = false
		NoOpt.Visible = false
		getText("!@#$@!@!@!$$@@@@!", 2)
		getText("Added +2 speed for you. Have FUN!", 2)
		task.wait(1)
		events:FireServer()
		endDialog()
	end)
	
	NoOpt.MouseButton1Click:Once(function()
		yesOpt.Visible = false
		NoOpt.Visible = false
		getText("!@#!!@!@!@!@!#@#$@! :/", 1)
		endDialog()
	end)
	
	task.spawn(function()
		while talking do
			task.wait(0.5)
			local char = plr.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local dist = (char.HumanoidRootPart.Position - ralphRoot.Position).Magnitude
				if dist > 12 then
					endDialog()
				end
			end
		end
	end)
	
end)
