-- ServerScriptService/Initializer (Script)
-- Fixed initialization sequence with proper module loading

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for essential modules to load
local GameManager = require(script.Parent:WaitForChild("GameManager"))
local MagicalRealm = require(script.Parent:WaitForChild("MagicalRealm"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local RemoteEventHandler = require(script.Parent:WaitForChild("RemoteEventHandler"))

print("[Initializer] Starting game initialization...")

-- Step 1: Generate the magical world environment first
MagicalRealm.CreateWorld()
print("[Initializer] Magical world created")

-- Step 2: Initialize data management systems
print("[Initializer] Data systems initialized")

-- Step 3: Setup remote events for client-server communication
print("[Initializer] Remote events initialized")

-- Step 4: GameManager will handle player joining/leaving automatically via its connections
print("[Initializer] GameManager loaded and player events connected")

-- Create initialization complete event for other systems
local initCompleteEvent = Instance.new("BindableEvent")
initCompleteEvent.Name = "InitializationComplete"
initCompleteEvent.Parent = ReplicatedStorage

-- Fire the event to signal other systems
initCompleteEvent:Fire()

print("[Initializer] Game initialization complete! Players can now join.")