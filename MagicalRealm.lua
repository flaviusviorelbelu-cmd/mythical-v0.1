-- Magical Realm Generator (ServerScript)
local MagicalRealm = {}
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local exclusionRadius = 20 
local TERRAIN_HEIGHT = 6
local shopsPositions = {  -- folose?te cfg.pos din codul tau de shops
	Vector3.new(50, TERRAIN_HEIGHT + 6, 50),
	Vector3.new(-50, TERRAIN_HEIGHT + 6, 50),
	Vector3.new(50, TERRAIN_HEIGHT + 6, -50),
	Vector3.new(-50, TERRAIN_HEIGHT + 6, -50)
}

local DEBUG_MODE = true

-- Debug logger
local function debugLog(msg, lvl)
	if DEBUG_MODE then
		print("[MapGenerator][" .. (lvl or "INFO") .. "] " .. msg)
	end
end

-- Create the magical world environment
function MagicalRealm.CreateWorld()
	local workspace = game.Workspace

	-- Set up magical lighting
	MagicalRealm.SetupMagicalLighting()

	-- Create floating islands for players
	local mainIsland = MagicalRealm.CreateMainIsland()

	-- Add magical decorations
	MagicalRealm.AddFloatingCrystals(mainIsland)
	MagicalRealm.AddGlowingTrees(mainIsland)
	MagicalRealm.CreateMagicalPortal(mainIsland)

	-- Start atmospheric effects
	MagicalRealm.StartSkyColorCycle()
	MagicalRealm.CreateFloatingParticles()

	return mainIsland
end

function MagicalRealm.SetupMagicalLighting()
	-- Magical atmosphere settings
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(100, 150, 255)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 200, 255)
	Lighting.ColorShift_Bottom = Color3.fromRGB(150, 255, 200)

	-- Add atmospheric fog
	Lighting.FogEnd = 500
	Lighting.FogColor = Color3.fromRGB(200, 150, 255)

	-- Create magical sky
	local sky = Instance.new("Sky")
	sky.SkyboxBk = "rbxasset://sky/space_02.jpg"
	sky.SkyboxDn = "rbxasset://sky/space_02.jpg"
	sky.SkyboxFt = "rbxasset://sky/space_02.jpg"
	sky.SkyboxLf = "rbxasset://sky/space_02.jpg"
	sky.SkyboxRt = "rbxasset://sky/space_02.jpg"
	sky.SkyboxUp = "rbxasset://sky/space_02.jpg"
	sky.Parent = Lighting
end

local function scatterAssets(modelName, count, yMin, yMax, radius)
	for i = 1, count do
		local asset = Instance.new("Part")
		asset.Name = modelName
		asset.Shape = Enum.PartType.Ball
		asset.Size = Vector3.new(3, 5, 3)
		asset.Position = Vector3.new(
			math.random(-radius, radius),
			math.random(yMin, yMax),
			math.random(-radius, radius)
		)
		asset.Anchored = true
		asset.Material = Enum.Material.Neon
		asset.Color = modelName == "Crystal" and Color3.fromRGB(255, 0, 255) or Color3.fromRGB(128, 255, 100)

		-- For crystals: add sparkles
		if modelName == "Crystal" then
			local p = Instance.new("ParticleEmitter")
			p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			p.Color = ColorSequence.new(asset.Color)
			p.Lifetime = NumberRange.new(2)
			p.Rate = 20
			p.Parent = asset
		end

		asset.Parent = workspace
	end
end

function MagicalRealm.CreateMainIsland()
	-- Main floating island
	local island = Instance.new("Part")
	island.Name = "MagicalIsland"
	island.Size = Vector3.new(512, 2, 512)
	island.Position = Vector3.new(0, 5, 0)
	island.Anchored = true
	island.Material = Enum.Material.Grass
	island.BrickColor = BrickColor.new("Bright green")
	island.Parent = workspace

	-- Add magical glow effect
	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(150, 255, 200)
	pointLight.Brightness = 0.5
	pointLight.Range = 100
	pointLight.Parent = island

	return island
end

function MagicalRealm.AddFloatingCrystals(island)
	local crystals = {}

	for i = 1, 15 do
		local crystal = Instance.new("Part")
		crystal.Name = "FloatingCrystal"
		crystal.Size = Vector3.new(2, 4, 2)
		crystal.Material = Enum.Material.Neon
		crystal.BrickColor = BrickColor.new("Bright blue")
		crystal.Anchored = true
		crystal.CanCollide = false

		-- Random position around island
		local angle = math.rad(i * 24) -- Spread crystals in circle
		local radius = math.random(60, 90)
		crystal.Position = Vector3.new(
			math.cos(angle) * radius,
			math.random(15, 35),
			math.sin(angle) * radius
		)

		crystal.Parent = workspace
		table.insert(crystals, crystal)

		-- Add magical particle effect
		local attachment = Instance.new("Attachment")
		attachment.Parent = crystal

		local particles = Instance.new("ParticleEmitter")
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
		particles.Size = NumberSequence.new(0.5)
		particles.Lifetime = NumberRange.new(2.0)
		particles.Rate = 20
		particles.Parent = attachment
	end

	-- Animate floating crystals
	MagicalRealm.AnimateFloatingCrystals(crystals)

	return crystals
end

function isTooCloseToShops(treePos)
	for _, shopPos in ipairs(shopsPositions) do
		local horizontalDist = (Vector3.new(treePos.X, 0, treePos.Z) - Vector3.new(shopPos.X, 0, shopPos.Z)).Magnitude
		if horizontalDist < exclusionRadius then
			return true
		end
	end
	return false
end

