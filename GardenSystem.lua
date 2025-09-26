-- Garden Plot Manager (ServerScript)
local GardenSystem = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DEBUG_MODE = true

-- Debug logger
local function debugLog(msg, lvl)
	if DEBUG_MODE then
		print("[MapGenerator][" .. (lvl or "INFO") .. "] " .. msg)
	end
end

-- Plot configuration
local PLOT_SIZE = Vector3.new(3.5, 0.2, 3.5)
local PLOTS_PER_PLAYER = 9
local PLOT_SPACING = 5

-- Store player plots
local playerPlots = {}

function GardenSystem.AddFence(centerPos, parentModel)
	local length = PLOT_SPACING * 7 -- Ajusteaza sa depa?easca gridul 3x3
	local thickness = 0.4
	local height = 2
	local y = centerPos.Y + height / 2

	local fenceOffsets = {
		{Vector3.new(0, 0, length/2), Vector3.new(length, height, thickness)},    -- fa?a
		{Vector3.new(0, 0, -length/2), Vector3.new(length, height, thickness)},   -- spate
		{Vector3.new(length/2, 0, 0), Vector3.new(thickness, height, length)},    -- dreapta
		{Vector3.new(-length/2, 0, 0), Vector3.new(thickness, height, length)},   -- stânga
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
	-- Plaseaza cufarul lânga ploturi, la stânga
	local chest = Instance.new("Part")
	chest.Name = "Chest"
	chest.Size = Vector3.new(2.2, 1.6, 1.2)
	chest.Position = centerPos + Vector3.new(-(PLOT_SPACING * 2), 1, 0)
	chest.Anchored = true
	chest.Material = Enum.Material.Wood
	chest.BrickColor = BrickColor.new("Dark orange")
	chest.Shape = Enum.PartType.Block
	chest.Parent = parentModel
	
	-- Add corner reinforcements (metal bands)
	local function addMetalBand(offset, size)
		local band = Instance.new("Part")
		band.Name = "MetalBand"
		band.Size = size
		band.Position = chest.Position + offset
		band.Anchored = true
		band.Material = Enum.Material.Metal
		band.BrickColor = BrickColor.new("Really black")
		band.Parent = chest

		-- Weld to chest
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chest
		weld.Part1 = band
		weld.Parent = chest

		return band
	end
	
	-- Add horizontal metal bands
	addMetalBand(Vector3.new(0, 0.6, 0), Vector3.new(2.4, 0.1, 1.4))
	addMetalBand(Vector3.new(0, -0.6, 0), Vector3.new(2.4, 0.1, 1.4))

	-- Add vertical corner bands
	addMetalBand(Vector3.new(-1, 0, -0.5), Vector3.new(0.1, 1.8, 0.1))
	addMetalBand(Vector3.new(1, 0, -0.5), Vector3.new(0.1, 1.8, 0.1))
	addMetalBand(Vector3.new(-1, 0, 0.5), Vector3.new(0.1, 1.8, 0.1))
	addMetalBand(Vector3.new(1, 0, 0.5), Vector3.new(0.1, 1.8, 0.1))
	
	-- Create chest lid
	local lid = Instance.new("Part")
	lid.Name = "ChestLid"
	lid.Size = Vector3.new(2.2, 0.2, 1.2)
	lid.Position = chest.Position + Vector3.new(0, 0.9, 0)
	lid.Anchored = true
	lid.Material = Enum.Material.Wood
	lid.BrickColor = BrickColor.new("Dark orange")
	lid.Parent = chest 
	
	-- Add lid handle
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.1, 0.1)
	handle.Position = lid.Position + Vector3.new(0, 0.15, 0.5)
	handle.Anchored = true
	handle.Material = Enum.Material.Metal
	handle.BrickColor = BrickColor.new("Gold")
	handle.Shape = Enum.PartType.Cylinder
	handle.Rotation = Vector3.new(0, 0, 90)
	handle.Parent = chest
	
	-- Add decorative lock
	local lock = Instance.new("Part")
	lock.Name = "Lock"
	lock.Size = Vector3.new(0.3, 0.4, 0.2)
	lock.Position = chest.Position + Vector3.new(0, 0, 0.7)
	lock.Anchored = true
	lock.Material = Enum.Material.Metal
	lock.BrickColor = BrickColor.new("Gold")
	lock.Parent = chest
	
	-- Add keyhole to lock
	local keyhole = Instance.new("Part")
	keyhole.Name = "Keyhole"
	keyhole.Size = Vector3.new(0.05, 0.15, 0.25)
	keyhole.Position = lock.Position + Vector3.new(0, 0, 0.01)
	keyhole.Anchored = true
	keyhole.Material = Enum.Material.Metal
	keyhole.BrickColor = BrickColor.new("Really black")
	keyhole.Parent = chest
	
	-- Add some decorative studs
	local function addStud(offset)
		local stud = Instance.new("Part")
		stud.Name = "Stud"
		stud.Size = Vector3.new(0.1, 0.1, 0.1)
		stud.Position = chest.Position + offset
		stud.Anchored = true
		stud.Material = Enum.Material.Metal
		stud.BrickColor = BrickColor.new("Really black")
		stud.Shape = Enum.PartType.Ball
		stud.Parent = chest

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chest
		weld.Part1 = stud
		weld.Parent = chest
	end
	
	-- Add studs to corners and sides
	addStud(Vector3.new(-0.8, 0.4, 0.55))
	addStud(Vector3.new(0.8, 0.4, 0.55))
	addStud(Vector3.new(-0.8, -0.4, 0.55))
	addStud(Vector3.new(0.8, -0.4, 0.55))
	
	-- Add a subtle PointLight for magical effect
	local light = Instance.new("PointLight")
	light.Name = "ChestGlow"
	light.Brightness = 0.5
	light.Color = Color3.new(1, 0.8, 0.4) -- Warm golden glow
	light.Range = 8
	light.Parent = chest
	
	-- Add a subtle ParticleEmitter for sparkles (optional)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SparkleAttachment"
	attachment.Position = Vector3.new(0, 0.8, 0)
	attachment.Parent = chest

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "ChestSparkles"
	sparkles.Enabled = false -- Enable when chest is opened or interacted with
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Lifetime = NumberRange.new(0.5, 1.5)
	sparkles.Rate = 10
	sparkles.SpreadAngle = Vector2.new(45, 45)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.Parent = attachment
	
	-- Add ClickDetector for interaction
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Name = "ChestInteraction"
	clickDetector.MaxActivationDistance = 10
	clickDetector.Parent = chest
	
	-- The parts are accessible by their names for future animations:
	-- chest:FindFirstChild("ChestLid") - for the lid
	-- chest:FindFirstChild("Handle") - for the handle
	-- chest:FindFirstChild("SparkleAttachment"):FindFirstChild("ChestSparkles") - for sparkles

	
	-- Po?i adauga ?i Decal, SurfaceGui sau Mesh daca ai model 3D pentru un aspect mai interesant
	return chest
