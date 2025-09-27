-- GardenSystem.lua (ServerScriptService) - Unified Garden Management
local GardenSystem = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DEBUG_MODE = true

-- Debug logger
local function debugLog(msg, lvl)
	if DEBUG_MODE then
		print("[GardenSystem][" .. (lvl or "INFO") .. "] " .. msg)
	end
end

-- Configuration
local PLOT_SIZE = Vector3.new(3.5, 0.2, 3.5)
local PLOTS_PER_PLAYER = 9
local PLOT_SPACING = 5

-- Storage
local playerGardens = {} -- userId -> gardenData
local playerPlots = {}   -- userId -> {plotIndex -> plotData}

-- Seed and crop configurations
local SEED_CONFIG = {
	basic_seed = {
		name = "Magic Wheat",
		cost = 10,
		growTime = 30,
		cropType = "magic_wheat",
		color = Color3.fromRGB(255, 255, 0)
	},
	stellar_seed = {
		name = "Stellar Corn",
		cost = 50,
		growTime = 120,
		cropType = "stellar_corn",
		color = Color3.fromRGB(255, 200, 0)
	},
	cosmic_seed = {
		name = "Cosmic Berries",
		cost = 200,
		growTime = 300,
		cropType = "cosmic_berries",
		color = Color3.fromRGB(200, 0, 255)
	}
}

local CROP_CONFIG = {
	magic_wheat = { sellPrice = 15, expReward = 5 },
	stellar_corn = { sellPrice = 80, expReward = 15 },
	cosmic_berries = { sellPrice = 350, expReward = 35 }
}

-- Require DataManager safely
local DataManager
spawn(function()
	DataManager = require(script.Parent:WaitForChild("DataManager"))
end)

-- === VALIDATION FUNCTIONS ===
function GardenSystem.IsValidSeed(seedType)
	return SEED_CONFIG[seedType] ~= nil
end

function GardenSystem.IsValidCrop(cropType)
	return CROP_CONFIG[cropType] ~= nil
end

-- === GARDEN INITIALIZATION ===
function GardenSystem.InitializePlayerGarden(player)
	local userId = player.UserId
	if playerGardens[userId] then
		debugLog("Garden already exists for " .. player.Name, "WARN")
		return
	end

	-- Create garden data structure
	playerGardens[userId] = {
		owner = player,
		centerPos = GardenSystem.GetPlayerGardenPosition(userId),
		model = nil
	}

	playerPlots[userId] = {}

	-- Create physical garden
	local gardenModel = Instance.new("Model")
	gardenModel.Name = player.Name .. "_Garden"
	gardenModel.Parent = workspace
	playerGardens[userId].model = gardenModel

	local gardenCenter = playerGardens[userId].centerPos

	-- Create 9 plots in 3x3 grid
	for row = 1, 3 do
		for col = 1, 3 do
			local plotIndex = (row - 1) * 3 + col
			local plot = GardenSystem.CreatePlot(player, plotIndex, gardenCenter, row, col)
			plot.part.Parent = gardenModel
			playerPlots[userId][plotIndex] = plot
		end
	end

	-- Add decorations
	GardenSystem.AddChest(gardenCenter, gardenModel)
	GardenSystem.AddFence(gardenCenter, gardenModel)
	GardenSystem.CreatePlayerNameplate(player, gardenCenter, gardenModel)

	debugLog("Created garden for player: " .. player.Name)
end

function GardenSystem.GetPlayerGardenPosition(userId)
	-- Position players in circle around main island
	local angle = math.rad((userId % 12) * 30)
	local radius = 120
	return Vector3.new(
		math.cos(angle) * radius,
		6,
		math.sin(angle) * radius
	)
end

