-- GardenClient.lua (StarterPlayerScripts)
-- Interactive garden system for planting and harvesting

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

print("[GardenClient] Initializing garden system...")

-- Wait for remote events
local remoteEvents = {}
local remoteFunctions = {}

spawn(function()
    remoteEvents.PlantSeedEvent = ReplicatedStorage:WaitForChild("PlantSeedEvent")
    remoteEvents.HarvestPlantEvent = ReplicatedStorage:WaitForChild("HarvestPlantEvent")
    remoteEvents.ShowPlotOptionsEvent = ReplicatedStorage:WaitForChild("ShowPlotOptionsEvent")
    remoteEvents.SellPlantEvent = ReplicatedStorage:WaitForChild("SellPlantEvent")
    remoteEvents.RequestInventoryUpdate = ReplicatedStorage:WaitForChild("RequestInventoryUpdate")
    remoteEvents.ShowFeedback = ReplicatedStorage:WaitForChild("ShowFeedback")
    remoteFunctions.GetGardenPlots = ReplicatedStorage:WaitForChild("GetGardenPlots")
    remoteFunctions.GetPlayerStats = ReplicatedStorage:WaitForChild("GetPlayerStats")
    print("[GardenClient] Remote connections established")
end)

-- Garden UI variables
local gardenGui = nil
local isGardenOpen = false
local plotInteractionGui = nil
local selectedPlot = nil
local connection = nil

-- Player inventory data
local playerInventory = {
    seeds = {
        basic_seed = {count = 0, name = "Magic Wheat", plantTime = 30, icon = "??"},
        stellar_seed = {count = 0, name = "Stellar Corn", plantTime = 60, icon = "??"},
        cosmic_seed = {count = 0, name = "Cosmic Berries", plantTime = 120, icon = "??"}
    }
}

-- Garden plot data
local gardenPlots = {}

-- In GardenClient.lua, replace the updateInventoryData function:
local function updateInventoryData()
	print("[GardenClient] Updating inventory data...")

	spawn(function()
		if remoteFunctions.GetPlayerStats then
			local success, stats = pcall(function()
				return remoteFunctions.GetPlayerStats:InvokeServer()
			end)

			if success and stats then
				print("[GardenClient] Received stats from server")
				print("[GardenClient] Stats structure:", stats)

				if stats.inventory and stats.inventory.seeds then
					print("[GardenClient] Found inventory.seeds:", stats.inventory.seeds)

					-- Update each seed type explicitly
					for seedType, count in pairs(stats.inventory.seeds) do
						if playerInventory.seeds[seedType] then
							playerInventory.seeds[seedType].count = count
							print("[GardenClient] Updated", seedType, "count to:", count)
						end
					end

					print("[GardenClient] Final playerInventory.seeds:")
					for seedType, seedData in pairs(playerInventory.seeds) do
						print("  ", seedType, "=", seedData.count)
					end
				else
					print("[GardenClient] NO inventory.seeds found in server response")
					if stats.inventory then
						print("[GardenClient] Inventory exists but no seeds:", stats.inventory)
					else
						print("[GardenClient] No inventory at all in response")
					end
				end
			else
				print("[GardenClient] Failed to get stats from server")
			end
		end
	end)
end



-- Get garden plot data
local function updateGardenData()
    spawn(function()
        if remoteFunctions.GetGardenPlots then
            local success, plots = pcall(function()
                return remoteFunctions.GetGardenPlots:InvokeServer()
            end)
            
            if success and plots then
                gardenPlots = plots
                print("[GardenClient] Updated garden plots:", plots)
            end
        end
    end)
end

