--!strict

-- Creates only replicated session containers. Persistent data ownership and
-- gameplay mutations stay with their respective server services.

export type SessionContainers = {
	stats: Folder,
	score: IntValue,
	coins: IntValue,
	speed: NumberValue,
	eggInventory: Folder,
	petInventory: Folder,
}

export type PersistentCreature = {
	id: string,
	species: string,
	mutation: string,
}

export type PersistentState = {
	score: number,
	coins: number,
	speed: number,
	eggInventory: { [string]: number },
	creatures: { PersistentCreature },
}

local PlayerStateService = {}

function PlayerStateService.hasSessionContainers(parent: Instance): boolean
	return parent:FindFirstChild("leaderstats") ~= nil
		or parent:FindFirstChild("EggInventory") ~= nil
		or parent:FindFirstChild("PetInventory") ~= nil
end

function PlayerStateService.getSessionContainers(parent: Instance): SessionContainers?
	local stats = parent:FindFirstChild("leaderstats")
	local eggInventory = parent:FindFirstChild("EggInventory")
	local petInventory = parent:FindFirstChild("PetInventory")
	if
		not stats
		or not stats:IsA("Folder")
		or not eggInventory
		or not eggInventory:IsA("Folder")
		or not petInventory
		or not petInventory:IsA("Folder")
	then
		return nil
	end
	local score = stats:FindFirstChild("Score")
	local coins = stats:FindFirstChild("Coins")
	local speed = stats:FindFirstChild("Speed")
	if
		not score
		or not score:IsA("IntValue")
		or not coins
		or not coins:IsA("IntValue")
		or not speed
		or not speed:IsA("NumberValue")
	then
		return nil
	end
	return {
		stats = stats,
		score = score,
		coins = coins,
		speed = speed,
		eggInventory = eggInventory,
		petInventory = petInventory,
	}
end

function PlayerStateService.createSessionContainers(
	parent: Instance,
	rarityNames: { string },
	baseWalkSpeed: number
): SessionContainers
	assert(not PlayerStateService.hasSessionContainers(parent), "Session state already exists")

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = parent

	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Parent = stats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats

	local speed = Instance.new("NumberValue")
	speed.Name = "Speed"
	speed.Value = baseWalkSpeed
	speed.Parent = stats

	local eggInventory = Instance.new("Folder")
	eggInventory.Name = "EggInventory"
	eggInventory.Parent = parent
	for _, rarityName in rarityNames do
		local count = Instance.new("IntValue")
		count.Name = rarityName
		count.Parent = eggInventory
	end

	local petInventory = Instance.new("Folder")
	petInventory.Name = "PetInventory"
	petInventory.Parent = parent

	return {
		stats = stats,
		score = score,
		coins = coins,
		speed = speed,
		eggInventory = eggInventory,
		petInventory = petInventory,
	}
end

function PlayerStateService.applyPersistentState(containers: SessionContainers, state: PersistentState)
	containers.score.Value = state.score
	containers.coins.Value = state.coins
	containers.speed.Value = state.speed

	for rarityName, count in state.eggInventory do
		local value = containers.eggInventory:FindFirstChild(rarityName)
		if value and value:IsA("IntValue") then
			value.Value = count
		end
	end

	containers.petInventory:ClearAllChildren()
	for _, creature in state.creatures do
		local pet = Instance.new("StringValue")
		pet.Name = creature.id
		pet.Value = creature.species
		pet:SetAttribute("Mutation", creature.mutation)
		pet.Parent = containers.petInventory
	end
end

function PlayerStateService.snapshotPersistentState(
	containers: SessionContainers,
	rarityNames: { string }
): PersistentState
	local eggInventory: { [string]: number } = {}
	for _, rarityName in rarityNames do
		local value = containers.eggInventory:FindFirstChild(rarityName)
		eggInventory[rarityName] = if value and value:IsA("IntValue") then value.Value else 0
	end

	local creatures: { PersistentCreature } = {}
	for _, pet in containers.petInventory:GetChildren() do
		if pet:IsA("StringValue") then
			local mutation = pet:GetAttribute("Mutation")
			table.insert(creatures, {
				id = pet.Name,
				species = pet.Value,
				mutation = if typeof(mutation) == "string" then mutation else "None",
			})
		end
	end
	table.sort(creatures, function(left, right)
		return left.id < right.id
	end)

	return {
		score = containers.score.Value,
		coins = containers.coins.Value,
		speed = containers.speed.Value,
		eggInventory = eggInventory,
		creatures = creatures,
	}
end

return PlayerStateService