-- === PLOT MANAGEMENT ===
function GardenSystem.CreatePlot(player, plotIndex, centerPos, row, col)
	-- Calculate plot position in 3x3 grid
	local offsetX = (col - 2) * PLOT_SPACING
	local offsetZ = (row - 2) * PLOT_SPACING
	local plotPos = centerPos + Vector3.new(offsetX, 0, offsetZ)

	-- Create plot base
	local plotBase = Instance.new("Part")
	plotBase.Name = player.Name .. "_Plot_" .. plotIndex
	plotBase.Size = PLOT_SIZE
	plotBase.Position = plotPos
	plotBase.Anchored = true
	plotBase.Material = Enum.Material.Ground
	plotBase.BrickColor = BrickColor.new("Brown")

	-- Create plot border
	local border = Instance.new("Part")
	border.Name = "PlotBorder"
	border.Size = Vector3.new(PLOT_SIZE.X + 0.5, 0.5, PLOT_SIZE.Z + 0.5)
	border.Position = plotPos + Vector3.new(0, 0.5, 0)
	border.Anchored = true
	border.Material = Enum.Material.Wood
	border.BrickColor = BrickColor.new("Dark brown")
	border.CanCollide = false
	border.Transparency = 0.3
	border.Parent = plotBase

	-- Create status indicator
	local statusIndicator = Instance.new("Part")
	statusIndicator.Name = "StatusIndicator"
	statusIndicator.Size = Vector3.new(1, 0.2, 1)
	statusIndicator.Position = plotPos + Vector3.new(0.5, 0.5, 0.5)
	statusIndicator.Anchored = true
	statusIndicator.Material = Enum.Material.Neon
	statusIndicator.BrickColor = BrickColor.new("Lime green")
	statusIndicator.Shape = Enum.PartType.Cylinder
	statusIndicator.Parent = plotBase

	-- Create click detector
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 50
	clickDetector.Parent = plotBase

	-- Plot data structure
	local plotData = {
		part = plotBase,
		indicator = statusIndicator,
		clickDetector = clickDetector,
		owner = player,
		plotIndex = plotIndex,
		seedType = nil,
		plantTime = nil,
		growthStage = 0,
		isReady = false,
		cropModel = nil
	}

	-- Connect click event
	clickDetector.MouseClick:Connect(function(clickingPlayer)
		GardenSystem.HandlePlotClick(clickingPlayer, plotData)
	end)

	return plotData
end

-- === DECORATIVE ELEMENTS ===
function GardenSystem.AddFence(centerPos, parentModel)
	local length = PLOT_SPACING * 7
	local thickness = 0.4
	local height = 2

	local fenceOffsets = {
		{Vector3.new(0, 0, length/2), Vector3.new(length, height, thickness)},
		{Vector3.new(0, 0, -length/2), Vector3.new(length, height, thickness)},
		{Vector3.new(length/2, 0, 0), Vector3.new(thickness, height, length)},
		{Vector3.new(-length/2, 0, 0), Vector3.new(thickness, height, length)}
	}

	for _, offset in ipairs(fenceOffsets) do
		local fence = Instance.new("Part")
		fence.Name = "Fence"
		fence.Size = offset[2]
		fence.Position = centerPos + offset[1] + Vector3.new(0, height/2, 0)
		fence.Anchored = true
		fence.Material = Enum.Material.Wood
		fence.BrickColor = BrickColor.new("Burgundy")
		fence.Parent = parentModel
	end
end

function GardenSystem.AddChest(centerPos, parentModel)
	local chest = Instance.new("Part")
	chest.Name = "Chest"
	chest.Size = Vector3.new(2.2, 1.6, 1.2)
	chest.Position = centerPos + Vector3.new(-(PLOT_SPACING * 2), 1, 0)
	chest.Anchored = true
	chest.Material = Enum.Material.Wood
	chest.BrickColor = BrickColor.new("Dark orange")
	chest.Parent = parentModel

	-- Add click detector for chest interaction
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Name = "ChestInteraction"
	clickDetector.MaxActivationDistance = 10
	clickDetector.Parent = chest

	return chest
end