-- Find player's garden in workspace
local function findPlayerGarden()
	-- Try multiple possible garden names
	local possibleNames = {
		"Garden_" .. player.Name,           -- Garden_deiandario
		player.Name .. "_Garden",           -- deiandario_Garden
		"PlayerGarden_" .. player.Name,     -- PlayerGarden_deiandario
		"Garden" .. player.UserId,          -- Garden2925485112
		"Garden1"                           -- Default garden 1
	}

	for _, name in ipairs(possibleNames) do
		local garden = Workspace:FindFirstChild(name)
		if garden then
			print("[GardenClient] Found garden:", name)
			return garden
		end
	end

	-- Try to find any garden with plots
	for _, obj in pairs(Workspace:GetChildren()) do
		if obj:FindFirstChild("Plots") and obj:FindFirstChild("Plots"):GetChildren()[1] then
			print("[GardenClient] Found garden by plots:", obj.Name)
			return obj
		end
	end

	print("[GardenClient] No garden found, will retry...")
	return nil
end


-- Create plot interaction UI
local function createPlotInteractionUI(plot, plotData)
	if plotInteractionGui then plotInteractionGui:Destroy() end

	print("[GardenClient] Creating interaction UI for plot", plotData.plotNumber)
	print("[GardenClient] Current inventory:", playerInventory.seeds)

	plotInteractionGui = Instance.new("ScreenGui")
	plotInteractionGui.Name = "PlotInteractionGui"
	plotInteractionGui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "InteractionFrame"
	mainFrame.Size = UDim2.new(0, 350, 0, 250)
	mainFrame.Position = UDim2.new(0.5, -175, 0.5, -125)
	mainFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = plotInteractionGui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = mainFrame

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -60, 0, 40)
	titleLabel.Position = UDim2.new(0, 10, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "?? Garden Plot " .. (plotData.plotNumber or "?")
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = mainFrame

	-- Status label
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -20, 0, 30)
	statusLabel.Position = UDim2.new(0, 10, 0, 50)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(149, 165, 166)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = mainFrame

	-- Check plot status
	if not plotData.crop then
		-- Empty plot - show planting options
		statusLabel.Text = "Empty plot - ready for planting"

		-- Check if player has any seeds
		local hasSeeds = false
		for seedType, seedData in pairs(playerInventory.seeds) do
			if seedData.count > 0 then
				hasSeeds = true
				break
			end
		end

		if not hasSeeds then
			-- No seeds available
			local noSeedsLabel = Instance.new("TextLabel")
			noSeedsLabel.Size = UDim2.new(1, -20, 0, 80)
			noSeedsLabel.Position = UDim2.new(0, 10, 0, 90)
			noSeedsLabel.BackgroundTransparency = 1
			noSeedsLabel.Text = "?? No seeds available!\n\nVisit the shop to buy seeds first."
			noSeedsLabel.TextColor3 = Color3.fromRGB(230, 126, 34)
			noSeedsLabel.TextScaled = true
			noSeedsLabel.Font = Enum.Font.Gotham
			noSeedsLabel.Parent = mainFrame
		else
			-- Create seed selection
			local seedFrame = Instance.new("ScrollingFrame")
			seedFrame.Size = UDim2.new(1, -20, 0, 120)
			seedFrame.Position = UDim2.new(0, 10, 0, 90)
			seedFrame.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
			seedFrame.BorderSizePixel = 0
			seedFrame.ScrollBarThickness = 6
			seedFrame.Parent = mainFrame

			local seedCorner = Instance.new("UICorner")
			seedCorner.CornerRadius = UDim.new(0, 8)
			seedCorner.Parent = seedFrame

			local listLayout = Instance.new("UIListLayout")
			listLayout.Padding = UDim.new(0, 5)
			listLayout.Parent = seedFrame

			print("[GardenClient] Creating seed buttons...")

			for seedType, seedData in pairs(playerInventory.seeds) do
				print("[GardenClient] Checking seed:", seedType, "count:", seedData.count)

				if seedData.count > 0 then
					local seedButton = Instance.new("TextButton")
					seedButton.Size = UDim2.new(1, -10, 0, 35)
					seedButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
					seedButton.BorderSizePixel = 0
					seedButton.Text = seedData.icon .. " " .. seedData.name .. " (x" .. seedData.count .. ")"
					seedButton.TextColor3 = Color3.new(1, 1, 1)
					seedButton.TextScaled = true
					seedButton.Font = Enum.Font.GothamBold
					seedButton.Parent = seedFrame

					local buttonCorner = Instance.new("UICorner")
					buttonCorner.CornerRadius = UDim.new(0, 6)
					buttonCorner.Parent = seedButton

					seedButton.MouseButton1Click:Connect(function()
						print("[GardenClient] Planting", seedType, "in plot", plotData.plotNumber)
						if remoteEvents.PlantSeedEvent then
							remoteEvents.PlantSeedEvent:FireServer(plotData.plotNumber, seedType)
						end
						plotInteractionGui:Destroy()
						plotInteractionGui = nil

						if _G.MainClient then
							_G.MainClient.ShowFeedback("Planting " .. seedData.name .. "...", "success")
						end
					end)

					print("[GardenClient] Created seed button for:", seedType)
				end
			end

			seedFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
		end

	elseif plotData.isReady then
		-- Ready to harvest
		statusLabel.Text = "?? Ready to harvest!"
		statusLabel.TextColor3 = Color3.fromRGB(46, 204, 113)

		local harvestButton = Instance.new("TextButton")
		harvestButton.Size = UDim2.new(0, 200, 0, 40)
		harvestButton.Position = UDim2.new(0.5, -100, 0, 100)
		harvestButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		harvestButton.Text = "?? Harvest Crop"
		harvestButton.TextColor3 = Color3.new(1, 1, 1)
		harvestButton.TextScaled = true
		harvestButton.Font = Enum.Font.GothamBold
		harvestButton.BorderSizePixel = 0
		harvestButton.Parent = mainFrame

		local harvestCorner = Instance.new("UICorner")
		harvestCorner.CornerRadius = UDim.new(0, 8)
		harvestCorner.Parent = harvestButton

		harvestButton.MouseButton1Click:Connect(function()
			print("[GardenClient] Harvesting plot", plotData.plotNumber)
			if remoteEvents.HarvestPlantEvent then
				remoteEvents.HarvestPlantEvent:FireServer(plotData.plotNumber)
			end
			plotInteractionGui:Destroy()
			plotInteractionGui = nil
		end)

	else
		-- Growing
		local timeLeft = plotData.timeRemaining or 0
		statusLabel.Text = "?? Growing... " .. math.floor(timeLeft) .. "s remaining"
		statusLabel.TextColor3 = Color3.fromRGB(230, 126, 34)

		local progressFrame = Instance.new("Frame")
		progressFrame.Size = UDim2.new(1, -20, 0, 20)
		progressFrame.Position = UDim2.new(0, 10, 0, 100)
		progressFrame.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
		progressFrame.BorderSizePixel = 0
		progressFrame.Parent = mainFrame

		local progressCorner = Instance.new("UICorner")
		progressCorner.CornerRadius = UDim.new(0, 10)
		progressCorner.Parent = progressFrame

		local progressBar = Instance.new("Frame")
		progressBar.Size = UDim2.new(math.max(0, (1 - timeLeft / (plotData.growTime or 60))), 0, 1, 0)
		progressBar.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		progressBar.BorderSizePixel = 0
		progressBar.Parent = progressFrame

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 10)
		barCorner.Parent = progressBar
	end

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 40, 0, 30)
	closeButton.Position = UDim2.new(1, -50, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	closeButton.Text = "?"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.BorderSizePixel = 0
	closeButton.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		plotInteractionGui:Destroy()
		plotInteractionGui = nil
	end)

	-- Animation
	mainFrame.Position = UDim2.new(0.5, -175, 1, 0)
	local openTween = TweenService:Create(
		mainFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -175, 0.5, -125)}
	)
	openTween:Play()
