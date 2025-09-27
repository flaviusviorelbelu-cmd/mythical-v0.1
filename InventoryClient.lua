-- InventoryClient.lua (StarterPlayerScripts)
-- Complete inventory system for seeds, crops, and pets

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[InventoryClient] Initializing inventory system...")

-- Wait for remote events
local remoteEvents = {}
local remoteFunctions = {}

spawn(function()
	remoteEvents.RequestInventoryUpdate = ReplicatedStorage:WaitForChild("RequestInventoryUpdate")
	remoteEvents.SellPlantEvent = ReplicatedStorage:WaitForChild("SellPlantEvent")
	remoteEvents.ShowFeedback = ReplicatedStorage:WaitForChild("ShowFeedback")
	remoteFunctions.GetPlayerStats = ReplicatedStorage:WaitForChild("GetPlayerStats")
	remoteFunctions.GetPetData = ReplicatedStorage:WaitForChild("GetPetData")
	print("[InventoryClient] Remote connections established")
end)

-- Inventory UI variables
local inventoryGui = nil
local isInventoryOpen = false

-- Sample data structures (will be updated from server)
local inventoryData = {
	seeds = {
		basic_seed = {count = 0, name = "Magic Wheat", icon = "??"},
		stellar_seed = {count = 0, name = "Stellar Corn", icon = "??"},
		cosmic_seed = {count = 0, name = "Cosmic Berries", icon = "??"}
	},
	crops = {
		magic_wheat = {count = 0, name = "Magic Wheat", sellPrice = 15, icon = "??"},
		stellar_corn = {count = 0, name = "Stellar Corn", sellPrice = 80, icon = "??"},
		cosmic_berries = {count = 0, name = "Cosmic Berries", sellPrice = 350, icon = "??"}
	},
	pets = {}
}

-- Update inventory data from server
local function updateInventoryData()
	spawn(function()
		if remoteFunctions.GetPlayerStats then
			local success, stats = pcall(function()
				return remoteFunctions.GetPlayerStats:InvokeServer()
			end)

			if success and stats then
				print("[InventoryClient] Received player stats")
				-- Update inventory counts if available
				-- Note: You may need to modify server to send inventory data
			end
		end

		-- Request inventory update
		if remoteEvents.RequestInventoryUpdate then
			remoteEvents.RequestInventoryUpdate:FireServer()
		end
	end)
end