end


function GardenSystem.InitializePlayerGarden(player)
	local userId = player.UserId
	playerPlots[userId] = {}
	
	-- Creeaza Model pentru toata gradina
	local gardenModel = Instance.new("Model")
	gardenModel.Name = player.Name .. "_Garden"
	gardenModel.Parent = workspace
	
	-- Create player's garden area
	local gardenCenter = GardenSystem.GetPlayerGardenPosition(userId)

	-- Create 9 plots in 3x3 grid
	for row = 1, 3 do
		for col = 1, 3 do
			local plotIndex = (row - 1) * 3 + col
			local plot = GardenSystem.CreatePlot(player, plotIndex, gardenCenter, row, col)
			-- Muta plotBase la gardenModel
			plot.part.Parent = gardenModel
			playerPlots[userId][plotIndex] = plot
		end
	end
	
	-- Adauga cufar lânga grid
	GardenSystem.AddChest(gardenCenter, gardenModel)
	
	-- Adauga gard în jurul gradinii
	GardenSystem.AddFence(gardenCenter, gardenModel)

	-- Placare nameplate tot la gardenModel
	GardenSystem.CreatePlayerNameplate(player, gardenCenter, gardenModel)

	print("Created garden for player:", player.Name)
end

function GardenSystem.GetPlayerGardenPosition(userId)
	-- Position players in circle around main island
	local angle = math.rad((userId % 12) * 30) -- Spread players around
	local radius = 120
	return Vector3.new(
		math.cos(angle) * radius,
		6, -- Elevated above main island
		math.sin(angle) * radius
	)
end