end


-- Handle plot clicking
local function setupPlotInteractions()
	local garden = findPlayerGarden()
	if not garden then
		print("[GardenClient] No garden found, retrying in 3 seconds...")
		wait(3)
		garden = findPlayerGarden()
		if not garden then
			print("[GardenClient] Garden still not found after retry")
			return
		end
	end

	print("[GardenClient] Setting up interactions for garden:", garden.Name)

	local plots = garden:FindFirstChild("Plots")
	if not plots then
		-- Try finding plots directly in the garden
		for _, child in pairs(garden:GetChildren()) do
			if child.Name:match("Plot") and child:IsA("BasePart") then
				print("[GardenClient] Found plot directly in garden:", child.Name)

				local clickDetector = child:FindFirstChildOfClass("ClickDetector")
				if not clickDetector then
					clickDetector = Instance.new("ClickDetector")
					clickDetector.MaxActivationDistance = 20
					clickDetector.Parent = child
				end

				clickDetector.MouseClick:Connect(function()
					local plotNumber = tonumber(child.Name:match("%d+"))
					if plotNumber then
						print("[GardenClient] Clicked plot", plotNumber)
						updateInventoryData()
						updateGardenData()

						-- FIX: Make sure plotNumber is included in plotData
						local plotData = gardenPlots[plotNumber] or {plotNumber = plotNumber}
						plotData.plotNumber = plotNumber  -- Ensure this is set

						createPlotInteractionUI(child, plotData)
					end
				end)

			end
		end
		return
	end

	-- Original code for plots in Plots folder
	for _, plot in pairs(plots:GetChildren()) do
		if plot:IsA("BasePart") and plot.Name:match("Plot") then
			local clickDetector = plot:FindFirstChildOfClass("ClickDetector")
			if not clickDetector then
				clickDetector = Instance.new("ClickDetector")
				clickDetector.MaxActivationDistance = 20
				clickDetector.Parent = plot
			end

			clickDetector.MouseClick:Connect(function()
				local plotNumber = tonumber(plot.Name:match("%d+"))
				if plotNumber then
					print("[GardenClient] Clicked plot", plotNumber)
					updateInventoryData()
					updateGardenData()

					local plotData = gardenPlots[plotNumber] or {plotNumber = plotNumber}
					createPlotInteractionUI(plot, plotData)
				end
			end)
		end
	end

	print("[GardenClient] Plot interactions setup complete")
