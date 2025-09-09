local rs = game:GetService("ReplicatedStorage")
local getItem = rs.Gears.Drinks

local drinks = {
	{
		drinkId = 01,
		name = "Bloxy Cola",
		requirement = {
			reqWins = 1
		},
		effect = {
			BonusSpeed = 10
		},
		item = getItem.BloxyCola
	},
	{
		drinkId = 02,
		name = "Slightly Bigger Bloxy Cola",
		requirement = {
			reqWins = 1
		},
		effect = {
			BonusSpeed = 15
		},
		item = getItem.SlightlyBiggerBloxyCola -- reference
	},
	{
		drinkId = 03,
		name = "Water Bottle",
		requirement = { -- validation
			reqWins = 1
		},
		effect = {
			BonusSpeed = 20 -- buff
		},
		item = getItem.BloxyCola -- reference
	},
	{
		drinkId = 04,
		name = "Sparkling Water Bottle",
		requirement = {
			reqWins = 1
		},
		effect = {
			BonusSpeed = 25 -- buff
		},
		item = getItem.BloxyCola -- reference
	}
}

return drinks
