local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer

local function getDescendantsByClass(root: Instance, classNames: {string}): {Instance}
	local targets = {}
	local classSet = {}
	for _, name in ipairs(classNames) do classSet[name] = true end
	for _, inst in ipairs(root:GetDescendants()) do
		if classSet[inst.ClassName] then
			table.insert(targets, inst)
		end
	end
	return targets
end

local function chunkTable(items: {any}, size: {number}): {{any}}
	local chunks = {}
	local i = 1
	while i <= #items do
		table.insert(chunks, { table.unpack(items, i, math.min(i + size - 1, #items)) })
		i += size
	end
	
	return chunks
end

local function tryPreload(label: string, instances: {Instance}): number
	local count = 0
	if #instances == 0 then return 0 end
	for _, batch in ipairs(chunkTable(instances, 50)) do
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		
		if not ok then
			warn(string.format("CLIENT %s FAILED TO PRELOAD %s", label, tostring(err)))
		else
			count += #batch
		end
		-- Yield briefly so we don't spike a frame on join
		task.wait()
	end
	return count
end

local function preloadUI(): number
	local guiRoot = player:WaitForChild("PlayerGui")
	local uiInstances = {}
	-- Preload all images and UI instances under PlayerGui
	for _, inst in ipairs(guiRoot:GetDescendants()) do
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("Decal") then
			table.insert(uiInstances, inst)
		end
	end
	return tryPreload("UI", uiInstances)
end

local function preloadReplicated(): number
	local toPreload = {}
	-- Narrow scope to known design folders to avoid scanning entire ReplicatedStorage
	local roots = {}
	local designFolder = rs:FindFirstChild("Design")
	if designFolder then table.insert(roots, designFolder) end
	for _, root in ipairs(roots) do
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("Decal") or inst:IsA("Texture") then
				table.insert(toPreload, inst)
			end
		end
	end
	return tryPreload("ReplicatedStorage Images", toPreload)
end

task.spawn(function()
	local t0 = tick()
	local total = 0
	local uiCount = preloadUI() or 0
	local repCount = preloadReplicated() or 0
	total = total + uiCount + repCount
	local dt = tick() - t0
	print(string.format("== PRELOADED ASSETS IN %.2f seconds ==", dt))
end)