function GardenSystem.CreatePlayerNameplate(player, centerPos, parentModel)
	local nameplate = Instance.new("Part")
	nameplate.Name = player.Name .. "_Nameplate"
	nameplate.Size = Vector3.new(10, 1, 3)
	nameplate.Position = centerPos + Vector3.new(0, 20, 0)
	nameplate.Anchored = true
	nameplate.CanCollide = false
	nameplate.Transparency = 1
	nameplate.Parent = parentModel

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = nameplate

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = player.Name .. "'s Magical Garden"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.Fantasy
	textLabel.Parent = gui

	-- Floating animation
	local floatTween = TweenService:Create(
		nameplate,
		TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Position = centerPos + Vector3.new(0, 25, 0)}
	)
	floatTween:Play()
end

-- === FARMING FUNCTIONALITY ===
function GardenSystem.BuySeed(player, seedType, amount)
	if not DataManager then
		return false, "Data system not ready", 0
	end

	local seedConfig = SEED_CONFIG[seedType]
	if not seedConfig then
		return false, "Invalid seed type", 0
	end

	local playerData = DataManager.GetPlayerData(player)
	if not playerData then
		return false, "Player data not found", 0
	end

	local totalCost = seedConfig.cost * amount
	if playerData.coins < totalCost then
		return false, "Not enough coins", 0
	end

	-- Deduct coins and add seeds
	playerData.coins = playerData.coins - totalCost
	playerData.inventory = playerData.inventory or {}
	playerData.inventory.seeds = playerData.inventory.seeds or {}
	playerData.inventory.seeds[seedType] = (playerData.inventory.seeds[seedType] or 0) + amount

	DataManager.SavePlayerData(player, playerData)
	return true, "Seeds purchased successfully", totalCost
end

function GardenSystem.PlantSeed(player, plotIndex, seedType)
	if not DataManager then
		return false, "Data system not ready"
	end

	local userId = player.UserId
	local plots = playerPlots[userId]
	if not plots or not plots[plotIndex] then
		return false, "Plot not found"
	end

	local plotData = plots[plotIndex]
	if plotData.seedType then
		return false, "Plot already occupied"
	end

	local seedConfig = SEED_CONFIG[seedType]
	if not seedConfig then
		return false, "Invalid seed type"
	end

	local playerData = DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.seeds or 
		(playerData.inventory.seeds[seedType] or 0) <= 0 then
		return false, "No seeds available"
	end

	-- Plant the seed
	plotData.seedType = seedType
	plotData.plantTime = tick()
	plotData.growthStage = 1
	plotData.isReady = false

	-- Update visuals
	plotData.indicator.BrickColor = BrickColor.new("Yellow")
	GardenSystem.CreateCropVisual(plotData, seedConfig)
	GardenSystem.StartGrowthTimer(plotData, seedConfig)

	-- Consume seed from inventory
	playerData.inventory.seeds[seedType] = playerData.inventory.seeds[seedType] - 1
	DataManager.SavePlayerData(player, playerData)

	debugLog("Planted " .. seedConfig.name .. " in plot " .. plotIndex)
	return true, "Seed planted successfully"
end

function GardenSystem.Harvest(player, plotIndex)
	local userId = player.UserId
	local plots = playerPlots[userId]
	if not plots or not plots[plotIndex] then
		return false, nil, 0, "Plot not found"
	end

	local plotData = plots[plotIndex]
	if not plotData.isReady or not plotData.seedType then
		return false, nil, 0, "Plot not ready for harvest"
	end

	local seedConfig = SEED_CONFIG[plotData.seedType]
	local cropType = seedConfig.cropType
	local quantity = 1

	-- Clear plot
	plotData.seedType = nil
	plotData.plantTime = nil
	plotData.growthStage = 0
	plotData.isReady = false

	-- Update visuals
	plotData.indicator.BrickColor = BrickColor.new("Lime green")
	if plotData.cropModel then
		plotData.cropModel:Destroy()
		plotData.cropModel = nil
	end

	-- Add to player inventory
	if DataManager then
		local playerData = DataManager.GetPlayerData(player)
		if playerData then
			playerData.inventory = playerData.inventory or {}
			playerData.inventory.crops = playerData.inventory.crops or {}
			playerData.inventory.crops[cropType] = (playerData.inventory.crops[cropType] or 0) + quantity
			DataManager.SavePlayerData(player, playerData)
		end
	end

	return true, cropType, quantity, "Harvest successful"