-- Create inventory UI
local function createInventoryUI()
	if inventoryGui then inventoryGui:Destroy() end

	-- Main inventory GUI
	inventoryGui = Instance.new("ScreenGui")
	inventoryGui.Name = "InventoryGui"
	inventoryGui.Parent = playerGui

	-- Background frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "InventoryFrame"
	mainFrame.Size = UDim2.new(0, 900, 0, 700)
	mainFrame.Position = UDim2.new(0.5, -450, 0.5, -350)
	mainFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = inventoryGui

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
	titleLabel.Text = "?? My Inventory"
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
		_G.InventoryClient.ToggleInventory()
	end)

	-- Tab buttons
	local tabFrame = Instance.new("Frame")
	tabFrame.Size = UDim2.new(1, -20, 0, 50)
	tabFrame.Position = UDim2.new(0, 10, 0, 70)
	tabFrame.BackgroundTransparency = 1
	tabFrame.Parent = mainFrame

	local seedTabButton = Instance.new("TextButton")
	seedTabButton.Size = UDim2.new(0.33, -5, 1, 0)
	seedTabButton.Position = UDim2.new(0, 0, 0, 0)
	seedTabButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	seedTabButton.Text = "?? Seeds"
	seedTabButton.TextColor3 = Color3.new(1, 1, 1)
	seedTabButton.TextScaled = true
	seedTabButton.Font = Enum.Font.GothamBold
	seedTabButton.BorderSizePixel = 0
	seedTabButton.Parent = tabFrame

	local seedTabCorner = Instance.new("UICorner")
	seedTabCorner.CornerRadius = UDim.new(0, 8)
	seedTabCorner.Parent = seedTabButton

	local cropTabButton = Instance.new("TextButton")
	cropTabButton.Size = UDim2.new(0.33, -5, 1, 0)
	cropTabButton.Position = UDim2.new(0.33, 2.5, 0, 0)
	cropTabButton.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
	cropTabButton.Text = "?? Crops"
	cropTabButton.TextColor3 = Color3.new(1, 1, 1)
	cropTabButton.TextScaled = true
	cropTabButton.Font = Enum.Font.GothamBold
	cropTabButton.BorderSizePixel = 0
	cropTabButton.Parent = tabFrame

	local cropTabCorner = Instance.new("UICorner")
	cropTabCorner.CornerRadius = UDim.new(0, 8)
	cropTabCorner.Parent = cropTabButton

	local petTabButton = Instance.new("TextButton")
	petTabButton.Size = UDim2.new(0.33, -5, 1, 0)
	petTabButton.Position = UDim2.new(0.66, 5, 0, 0)
	petTabButton.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
	petTabButton.Text = "?? Pets"
	petTabButton.TextColor3 = Color3.new(1, 1, 1)
	petTabButton.TextScaled = true
	petTabButton.Font = Enum.Font.GothamBold
	petTabButton.BorderSizePixel = 0
	petTabButton.Parent = tabFrame

	local petTabCorner = Instance.new("UICorner")
	petTabCorner.CornerRadius = UDim.new(0, 8)
	petTabCorner.Parent = petTabButton

	-- Content frame
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Size = UDim2.new(1, -20, 1, -140)
	contentFrame.Position = UDim2.new(0, 10, 0, 130)
	contentFrame.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 8
	contentFrame.Parent = mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 12)
	contentCorner.Parent = contentFrame

	-- Create seeds tab
	local function createSeedsTab()
		contentFrame:ClearAllChildren()

		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellSize = UDim2.new(0, 200, 0, 120)
		gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
		gridLayout.Parent = contentFrame

		for seedType, seedData in pairs(inventoryData.seeds) do
			local itemFrame = Instance.new("Frame")
			itemFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
			itemFrame.BorderSizePixel = 0
			itemFrame.Parent = contentFrame

			local itemCorner = Instance.new("UICorner")
			itemCorner.CornerRadius = UDim.new(0, 12)
			itemCorner.Parent = itemFrame

			-- Item icon
			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(1, 0, 0, 40)
			iconLabel.Position = UDim2.new(0, 0, 0, 10)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = seedData.icon
			iconLabel.TextScaled = true
			iconLabel.Parent = itemFrame

			-- Item name
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -10, 0, 25)
			nameLabel.Position = UDim2.new(0, 5, 0, 50)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = seedData.name
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.Parent = itemFrame

			-- Item count
			local countLabel = Instance.new("TextLabel")
			countLabel.Size = UDim2.new(1, -10, 0, 25)
			countLabel.Position = UDim2.new(0, 5, 0, 75)
			countLabel.BackgroundTransparency = 1
			countLabel.Text = "Count: " .. seedData.count
			countLabel.TextColor3 = Color3.fromRGB(149, 165, 166)
			countLabel.TextScaled = true
			countLabel.Font = Enum.Font.Gotham
			countLabel.Parent = itemFrame

			-- Glow effect if player has seeds
			if seedData.count > 0 then
				itemFrame.BackgroundColor3 = Color3.fromRGB(46, 204, 113)

				local glowEffect = Instance.new("UIStroke")
				glowEffect.Color = Color3.fromRGB(46, 204, 113)
				glowEffect.Thickness = 2
				glowEffect.Parent = itemFrame
			end
		end

		contentFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
	end

	-- Create crops tab
	local function createCropsTab()
		contentFrame:ClearAllChildren()

		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 10)
		listLayout.Parent = contentFrame

		for cropType, cropData in pairs(inventoryData.crops) do
			local itemFrame = Instance.new("Frame")
			itemFrame.Size = UDim2.new(1, -20, 0, 100)
			itemFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
			itemFrame.BorderSizePixel = 0
			itemFrame.Parent = contentFrame

			local itemCorner = Instance.new("UICorner")
			itemCorner.CornerRadius = UDim.new(0, 12)
			itemCorner.Parent = itemFrame

			-- Item icon
			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(0, 80, 1, 0)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = cropData.icon
			iconLabel.TextScaled = true
			iconLabel.Parent = itemFrame

			-- Item details
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0, 250, 0, 30)
			nameLabel.Position = UDim2.new(0, 90, 0, 10)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = cropData.name
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = itemFrame

			local countLabel = Instance.new("TextLabel")
			countLabel.Size = UDim2.new(0, 250, 0, 25)
			countLabel.Position = UDim2.new(0, 90, 0, 40)
			countLabel.BackgroundTransparency = 1
			countLabel.Text = "Count: " .. cropData.count
			countLabel.TextColor3 = Color3.fromRGB(149, 165, 166)
			countLabel.TextScaled = true
			countLabel.Font = Enum.Font.Gotham
			countLabel.TextXAlignment = Enum.TextXAlignment.Left
			countLabel.Parent = itemFrame

			local priceLabel = Instance.new("TextLabel")
			priceLabel.Size = UDim2.new(0, 250, 0, 25)
			priceLabel.Position = UDim2.new(0, 90, 0, 65)
			priceLabel.BackgroundTransparency = 1
			priceLabel.Text = "?? " .. cropData.sellPrice .. " coins each"
			priceLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
			priceLabel.TextScaled = true
			priceLabel.Font = Enum.Font.Gotham
			priceLabel.TextXAlignment = Enum.TextXAlignment.Left
			priceLabel.Parent = itemFrame

			-- Sell button (only if player has crops)
			if cropData.count > 0 then
				itemFrame.BackgroundColor3 = Color3.fromRGB(230, 126, 34)

				local sellButton = Instance.new("TextButton")
				sellButton.Size = UDim2.new(0, 120, 0, 40)
				sellButton.Position = UDim2.new(1, -130, 0.5, -20)
				sellButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
				sellButton.Text = "Sell All"
				sellButton.TextColor3 = Color3.new(1, 1, 1)
				sellButton.TextScaled = true
				sellButton.Font = Enum.Font.GothamBold
				sellButton.BorderSizePixel = 0
				sellButton.Parent = itemFrame

				local sellCorner = Instance.new("UICorner")
				sellCorner.CornerRadius = UDim.new(0, 8)
				sellCorner.Parent = sellButton

				sellButton.MouseButton1Click:Connect(function()
					print("[InventoryClient] Selling", cropData.count, cropType)
					if remoteEvents.SellPlantEvent then
						remoteEvents.SellPlantEvent:FireServer(cropType, cropData.count)
						-- Update local count
						cropData.count = 0
						createCropsTab() -- Refresh display
					end
				end)

				local glowEffect = Instance.new("UIStroke")
				glowEffect.Color = Color3.fromRGB(230, 126, 34)
				glowEffect.Thickness = 2
				glowEffect.Parent = itemFrame
			end
		end

		contentFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
	end

	-- Create pets tab
	local function createPetsTab()
		contentFrame:ClearAllChildren()

		local noItemsLabel = Instance.new("TextLabel")
		noItemsLabel.Size = UDim2.new(1, 0, 0, 100)
		noItemsLabel.Position = UDim2.new(0, 0, 0.4, 0)
		noItemsLabel.BackgroundTransparency = 1
		noItemsLabel.Text = "??\n\nNo pets yet!\nHatch some eggs to get pets."
		noItemsLabel.TextColor3 = Color3.fromRGB(149, 165, 166)
		noItemsLabel.TextScaled = true
		noItemsLabel.Font = Enum.Font.Gotham
		noItemsLabel.Parent = contentFrame

		contentFrame.CanvasSize = UDim2.new(0, 0, 0, 200)
	end

	-- Tab button events
	seedTabButton.MouseButton1Click:Connect(createSeedsTab)
	cropTabButton.MouseButton1Click:Connect(createCropsTab)
	petTabButton.MouseButton1Click:Connect(createPetsTab)

	-- Start with seeds tab
	createSeedsTab()

	-- Animation
	mainFrame.Position = UDim2.new(0.5, -450, 1, 0)
	local openTween = TweenService:Create(
		mainFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -450, 0.5, -350)}
	)
	openTween:Play()
