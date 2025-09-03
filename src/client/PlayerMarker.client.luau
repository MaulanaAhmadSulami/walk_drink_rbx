local Players = game:GetService("Players")
local player = Players.LocalPlayer

local playerUID = player.UserId

local PlayerImage = script.Parent
local thumbnailType = Enum.ThumbnailType.HeadShot
local thumbnailSize = Enum.ThumbnailSize.Size420x420


local content, isReady = Players:GetUserThumbnailAsync(playerUID, thumbnailType, thumbnailSize)


if isReady then
	PlayerImage.Image = content
else
	warn("Thumbnail not ready yet! Please wait")
end