end

-- Create garden overview UI
local function createGardenUI()
    if gardenGui then gardenGui:Destroy() end
    
    gardenGui = Instance.new("ScreenGui")
    gardenGui.Name = "GardenGui"
    gardenGui.Parent = playerGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "GardenFrame"
    mainFrame.Size = UDim2.new(0, 800, 0, 600)
    mainFrame.Position = UDim2.new(0.5, -400, 0.5, -300)
    mainFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gardenGui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 15)
    frameCorner.Parent = mainFrame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 60)
    titleBar.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 15)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -120, 1, 0)
    titleLabel.Position = UDim2.new(0, 20, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "?? My Garden"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 80, 1, -10)
    closeButton.Position = UDim2.new(1, -90, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    closeButton.Text = "? Close"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        _G.GardenClient.ToggleGardenMenu()
    end)
    
    -- Content area
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -80)
    contentFrame.Position = UDim2.new(0, 10, 0, 70)
    contentFrame.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
    contentFrame.BorderSizePixel = 0
    contentFrame.Parent = mainFrame
    
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 12)
    contentCorner.Parent = contentFrame
    
    -- Instructions
    local instructionLabel = Instance.new("TextLabel")
    instructionLabel.Size = UDim2.new(1, -20, 0, 100)
    instructionLabel.Position = UDim2.new(0, 10, 0, 20)
    instructionLabel.BackgroundTransparency = 1
    instructionLabel.Text = "?? Welcome to your garden!\n\n• Click on any plot to plant seeds or harvest crops\n• Buy seeds from the shop first\n• Watch your plants grow over time"
    instructionLabel.TextColor3 = Color3.new(1, 1, 1)
    instructionLabel.TextScaled = true
    instructionLabel.Font = Enum.Font.Gotham
    instructionLabel.Parent = contentFrame
    
    -- Teleport to garden button
    local teleportButton = Instance.new("TextButton")
    teleportButton.Size = UDim2.new(0, 200, 0, 50)
    teleportButton.Position = UDim2.new(0.5, -100, 0, 150)
    teleportButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    teleportButton.Text = "?? Go to My Garden"
    teleportButton.TextColor3 = Color3.new(1, 1, 1)
    teleportButton.TextScaled = true
    teleportButton.Font = Enum.Font.GothamBold
    teleportButton.BorderSizePixel = 0
    teleportButton.Parent = contentFrame
    
    local teleportCorner = Instance.new("UICorner")
    teleportCorner.CornerRadius = UDim.new(0, 10)
    teleportCorner.Parent = teleportButton
    
    teleportButton.MouseButton1Click:Connect(function()
        local garden = findPlayerGarden()
        if garden and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local teleportPosition = garden.PrimaryPart.Position + Vector3.new(0, 5, 15)
            player.Character.HumanoidRootPart.CFrame = CFrame.new(teleportPosition)
            _G.GardenClient.ToggleGardenMenu() -- Close menu after teleport
            
            if _G.MainClient then
                _G.MainClient.ShowFeedback("Teleported to your garden!", "success")
            end
        else
            if _G.MainClient then
                _G.MainClient.ShowFeedback("Garden not found!", "error")
            end
        end
    end)
    
    -- Garden stats
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(1, -20, 0, 80)
    statsLabel.Position = UDim2.new(0, 10, 0, 220)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "?? Garden Statistics\n\nPlots: 9 | Active: 0 | Ready: 0"
    statsLabel.TextColor3 = Color3.fromRGB(149, 165, 166)
    statsLabel.TextScaled = true
    statsLabel.Font = Enum.Font.Gotham
    statsLabel.Parent = contentFrame
    
    -- Animation
    mainFrame.Position = UDim2.new(0.5, -400, 1, 0)
    local openTween = TweenService:Create(
        mainFrame,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -400, 0.5, -300)}
    )
    openTween:Play()