end

function GardenSystem.SellPlant(player, cropType, quantity)
	if not DataManager then
		return false, 0, "Data system not ready"
	end

	local cropConfig = CROP_CONFIG[cropType]
	if not cropConfig then
		return false, 0, "Invalid crop type"
	end

	local playerData = DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.crops or 
		(playerData.inventory.crops[cropType] or 0) < quantity then
		return false, 0, "Not enough crops to sell"
	end

	local coinsGained = cropConfig.sellPrice * quantity

	-- Remove crops and add coins
	playerData.inventory.crops[cropType] = playerData.inventory.crops[cropType] - quantity
	playerData.coins = (playerData.coins or 0) + coinsGained

	DataManager.SavePlayerData(player, playerData)
	return true, coinsGained, "Crops sold successfully"
end

-- === VISUAL EFFECTS ===
function GardenSystem.CreateCropVisual(plotData, seedConfig)
	if plotData.cropModel then
		plotData.cropModel:Destroy()
	end

	local crop = Instance.new("Part")
	crop.Name = "Crop_" .. seedConfig.name
	crop.Size = Vector3.new(2, 1, 2)
	crop.Position = plotData.part.Position + Vector3.new(0, 0.5, 0)
	crop.Anchored = true
	crop.Material = Enum.Material.Neon
	crop.Color = seedConfig.color
	crop.Shape = Enum.PartType.Ball
	crop.Parent = plotData.part

	plotData.cropModel = crop

	-- Growth animation
	local growTween = TweenService:Create(
		crop,
		TweenInfo.new(2, Enum.EasingStyle.Elastic),
		{Size = Vector3.new(3, 2, 3)}
	)
	growTween:Play()
end

function GardenSystem.StartGrowthTimer(plotData, seedConfig)
	spawn(function()
		wait(seedConfig.growTime)

		-- Crop is ready!
		plotData.isReady = true
		plotData.growthStage = 3

		-- Update visual indicators
		plotData.indicator.BrickColor = BrickColor.new("Bright green")

		if plotData.cropModel then
			plotData.cropModel.Material = Enum.Material.ForceField
			plotData.cropModel.Color = Color3.fromRGB(255, 215, 0)
		end

		debugLog("Crop ready for harvest in plot " .. plotData.plotIndex)
	end)
end

-- === INTERACTION HANDLING ===
function GardenSystem.HandlePlotClick(clickingPlayer, plotData)
	if clickingPlayer ~= plotData.owner then
		return
	end

	debugLog("Plot clicked by: " .. clickingPlayer.Name .. ", Plot: " .. plotData.plotIndex)

	if plotData.seedType == nil then
		debugLog("Empty plot - ready for planting")
	elseif plotData.isReady then
		GardenSystem.Harvest(clickingPlayer, plotData.plotIndex)
	else
		local timeLeft = GardenSystem.GetGrowTimeLeft(plotData)
		debugLog("Still growing... Time left: " .. timeLeft .. " seconds")
	end
end

function GardenSystem.GetGrowTimeLeft(plotData)
	local seedConfig = SEED_CONFIG[plotData.seedType]
	if not plotData.plantTime or not seedConfig then
		return 0
	end

	local elapsed = tick() - plotData.plantTime
	local timeLeft = math.max(0, seedConfig.growTime - elapsed)
	return math.floor(timeLeft)
end

-- === DATA ACCESS FUNCTIONS ===
function GardenSystem.GetPlayerPlots(player)
	return playerPlots[player.UserId] or {}
end

function GardenSystem.GetInventory(player)
	if not DataManager then return {} end
	local playerData = DataManager.GetPlayerData(player)
	return playerData and playerData.inventory or {}
end

-- === CLEANUP ===
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	if playerGardens[userId] and playerGardens[userId].model then
		playerGardens[userId].model:Destroy()
	end
	playerGardens[userId] = nil
	playerPlots[userId] = nil
end)

debugLog("GardenSystem loaded successfully")
return GardenSystem