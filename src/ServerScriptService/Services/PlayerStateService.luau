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

local PlayerStateService = {}

function PlayerStateService.hasSessionContainers(parent: Instance): boolean
	return parent:FindFirstChild("leaderstats") ~= nil
		or parent:FindFirstChild("EggInventory") ~= nil
		or parent:FindFirstChild("PetInventory") ~= nil
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

return PlayerStateService
