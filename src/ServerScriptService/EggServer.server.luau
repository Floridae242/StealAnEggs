--!strict

-- Server-authoritative gameplay: clients can request only a drop. This script
-- determines every egg, carrier, score, cooldown, and drop position itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

local sharedFolder = ReplicatedStorage:WaitForChild("StealAnEggs")
local Config = require(sharedFolder:WaitForChild("Config"))
local EggCatalog = require(sharedFolder:WaitForChild("EggCatalog"))
local CreatureCatalog = require(sharedFolder:WaitForChild("CreatureCatalog"))
local RemoteRegistry = require(script.Parent:WaitForChild("Services"):WaitForChild("RemoteRegistry"))
local PlayerStateService = require(script.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

local gameMap = Workspace:WaitForChild("GameMap")
local spawnFolder = gameMap:WaitForChild("EggSpawnPoints")
local depositFolder = gameMap:WaitForChild("EggDepositZones")
local treadmillFolder = gameMap:FindFirstChild("Treadmills")

local eggsFolder = Workspace:FindFirstChild("Eggs") or Instance.new("Folder")
eggsFolder.Name = "Eggs"
eggsFolder.Parent = Workspace

local remotesFolder = sharedFolder:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = sharedFolder

local requestDrop = RemoteRegistry.getOrCreate(remotesFolder, "RequestDrop")
local requestHatch = RemoteRegistry.getOrCreate(remotesFolder, "RequestHatch")
local feedback = RemoteRegistry.getOrCreate(remotesFolder, "Feedback")
local scoreStore = if Config.SAVE_LIFETIME_SCORE then DataStoreService:GetDataStore(Config.DATASTORE_NAME) else nil

type EggState = {
	spawnPoint: BasePart,
	carrier: Player?,
	weld: WeldConstraint?,
	prompt: ProximityPrompt,
	lastTransferAt: number,
	rarity: string,
}

type PlayerData = { loaded: boolean, unsavedScore: number }
type CarryTravel = {
	pickupAt: number,
	pickupPosition: Vector3,
	lastSampleAt: number,
	lastPosition: Vector3,
	isSuspicious: boolean,
}
type TrainingState = {
	lastPosition: Vector3,
	lastObservedAt: number,
	enteredAt: number?,
	isSuspicious: boolean,
}

local eggStates: { [BasePart]: EggState } = {}
local carriedEgg: { [Player]: BasePart } = {}
local playerData: { [Player]: PlayerData } = {}
local carryTravel: { [Player]: CarryTravel } = {}
local lastActionAt: { [Player]: number } = {}
local lastDropAt: { [Player]: number } = {}
local lastDepositAt: { [Player]: number } = {}
local lastHatchAt: { [Player]: number } = {}
local trainingCoinRemainder: { [Player]: number } = {}
local passiveCoinRemainder: { [Player]: number } = {}
local trainingState: { [Player]: TrainingState } = {}
local isSaving: { [Player]: boolean } = {}
local eggRandom = Random.new()
local eggSerial = 0

local function notify(player: Player, message: string)
	feedback:FireClient(player, message)
end

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function clearCarrier(egg: BasePart)
	local state = eggStates[egg]
	if not state then
		return
	end
	if state.carrier then
		carriedEgg[state.carrier] = nil
		carryTravel[state.carrier] = nil
		state.carrier:SetAttribute("CarryingEggId", nil)
	end
	state.carrier = nil
	if state.weld then
		state.weld:Destroy()
		state.weld = nil
	end
end

local function resetEgg(egg: BasePart)
	local state = eggStates[egg]
	if not state or not state.spawnPoint.Parent then
		return
	end
	clearCarrier(egg)
	egg.Anchored, egg.CanCollide, egg.CanTouch, egg.Massless = true, true, true, false
	egg.CFrame = state.spawnPoint.CFrame + Vector3.new(0, state.spawnPoint.Size.Y / 2 + egg.Size.Y / 2, 0)
	state.prompt.ActionText, state.prompt.ObjectText, state.prompt.Enabled = "Pick up", "Egg", true
	state.lastTransferAt = 0
end

local function attachEgg(egg: BasePart, player: Player): boolean
	local state = eggStates[egg]
	local root = getAliveRoot(player)
	if not state or not root then
		return false
	end
	clearCarrier(egg)
	egg.Anchored, egg.CanCollide, egg.CanTouch, egg.Massless = false, false, false, true
	egg.CFrame = root.CFrame * Config.CARRY_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Name, weld.Part0, weld.Part1, weld.Parent = "CarryWeld", root, egg, egg
	state.weld, state.carrier, state.lastTransferAt = weld, player, os.clock()
	carriedEgg[player] = egg
	carryTravel[player] = {
		pickupAt = state.lastTransferAt,
		pickupPosition = root.Position,
		lastSampleAt = state.lastTransferAt,
		lastPosition = root.Position,
		isSuspicious = false,
	}
	player:SetAttribute("CarryingEggId", egg:GetAttribute("EggId"))
	state.prompt.ActionText, state.prompt.ObjectText = "Steal", "Egg carried by " .. player.DisplayName
	return true
end

local function tryTakeEgg(player: Player, egg: BasePart)
	local state = eggStates[egg]
	if not state or carriedEgg[player] then
		return
	end
	local now = os.clock()
	if now - (lastActionAt[player] or 0) < Config.ACTION_COOLDOWN then
		return
	end
	lastActionAt[player] = now
	local root = getAliveRoot(player)
	if not root or state.carrier == player then
		return
	end
	local maxDistance = state.carrier and Config.STEAL_DISTANCE or Config.PICKUP_DISTANCE
	if (root.Position - egg.Position).Magnitude > maxDistance then
		notify(player, "You are too far from the egg.")
		return
	end
	if state.carrier and now - state.lastTransferAt < Config.STEAL_COOLDOWN then
		return
	end
	local previousCarrier = state.carrier
	if attachEgg(egg, player) then
		if previousCarrier then
			notify(previousCarrier, player.DisplayName .. " stole your egg!")
		end
		notify(player, previousCarrier and "Egg stolen!" or "Egg picked up!")
	end
end

local function spawnEgg(spawnPoint: BasePart)
	eggSerial += 1
	local rarityName = EggCatalog.roll(eggRandom)
	local rarity = EggCatalog.getRarity(rarityName)
	if not rarity then
		error("Egg catalog returned an unknown rarity")
	end
	local egg = Instance.new("Part")
	egg.Name, egg.Shape, egg.Size = "Egg_" .. spawnPoint.Name, Enum.PartType.Ball, Vector3.new(2, 2.6, 2)
	egg.Color = rarity.color
	egg.Material = Enum.Material.SmoothPlastic
	egg:SetAttribute("EggId", spawnPoint.Name .. "_" .. eggSerial)
	egg:SetAttribute("Rarity", rarityName)
	egg.Parent = eggsFolder
	CollectionService:AddTag(egg, "StealableEgg")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "EggPrompt", "Pick up", rarityName .. " Egg"
	prompt.MaxActivationDistance = math.max(Config.PICKUP_DISTANCE, Config.STEAL_DISTANCE)
	prompt.HoldDuration, prompt.RequiresLineOfSight, prompt.Parent = Config.PROMPT_HOLD_DURATION, true, egg
	eggStates[egg] =
		{ spawnPoint = spawnPoint, carrier = nil, weld = nil, prompt = prompt, lastTransferAt = 0, rarity = rarityName }
	resetEgg(egg)
	prompt.Triggered:Connect(function(player)
		tryTakeEgg(player, egg)
	end)
end

local function dropEgg(player: Player)
	local now = os.clock()
	if now - (lastDropAt[player] or 0) < Config.DROP_COOLDOWN then
		return
	end
	lastDropAt[player] = now
	local egg = carriedEgg[player]
	local root = getAliveRoot(player)
	if not egg or not root or eggStates[egg].carrier ~= player then
		return
	end
	local desired = root.Position + root.CFrame.LookVector * 4
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	params.FilterDescendantsInstances = if character then { character, egg } else { egg }
	local hit = Workspace:Raycast(desired + Vector3.new(0, 5, 0), Vector3.new(0, -15, 0), params)
	clearCarrier(egg)
	egg.Anchored, egg.CanCollide, egg.CanTouch, egg.Massless = true, true, true, false
	egg.CFrame = CFrame.new((hit and hit.Position or desired) + Vector3.new(0, egg.Size.Y / 2, 0))
	eggStates[egg].prompt.ActionText, eggStates[egg].prompt.ObjectText = "Pick up", "Dropped Egg"
	notify(player, "Egg dropped.")
end

requestDrop.OnServerEvent:Connect(function(player: Player)
	-- Deliberately accept no client-controlled egg, score, or position arguments.
	dropEgg(player)
end)

local function isInsideZone(player: Player, zone: BasePart): boolean
	local root = getAliveRoot(player)
	if not root then
		return false
	end
	local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
	local halfSize, tolerance = zone.Size / 2, Vector3.new(3, 5, 3)
	return math.abs(localPosition.X) <= halfSize.X + tolerance.X
		and math.abs(localPosition.Y) <= halfSize.Y + tolerance.Y
		and math.abs(localPosition.Z) <= halfSize.Z + tolerance.Z
end

local function getIntValue(parent: Instance, name: string): IntValue?
	local value = parent:FindFirstChild(name)
	return if value and value:IsA("IntValue") then value else nil
end

local function addEggToInventory(player: Player, rarityName: string): boolean
	local inventory = player:FindFirstChild("EggInventory")
	if not inventory then
		return false
	end
	local count = getIntValue(inventory, rarityName)
	if not count then
		return false
	end
	count.Value += 1
	return true
end

local function awardEgg(player: Player, egg: BasePart)
	local state = eggStates[egg]
	if not state or state.carrier ~= player or carriedEgg[player] ~= egg then
		return
	end
	local travel = carryTravel[player]
	local root = getAliveRoot(player)
	if not travel or not root then
		return
	end
	local elapsed = os.clock() - travel.pickupAt
	local maximumDistance = elapsed * Config.MAX_CARRY_SPEED + Config.TELEPORT_DISTANCE_BUFFER
	if
		travel.isSuspicious
		or elapsed < Config.MINIMUM_CARRY_TIME
		or (root.Position - travel.pickupPosition).Magnitude > maximumDistance
	then
		notify(player, "Deposit rejected: impossible carry movement.")
		resetEgg(egg)
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local score = leaderstats and leaderstats:FindFirstChild("Score")
	local coins = leaderstats and getIntValue(leaderstats, "Coins")
	if not score or not score:IsA("IntValue") then
		return
	end
	local rarity = EggCatalog.getRarity(state.rarity)
	if not rarity or not coins or not addEggToInventory(player, state.rarity) then
		return
	end
	score.Value += Config.SCORE_PER_EGG
	coins.Value += rarity.depositCoins
	if playerData[player] then
		playerData[player].unsavedScore += Config.SCORE_PER_EGG
	end
	local spawnPoint = state.spawnPoint
	clearCarrier(egg)
	eggStates[egg] = nil
	egg:Destroy()
	notify(player, state.rarity .. " egg secured! +" .. rarity.depositCoins .. " coins. Hatch it from your inventory.")
	task.delay(Config.RESPAWN_TIME, function()
		if spawnPoint.Parent then
			spawnEgg(spawnPoint)
		end
	end)
end

local function hatchEgg(player: Player, requestedRarity: unknown)
	if typeof(requestedRarity) ~= "string" then
		return
	end
	local rarity = EggCatalog.getRarity(requestedRarity)
	if not rarity then
		return
	end
	local now = os.clock()
	if now - (lastHatchAt[player] or 0) < Config.HATCH_COOLDOWN then
		return
	end
	lastHatchAt[player] = now
	if not getAliveRoot(player) then
		return
	end
	local inventory = player:FindFirstChild("EggInventory")
	local pets = player:FindFirstChild("PetInventory")
	local eggs = inventory and getIntValue(inventory, requestedRarity)
	if not eggs or not pets or eggs.Value <= 0 then
		notify(player, "You do not have a " .. requestedRarity .. " egg to hatch.")
		return
	end
	local petName = EggCatalog.choosePet(requestedRarity, eggRandom)
	if not petName or not CreatureCatalog.get(petName) then
		return
	end
	-- Consume first, then record the server-selected outcome.
	eggs.Value -= 1
	local pet = Instance.new("StringValue")
	pet.Name = "Pet_" .. string.format("%.0f", os.clock() * 1000) .. "_" .. tostring(#pets:GetChildren() + 1)
	pet.Value = petName
	pet:SetAttribute("Rarity", requestedRarity)
	pet:SetAttribute("Mutation", "None")
	pet.Parent = pets
	notify(player, "Hatched " .. petName .. " from a " .. requestedRarity .. " egg!")
end

local function payPassiveIncome()
	for _, player in Players:GetPlayers() do
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and getIntValue(leaderstats, "Coins")
		local pets = player:FindFirstChild("PetInventory")
		if coins and pets then
			local incomePerSecond = 0
			for _, pet in pets:GetChildren() do
				if pet:IsA("StringValue") then
					local creature = CreatureCatalog.get(pet.Value)
					local mutationAttribute = pet:GetAttribute("Mutation")
					local mutationName = if typeof(mutationAttribute) == "string" then mutationAttribute else nil
					if creature then
						incomePerSecond += creature.passiveCoinsPerSecond * CreatureCatalog.getMutationMultiplier(
							mutationName
						)
					end
				end
			end
			passiveCoinRemainder[player] = (passiveCoinRemainder[player] or 0)
				+ incomePerSecond * Config.PASSIVE_INCOME_TICK_SECONDS
			local earned = math.floor(passiveCoinRemainder[player])
			if earned > 0 then
				coins.Value += earned
				passiveCoinRemainder[player] -= earned
			end
		end
	end
end

local function runMutationEvent()
	sharedFolder:SetAttribute("ActiveMutationEvent", "Lumina Surge")
	for _, player in Players:GetPlayers() do
		local pets = player:FindFirstChild("PetInventory")
		if pets then
			local changed = 0
			for _, pet in pets:GetChildren() do
				if
					pet:IsA("StringValue")
					and pet:GetAttribute("Mutation") == "None"
					and eggRandom:NextNumber() <= Config.MUTATION_EVENT_CHANCE
				then
					pet:SetAttribute("Mutation", "Lumina")
					changed += 1
				end
			end
			if changed > 0 then
				notify(player, "Lumina Surge mutated " .. changed .. " creature(s)!")
			end
		end
	end
	task.wait(Config.MUTATION_EVENT_DURATION_SECONDS)
	sharedFolder:SetAttribute("ActiveMutationEvent", nil)
end

requestHatch.OnServerEvent:Connect(function(player: Player, requestedRarity: unknown)
	-- A rarity is UI intent only; egg ownership and the random pet are server-owned.
	hatchEgg(player, requestedRarity)
end)

local function trainPlayers()
	if not treadmillFolder then
		return
	end
	local zones = {}
	for _, descendant in treadmillFolder:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(zones, descendant)
		end
	end
	if #zones == 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		local root = getAliveRoot(player)
		local leaderstats = player:FindFirstChild("leaderstats")
		local speed = leaderstats and leaderstats:FindFirstChild("Speed")
		local coins = leaderstats and getIntValue(leaderstats, "Coins")
		if root and speed and speed:IsA("NumberValue") and coins then
			local now = os.clock()
			local state = trainingState[player]
			if not state then
				state = { lastPosition = root.Position, lastObservedAt = now, enteredAt = nil, isSuspicious = false }
				trainingState[player] = state
			else
				local elapsed = now - state.lastObservedAt
				if
					elapsed > 0
					and (root.Position - state.lastPosition).Magnitude / elapsed > Config.MAX_TRAINING_TRAVEL_SPEED
				then
					state.isSuspicious = true
				end
				state.lastPosition, state.lastObservedAt = root.Position, now
			end
			local training = false
			for _, zone in zones do
				local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
				local halfSize = zone.Size / 2
				if
					math.abs(localPosition.X) <= halfSize.X
					and math.abs(localPosition.Y) <= halfSize.Y + 4
					and math.abs(localPosition.Z) <= halfSize.Z
				then
					training = true
					break
				end
			end
			player:SetAttribute("IsTraining", training)
			if training and not state.enteredAt then
				state.enteredAt = now
			end
			if not training then
				state.enteredAt, state.isSuspicious = nil, false
			elseif
				state.enteredAt
				and not state.isSuspicious
				and now - state.enteredAt >= Config.MINIMUM_TRAINING_DWELL
			then
				speed.Value = math.min(
					Config.MAX_WALK_SPEED,
					speed.Value + Config.TRAINING_SPEED_PER_SECOND * Config.TRAINING_TICK_SECONDS
				)
				trainingCoinRemainder[player] = (trainingCoinRemainder[player] or 0)
					+ speed.Value * Config.TRAINING_COINS_PER_SPEED * Config.TRAINING_TICK_SECONDS
				local earnedCoins = math.floor(trainingCoinRemainder[player])
				if earnedCoins > 0 then
					coins.Value += earnedCoins
					trainingCoinRemainder[player] -= earnedCoins
				end
			end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = math.clamp(speed.Value, Config.BASE_WALK_SPEED, Config.MAX_WALK_SPEED)
			end
		end
	end
end

local function monitorCarriedEggMovement()
	local now = os.clock()
	for player, egg in pairs(carriedEgg) do
		local travel = carryTravel[player]
		local root = getAliveRoot(player)
		if not travel or not root or not eggStates[egg] then
			if egg and eggStates[egg] then
				resetEgg(egg)
			end
			continue
		end
		local elapsed = now - travel.lastSampleAt
		if elapsed > 0 then
			local speed = (root.Position - travel.lastPosition).Magnitude / elapsed
			if speed > Config.MAX_CARRY_SPEED then
				travel.isSuspicious = true
			end
			travel.lastPosition, travel.lastSampleAt = root.Position, now
		end
	end
end

local function connectDepositZone(zone: BasePart)
	zone.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastDepositAt[player] or 0) < 0.5 then
			return
		end
		lastDepositAt[player] = now
		local egg = carriedEgg[player]
		if egg and isInsideZone(player, zone) then
			awardEgg(player, egg)
		end
	end)
