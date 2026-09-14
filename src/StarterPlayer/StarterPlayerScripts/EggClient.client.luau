--!strict

-- Presentation and input only. The server remains authoritative for every
-- gameplay outcome; this client renders the original Celestial Egg Rush theme.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("StealAnEggs")
local remotes = sharedFolder:WaitForChild("Remotes")
local requestDrop = remotes:WaitForChild("RequestDrop") :: RemoteEvent
local requestHatch = remotes:WaitForChild("RequestHatch") :: RemoteEvent
local feedback = remotes:WaitForChild("Feedback") :: RemoteEvent

local COLORS = {
	ink = Color3.fromRGB(13, 16, 43),
	panel = Color3.fromRGB(33, 28, 76),
	panelDark = Color3.fromRGB(23, 20, 57),
	cyan = Color3.fromRGB(94, 239, 255),
	pink = Color3.fromRGB(255, 112, 202),
	gold = Color3.fromRGB(255, 213, 112),
	text = Color3.fromRGB(244, 247, 255),
	muted = Color3.fromRGB(183, 196, 242),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CelestialEggRushUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local function addCorner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance: GuiObject, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0.12
	stroke.Parent = instance
end

local function addGradient(instance: GuiObject, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = instance
end

local function styleText(textObject: TextLabel | TextButton, textSize: number)
	textObject.Font = Enum.Font.GothamBold
	textObject.TextColor3 = COLORS.text
	textObject.TextSize = textSize
	textObject.TextXAlignment = Enum.TextXAlignment.Left
	textObject.TextStrokeColor3 = COLORS.ink
	textObject.TextStrokeTransparency = 0.45
	textObject.TextTruncate = Enum.TextTruncate.AtEnd
end

local function makePanel(name: string, position: UDim2, size: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = COLORS.panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	addCorner(panel, 12)
	addStroke(panel, COLORS.cyan, 1.5)
	addGradient(panel, COLORS.panel, COLORS.panelDark)
	return panel
end

local statusPanel = makePanel("StatusPanel", UDim2.fromOffset(16, 16), UDim2.fromOffset(260, 170))
local statusConstraint = Instance.new("UISizeConstraint")
statusConstraint.MinSize = Vector2.new(190, 0)
statusConstraint.MaxSize = Vector2.new(280, 170)
statusConstraint.Parent = statusPanel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(14, 10)
titleLabel.Size = UDim2.new(1, -28, 0, 28)
titleLabel.Text = "CELESTIAL EGG RUSH"
styleText(titleLabel, 18)
titleLabel.TextColor3 = COLORS.gold
titleLabel.Parent = statusPanel

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Position = UDim2.fromOffset(14, 37)
subtitleLabel.Size = UDim2.new(1, -28, 0, 18)
subtitleLabel.Text = "TRAIN • STEAL • HATCH"
styleText(subtitleLabel, 11)
subtitleLabel.TextColor3 = COLORS.muted
subtitleLabel.Parent = statusPanel

local function makeStat(name: string, y: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -28, 0, 24)
	styleText(label, 15)
	label.Parent = statusPanel
	return label
end

local scoreLabel = makeStat("ScoreLabel", 64)
local coinsLabel = makeStat("CoinsLabel", 91)
local speedLabel = makeStat("SpeedLabel", 118)
local carryLabel = makeStat("CarryLabel", 145)
carryLabel.TextColor3 = COLORS.pink

local inventoryPanel = makePanel("InventoryPanel", UDim2.fromOffset(16, 198), UDim2.fromOffset(220, 152))
local inventoryTitle = Instance.new("TextLabel")
inventoryTitle.Name = "Title"
inventoryTitle.BackgroundTransparency = 1
inventoryTitle.Position = UDim2.fromOffset(14, 8)
inventoryTitle.Size = UDim2.new(1, -28, 0, 22)
inventoryTitle.Text = "EGG VAULT"
styleText(inventoryTitle, 14)
inventoryTitle.TextColor3 = COLORS.cyan
inventoryTitle.Parent = inventoryPanel

local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.Name = "Feedback"
feedbackLabel.AnchorPoint = Vector2.new(0.5, 1)
feedbackLabel.Position = UDim2.new(0.5, 0, 1, -90)
feedbackLabel.Size = UDim2.new(0.7, 0, 0, 48)
feedbackLabel.BackgroundColor3 = COLORS.panelDark
feedbackLabel.BackgroundTransparency = 0.04
feedbackLabel.BorderSizePixel = 0
feedbackLabel.TextXAlignment = Enum.TextXAlignment.Center
feedbackLabel.TextYAlignment = Enum.TextYAlignment.Center
styleText(feedbackLabel, 16)
feedbackLabel.TextColor3 = COLORS.gold
feedbackLabel.Visible = false
feedbackLabel.Parent = screenGui
addCorner(feedbackLabel, 12)
addStroke(feedbackLabel, COLORS.gold, 1.5)

local eventLabel = Instance.new("TextLabel")
eventLabel.Name = "EventLabel"
eventLabel.AnchorPoint = Vector2.new(0.5, 0)
eventLabel.Position = UDim2.new(0.5, 0, 0, 18)
eventLabel.Size = UDim2.new(0.45, 0, 0, 34)
eventLabel.BackgroundColor3 = COLORS.pink
eventLabel.BackgroundTransparency = 0.12
eventLabel.BorderSizePixel = 0
eventLabel.TextXAlignment = Enum.TextXAlignment.Center
styleText(eventLabel, 15)
eventLabel.Visible = false
eventLabel.Parent = screenGui
addCorner(eventLabel, 10)
addStroke(eventLabel, COLORS.gold, 1.25)

local function makeActionButton(name: string, text: string, position: UDim2, size: UDim2, accent: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = COLORS.panel
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	styleText(button, 14)
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.Parent = screenGui
	addCorner(button, 10)
	addStroke(button, accent, 1.5)
	addGradient(button, COLORS.panel, Color3.fromRGB(53, 39, 103))
	return button
end

local dropButton =
	makeActionButton("DropButton", "DROP EGG  [Q]", UDim2.new(1, -176, 1, -76), UDim2.fromOffset(160, 52), COLORS.pink)

local leaderstats = player:WaitForChild("leaderstats")
local score = leaderstats:WaitForChild("Score") :: IntValue
local coins = leaderstats:WaitForChild("Coins") :: IntValue
local speed = leaderstats:WaitForChild("Speed") :: NumberValue

local function updateScore()
	scoreLabel.Text = "✦ SCORE  " .. score.Value
end
score:GetPropertyChangedSignal("Value"):Connect(updateScore)
updateScore()

local function updateCoins()
	coinsLabel.Text = "◈ COINS  " .. coins.Value
end
coins:GetPropertyChangedSignal("Value"):Connect(updateCoins)
updateCoins()

local function updateSpeed()
	speedLabel.Text =
		string.format("➤ SPEED  %.1f%s", speed.Value, player:GetAttribute("IsTraining") and "  TRAINING" or "")
end
speed:GetPropertyChangedSignal("Value"):Connect(updateSpeed)
player:GetAttributeChangedSignal("IsTraining"):Connect(updateSpeed)
updateSpeed()

local function updateEvent()
	local eventName = sharedFolder:GetAttribute("ActiveMutationEvent")
	eventLabel.Visible = typeof(eventName) == "string"
	eventLabel.Text = eventLabel.Visible and ("✦ " .. eventName .. " ✦") or ""
end
sharedFolder:GetAttributeChangedSignal("ActiveMutationEvent"):Connect(updateEvent)
updateEvent()

local function updateCarry()
	local eggId = player:GetAttribute("CarryingEggId")
	carryLabel.Text = eggId and "✹ CARRYING  " .. tostring(eggId) or "○ HANDS FREE"
	dropButton.Visible = eggId ~= nil
end
player:GetAttributeChangedSignal("CarryingEggId"):Connect(updateCarry)
updateCarry()

local function askToDrop()
	requestDrop:FireServer()
end
dropButton.Activated:Connect(askToDrop)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Q then
		askToDrop()
	end
end)

local eggInventory = player:WaitForChild("EggInventory")
local hatchY = 38
for _, rarityName in { "Common", "Rare", "Legendary" } do
	local count = eggInventory:WaitForChild(rarityName) :: IntValue
	local hatchButton = makeActionButton(
		"Hatch" .. rarityName,
		"HATCH " .. string.upper(rarityName),
		UDim2.fromOffset(28, 198 + hatchY),
		UDim2.fromOffset(196, 30),
		rarityName == "Legendary" and COLORS.gold or (rarityName == "Rare" and COLORS.cyan or COLORS.pink)
	)
	local function updateHatchButton()
		hatchButton.Text = "HATCH " .. string.upper(rarityName) .. "  ×" .. count.Value
		hatchButton.Visible = count.Value > 0
	end
	count:GetPropertyChangedSignal("Value"):Connect(updateHatchButton)
	hatchButton.Activated:Connect(function()
		requestHatch:FireServer(rarityName)
	end)
	updateHatchButton()
	hatchY += 36
end

local feedbackVersion = 0
feedback.OnClientEvent:Connect(function(message: unknown)
	if typeof(message) ~= "string" then
		return
	end
	feedbackVersion += 1
	local version = feedbackVersion
	feedbackLabel.Text, feedbackLabel.Visible = message, true
	task.delay(2, function()
		if feedbackVersion == version then
			feedbackLabel.Visible = false
		end
	end)
end)