function GardenSystem.CreatePlot(player, plotIndex, centerPos, row, col)
	-- Calculate plot position in 3x3 grid
	local offsetX = (col - 2) * PLOT_SPACING -- -10, 0, 10
	local offsetZ = (row - 2) * PLOT_SPACING -- -10, 0, 10
	local plotPos = centerPos + Vector3.new(offsetX, 0, offsetZ)

	-- Create plot base
	local plotBase = Instance.new("Part")
	plotBase.Name = player.Name .. "_Plot_" .. plotIndex
	plotBase.Size = PLOT_SIZE
	plotBase.Position = plotPos
	plotBase.Anchored = true
	plotBase.Material = Enum.Material.Ground
	plotBase.BrickColor = BrickColor.new("Brown")
	plotBase.Parent = workspace

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

	-- Create plot status indicator
	local statusIndicator = Instance.new("Part")
	statusIndicator.Name = "StatusIndicator"
	statusIndicator.Size = Vector3.new(1, 0.2, 1)
	statusIndicator.Position = plotPos + Vector3.new(0.5, 0.5, 0.5)
	statusIndicator.Anchored = true
	statusIndicator.Material = Enum.Material.Neon
	statusIndicator.BrickColor = BrickColor.new("Lime green") -- Green = ready to plant
	statusIndicator.Shape = Enum.PartType.Cylinder
	statusIndicator.Parent = plotBase

	-- Create click detector for planting
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

function GardenSystem.CreatePlayerNameplate(player, centerPos, parentModel)
	-- Floating nameplate above garden
	local nameplate = Instance.new("Part")
	nameplate.Name = player.Name .. "_Nameplate"
	nameplate.Size = Vector3.new(10, 1, 3)
	nameplate.Position = centerPos + Vector3.new(0, 20, 0)
	nameplate.Anchored = true
	nameplate.CanCollide = false
	nameplate.Transparency = 1
	nameplate.Parent = parentModel or workspace

	-- Create text label
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

	-- Add glowing effect
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.fromRGB(150, 255, 200)

	-- Gentle floating animation
	local floatTween = TweenService:Create(
		nameplate,
		TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Position = centerPos + Vector3.new(0, 25, 0)}
	)
	floatTween:Play()
end