end

local function savePlayer(player: Player)
	local store = scoreStore
	if not Config.SAVE_LIFETIME_SCORE or not store then
		return
	end
	if isSaving[player] then
		return
	end
	local data = playerData[player]
	if not data or not data.loaded or data.unsavedScore <= 0 then
		return
	end
	isSaving[player] = true
	local delta = data.unsavedScore
	local ok, err = pcall(function()
		store:UpdateAsync("Player_" .. player.UserId, function(oldValue)
			return (tonumber(oldValue) or 0) + delta
		end)
	end)
	if ok then
		data.unsavedScore -= delta
	else
		warn("Could not save score for", player.Name, err)
	end
	isSaving[player] = nil
end

local function setupPlayer(player: Player)
	if playerData[player] or PlayerStateService.hasSessionContainers(player) then
		return
	end
	player:SetAttribute("CarryingEggId", nil)
	player:SetAttribute("IsTraining", false)
	local containers =
		PlayerStateService.createSessionContainers(player, EggCatalog.getRarityNames(), Config.BASE_WALK_SPEED)
	local stats = containers.stats
	local score = containers.score
	playerData[player] = { loaded = not Config.SAVE_LIFETIME_SCORE, unsavedScore = 0 }
	if Config.SAVE_LIFETIME_SCORE then
		local store = assert(scoreStore, "Score DataStore must exist when persistence is enabled")
		local ok, saved = pcall(function()
			return store:GetAsync("Player_" .. player.UserId)
		end)
		if ok then
			score.Value = typeof(saved) == "number" and saved or 0
			playerData[player].loaded = true
		else
			warn("Could not load", player.Name, saved)
		end
	end
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			local currentSpeed = stats:FindFirstChild("Speed")
			if currentSpeed and currentSpeed:IsA("NumberValue") then
				humanoid.WalkSpeed = math.clamp(currentSpeed.Value, Config.BASE_WALK_SPEED, Config.MAX_WALK_SPEED)
			end
			humanoid.Died:Connect(function()
				local egg = carriedEgg[player]
				if egg then
					resetEgg(egg)
				end
			end)
		end
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