end

-- Listen for inventory updates from server
spawn(function()
	local requestInventoryUpdateEvent = ReplicatedStorage:WaitForChild("RequestInventoryUpdate")
	requestInventoryUpdateEvent.OnClientEvent:Connect(function(data)
		print("[InventoryClient] Received inventory update:", data)
		if data and data.inventory then
			-- Update local inventory data
			if data.inventory.seeds then
				for seedType, count in pairs(data.inventory.seeds) do
					if inventoryData.seeds[seedType] then
						inventoryData.seeds[seedType].count = count
					end
				end
			end

			if data.inventory.crops then
				for cropType, count in pairs(data.inventory.crops) do
					if inventoryData.crops[cropType] then
						inventoryData.crops[cropType].count = count
					end
				end
			end

			-- Refresh UI if open
			if isInventoryOpen and inventoryGui then
				print("[InventoryClient] Refreshing inventory display")
				-- You would need to refresh the current tab here
			end
		end
	end)
end)

-- === PUBLIC FUNCTIONS ===
_G.InventoryClient = {
	ToggleInventory = function()
		if isInventoryOpen then
			-- Close inventory
			if inventoryGui then
				local mainFrame = inventoryGui:FindFirstChild("InventoryFrame")
				if mainFrame then
					local closeTween = TweenService:Create(
						mainFrame,
						TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
						{Position = UDim2.new(0.5, -450, 1, 0)}
					)
					closeTween:Play()
					closeTween.Completed:Connect(function()
						inventoryGui:Destroy()
						inventoryGui = nil
					end)
				end
			end
			isInventoryOpen = false
			print("[InventoryClient] Inventory closed")
		else
			-- Open inventory
			updateInventoryData() -- Refresh data from server
			createInventoryUI()
			isInventoryOpen = true
			print("[InventoryClient] Inventory opened")
		end
	end,

	-- Update inventory data
	UpdateInventory = function(newData)
		inventoryData = newData or inventoryData
		print("[InventoryClient] Inventory data updated")
	end,

	-- Get current inventory
	GetInventory = function()
		return inventoryData
	end
}

print("[InventoryClient] Inventory system initialized!")