end

-- Listen for server updates
spawn(function()
    -- Listen for plot data changes
    local plotDataChangedEvent = ReplicatedStorage:WaitForChild("PlotDataChanged")
    plotDataChangedEvent.OnClientEvent:Connect(function(plotNumber, newData)
        print("[GardenClient] Plot", plotNumber, "data changed:", newData)
        if gardenPlots[plotNumber] then
            gardenPlots[plotNumber] = newData
        end
    end)
end)

-- === PUBLIC FUNCTIONS ===
_G.GardenClient = {
    ToggleGardenMenu = function()
        if isGardenOpen then
            -- Close garden menu
            if gardenGui then
                local mainFrame = gardenGui:FindFirstChild("GardenFrame")
                if mainFrame then
                    local closeTween = TweenService:Create(
                        mainFrame,
                        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
                        {Position = UDim2.new(0.5, -400, 1, 0)}
                    )
                    closeTween:Play()
                    closeTween.Completed:Connect(function()
                        gardenGui:Destroy()
                        gardenGui = nil
                    end)
                end
            end
            isGardenOpen = false
            print("[GardenClient] Garden menu closed")
        else
            -- Open garden menu
            updateInventoryData()
            updateGardenData()
            createGardenUI()
            isGardenOpen = true
            print("[GardenClient] Garden menu opened")
        end
    end,
    
    -- Setup plot interactions
    SetupPlotInteractions = function()
        setupPlotInteractions()
    end,
    
    -- Get current garden data
    GetGardenData = function()
        return gardenPlots
    end,
    
    -- Update garden display
    RefreshGarden = function()
        updateGardenData()
        updateInventoryData()
    end
}

-- Auto-setup when player's character spawns
local function onCharacterAdded()
    wait(5) -- Give time for garden to be created
    setupPlotInteractions()
end

if player.Character then
    onCharacterAdded()
end

player.CharacterAdded:Connect(onCharacterAdded)

print("[GardenClient] Garden system initialized!")