function MagicalRealm.AddGlowingTrees(island)
	local trees = {}
	local exclusionRadius = 20 
	

	for i = 1, 8 do
		local set = false
		local try = 0
		while not set and try < 10 do 
			try = try + 1
		end
		-- Tree trunk
		local trunk = Instance.new("Part")
		trunk.Name = "MagicalTreeTrunk"
		trunk.Size = Vector3.new(2, 8, 2)
		trunk.Material = Enum.Material.Wood
		trunk.BrickColor = BrickColor.new("Brown")
		trunk.Anchored = true

		-- Tree crown
		local crown = Instance.new("Part")
		crown.Name = "MagicalTreeCrown"
		crown.Size = Vector3.new(8, 8, 8)
		crown.Shape = Enum.PartType.Ball
		crown.Material = Enum.Material.Neon
		crown.BrickColor = BrickColor.new("Alder")
		crown.Anchored = true
		crown.CanCollide = false

		-- Position around island edge
		local angle = math.rad(i * 45)
		local radius = 75
		local treePos = Vector3.new(
			math.random(-100, 100),
			6,
			math.random(-100, 100)
		)
		if not isTooCloseToShops(treePos) then
		trunk.Position = treePos
		crown.Position = treePos + Vector3.new(0, 8, 0)
		trunk.Parent = workspace
		crown.Parent = workspace
		
		set = true

		-- Add glowing effect
		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.fromRGB(150, 255, 150)
		pointLight.Brightness = 2
		pointLight.Range = 20
		pointLight.Parent = crown

		table.insert(trees, {trunk = trunk, crown = crown})
		end
	end

	return trees
end

function MagicalRealm.CreateMagicalPortal(island)
	-- Central spinning portal
	local portal = Instance.new("Part")
	portal.Name = "GardenPortal"
	portal.Size = Vector3.new(10, 1, 10)
	portal.Position = Vector3.new(0, 11, 0)
	portal.Anchored = true
	portal.Shape = Enum.PartType.Cylinder
	portal.Material = Enum.Material.Neon
	portal.BrickColor = BrickColor.new("Magenta")
	portal.CanCollide = false
	portal.Parent = workspace

	-- Portal spinning animation
	local spinTween = TweenService:Create(
		portal,
		TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{Rotation = Vector3.new(0, 360, 0)}
	)
	spinTween:Play()

	return portal
end

function MagicalRealm.AnimateFloatingCrystals(crystals)
	for _, crystal in pairs(crystals) do
		-- Gentle floating animation (unchanged)
		local originalPos = crystal.Position
		local floatTween = TweenService:Create(
			crystal,
			TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Position = originalPos + Vector3.new(0, 5, 0)}
		)
		floatTween:Play()

		-- Color changing effect: tween the Color property, not BrickColor
		local colorTween = TweenService:Create(
			crystal,
			TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
			{Color = Color3.fromRGB(255, 0, 255)}  -- Magenta
		)
		colorTween:Play()
	end
end

function MagicalRealm.StartSkyColorCycle()
	-- Color-cycling sky effect
	spawn(function()
		local colors = {
			Color3.fromRGB(255, 200, 255), -- Pink
			Color3.fromRGB(200, 255, 255), -- Cyan  
			Color3.fromRGB(255, 255, 200), -- Yellow
			Color3.fromRGB(200, 200, 255)  -- Blue
		}

		local currentIndex = 1

		while true do
			local nextIndex = currentIndex % #colors + 1

			--local colorTween = TweenService:Create(
				--Lighting,
				--TweenInfo.new(10, Enum.EasingStyle.Linear),
				--{ColorShift_Top = colors[nextIndex]}
			--)
			--colorTween:Play()

			currentIndex = nextIndex
			wait(10)
		end
	end)
end

function MagicalRealm.CreateFloatingParticles()
	-- Ambient magical particles
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.MagicalIsland

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 255, 200))
	}
	particles.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.8)
	}
	particles.Lifetime = NumberRange.new(5.0, 8.0)
	particles.Rate = 5
	particles.VelocityInheritance = 0
	particles.Speed = NumberRange.new(2, 4)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Parent = attachment
end
local function createFloatingIsland(position, size)
	local island = Instance.new("Part")
	island.Size = size -- e.g., Vector3.new(70, 6, 70)
	island.Position = position
	island.Anchored = true
	island.Material = Enum.Material.Grass
	island.Color = Color3.fromRGB(80, 200, 140)
	island.TopSurface = Enum.SurfaceType.Smooth
	island.Parent = workspace

	-- Underside rock
	local root = Instance.new("Part")
	root.Shape = Enum.PartType.Ball
	root.Size = Vector3.new(size.X/1.5, size.Y*2, size.Z/1.5)
	root.Position = position - Vector3.new(0, size.Y/1.6, 0)
	root.Anchored = true
	root.Material = Enum.Material.Slate
	root.Color = Color3.fromRGB(60, 60, 120)
	root.Parent = workspace

	return island
end

local portal = Instance.new("Part")
portal.Shape = Enum.PartType.Cylinder
portal.Size = Vector3.new(10, 1, 10)
portal.Position = Vector3.new(0, 40, 0)
portal.Anchored = true
portal.Material = Enum.Material.Neon
portal.Color = Color3.fromRGB(255, 0, 255)
portal.Parent = workspace
 
--create three islands
createFloatingIsland(Vector3.new(0,35,0), Vector3.new(70,6,70))
createFloatingIsland(Vector3.new(90,50,-40), Vector3.new(25,5,25))
createFloatingIsland(Vector3.new(-70,40,60), Vector3.new(40,5,40))
--Magic Trees and Crystals creatuion
scatterAssets("Crystal", 12, 40, 70, 90)
scatterAssets("MagicTree", 8, 37, 50, 80)



return MagicalRealm