function GardenSystem.HandlePlotClick(clickingPlayer, plotData)
	-- Only owner can interact with their plots
	if clickingPlayer ~= plotData.owner then
		return
	end

	print("Plot clicked by:", clickingPlayer.Name, "Plot:", plotData.plotIndex)

	if plotData.seedType == nil then
		-- Empty plot - show seed selection (we'll implement this next)
		print("Empty plot - ready for planting")
		-- For now, plant a basic seed
		GardenSystem.PlantSeed(plotData, "basic_seed")
	elseif plotData.isReady then
		-- Ready to harvest
		GardenSystem.HarvestCrop(plotData)
	else
		-- Still growing
		local timeLeft = GardenSystem.GetGrowTimeLeft(plotData)
		print("Still growing... Time left:", timeLeft, "seconds")
	end
end

function GardenSystem.PlantSeed(plotData, seedType)
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	local seedData = GameConfig.Seeds[seedType]

	if not seedData then
		warn("Invalid seed type:", seedType)
		return
	end

	-- Update plot data
	plotData.seedType = seedType
	plotData.plantTime = tick()
	plotData.growthStage = 1
	plotData.isReady = false

	-- Update visual indicator
	plotData.indicator.BrickColor = BrickColor.new("Yellow") -- Growing

	-- Create growing crop visual
	GardenSystem.CreateCropVisual(plotData, seedData)

	-- Start growth timer
	GardenSystem.StartGrowthTimer(plotData, seedData)

	print("Planted", seedData.name, "in plot", plotData.plotIndex)
end

function GardenSystem.CreateCropVisual(plotData, seedData)
	if plotData.cropModel then
		plotData.cropModel:Destroy()
	end

	-- Create simple crop representation
	local crop = Instance.new("Part")
	crop.Name = "Crop_" .. seedData.name
	crop.Size = Vector3.new(2, 1, 2)
	crop.Position = plotData.part.Position + Vector3.new(0, 0.5, 0)
	crop.Anchored = true
	crop.Material = Enum.Material.Neon
	crop.BrickColor = BrickColor.new("Lime green")
	crop.Shape = Enum.PartType.Ball
	crop.Parent = plotData.part

	-- Add magical growing effect
	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(100, 255, 100)
	pointLight.Brightness = 1
	pointLight.Range = 10
	pointLight.Parent = crop

	plotData.cropModel = crop

	-- Growth animation
	local growTween = TweenService:Create(
		crop,
		TweenInfo.new(2, Enum.EasingStyle.Elastic),
		{Size = Vector3.new(3, 2, 3)}
	)
	growTween:Play()
end

function GardenSystem.StartGrowthTimer(plotData, seedData)
	spawn(function()
		wait(seedData.growTime)

		-- Crop is ready!
		plotData.isReady = true
		plotData.growthStage = 3

		-- Update visual indicators
		plotData.indicator.BrickColor = BrickColor.new("Bright green") -- Ready to harvest

		if plotData.cropModel then
			-- Make crop glow when ready
			plotData.cropModel.Material = Enum.Material.ForceField
			plotData.cropModel.BrickColor = BrickColor.new("Gold")

			-- Add harvest sparkles
			local attachment = Instance.new("Attachment")
			attachment.Parent = plotData.cropModel

			local particles = Instance.new("ParticleEmitter")
			particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			particles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
			particles.Size = NumberSequence.new(0.5)
			particles.Lifetime = NumberRange.new(2.0)
			particles.Rate = 30
			particles.Parent = attachment
		end

		print("Crop ready for harvest in plot", plotData.plotIndex)
	end)
end

function GardenSystem.HarvestCrop(plotData)
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	local seedData = GameConfig.Seeds[plotData.seedType]

	-- Give rewards (we'll integrate with economy system later)
	print("Harvested", seedData.name, "- Earned", seedData.coinReward, "coins and", seedData.expReward, "exp")

	-- Clear plot
	plotData.seedType = nil
	plotData.plantTime = nil
	plotData.growthStage = 0
	plotData.isReady = false

	-- Reset visual indicator
	plotData.indicator.BrickColor = BrickColor.new("Lime green") -- Ready to plant again

	-- Remove crop visual
	if plotData.cropModel then
		-- Harvest animation
		local harvestTween = TweenService:Create(
			plotData.cropModel,
			TweenInfo.new(1, Enum.EasingStyle.Back),
			{
				Size = Vector3.new(0.1, 0.1, 0.1),
				Position = plotData.cropModel.Position + Vector3.new(0, 10, 0)
			}
		)
		harvestTween:Play()

		harvestTween.Completed:Connect(function()
			plotData.cropModel:Destroy()
			plotData.cropModel = nil
		end)
	end

	print("Plot", plotData.plotIndex, "is now empty and ready for replanting")
end

function GardenSystem.GetGrowTimeLeft(plotData)
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	local seedData = GameConfig.Seeds[plotData.seedType]

	if not plotData.plantTime or not seedData then
		return 0
	end

	local elapsed = tick() - plotData.plantTime
	local timeLeft = math.max(0, seedData.growTime - elapsed)
	return math.floor(timeLeft)
end

--Initialize all garden at begining
local GARDEN_COUNT = 8
for i = 1, GARDEN_COUNT do
	GardenSystem.InitializePlayerGarden({UserId = i, Name = "Garden"..i})
end

-- Exemplu: ServerScriptService/CreateShopsScript.lua sau în Script la ini?ializarea lumii
local TERRAIN_HEIGHT = 5  -- pune aici înal?imea insulei tale

local function generateShops()
	local shopConfigs = {
		{name = "SeedShop", color = "Bright green", pos = Vector3.new(50, TERRAIN_HEIGHT + 6, 50)},
		{name = "AnimalShop", color = "Bright blue", pos = Vector3.new(-50, TERRAIN_HEIGHT + 6, 50)},
		{name = "GearShop", color = "Bright red", pos = Vector3.new(50, TERRAIN_HEIGHT + 6, -50)},
		{name = "CraftingStation", color = "Bright yellow", pos = Vector3.new(-50, TERRAIN_HEIGHT + 6, -50)}
	}

	for _, cfg in ipairs(shopConfigs) do
		-- Create shop model container
		local shopModel = Instance.new("Model")
		shopModel.Name = cfg.name
		shopModel.Parent = workspace

		-- Create the visible building part
		local building = Instance.new("Part")
		building.Name = "Building"
		building.Size = Vector3.new(16, 12, 16)
		building.Material = Enum.Material.Brick
		building.BrickColor = BrickColor.new(cfg.color)
		building.Anchored = true
		building.Position = cfg.pos
		building.Parent = shopModel

		-- Create shop sign
		local sign = Instance.new("Part")
		sign.Name = "Sign"
		sign.Size = Vector3.new(12, 4, 0.5)
		sign.Material = Enum.Material.Wood
		sign.BrickColor = BrickColor.new("Brown")
		sign.Anchored = true
		sign.Position = cfg.pos + Vector3.new(0, 8, 10)
		sign.Parent = shopModel
		
		-- Add ClickDetector for BuildingHandler
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.Name = "ClickDetector"
		clickDetector.MaxActivationDistance = 20
		clickDetector.Parent = building

		local gui = Instance.new("SurfaceGui", sign)
		gui.Face = Enum.NormalId.Front

		local textLabel = Instance.new("TextLabel", gui)
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = cfg.name
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.GothamBold

		debugLog("Generated shop: " .. cfg.name)
	end
end

-- APEL FUNCTIE, ca sa apara shop-urile la start!
generateShops()
function GardenSystem.GetPlayerPlots(player)
	return playerPlots[player.UserId] or {}
end



return GardenSystem