for _, zone in depositFolder:GetDescendants() do
	if zone:IsA("BasePart") then
		CollectionService:AddTag(zone, "EggDepositZone")
		connectDepositZone(zone)
	end
end
local spawnPoints = {}
for _, point in spawnFolder:GetDescendants() do
	if point:IsA("BasePart") then
		CollectionService:AddTag(point, "EggSpawnPoint")
		table.insert(spawnPoints, point)
	end
end
table.sort(spawnPoints, function(a, b)
	return a.Name < b.Name
end)
for index = 1, math.min(Config.MAX_EGGS, #spawnPoints) do
	spawnEgg(spawnPoints[index])
end
Players.PlayerAdded:Connect(setupPlayer)
game:GetService("RunService").Heartbeat:Connect(monitorCarriedEggMovement)
for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end
task.spawn(function()
	while true do
		task.wait(Config.TRAINING_TICK_SECONDS)
		trainPlayers()
	end
end)
task.spawn(function()
	while true do
		task.wait(Config.PASSIVE_INCOME_TICK_SECONDS)
		payPassiveIncome()
	end
end)
task.spawn(function()
	while true do
		task.wait(Config.MUTATION_EVENT_INTERVAL_SECONDS)
		runMutationEvent()
	end
end)
if Config.SAVE_LIFETIME_SCORE then
	task.spawn(function()
		while true do
			task.wait(Config.PERIODIC_SAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				savePlayer(player)
			end
		end
	end)
end
Players.PlayerRemoving:Connect(function(player)
	local egg = carriedEgg[player]
	if egg then
		resetEgg(egg)
	end
	savePlayer(player)
	playerData[player], carriedEgg[player], carryTravel[player], lastActionAt[player], lastDropAt[player], lastDepositAt[player], lastHatchAt[player], trainingCoinRemainder[player], passiveCoinRemainder[player], trainingState[player], isSaving[player] =
		nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
end)
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayer(player)
	end
end)
