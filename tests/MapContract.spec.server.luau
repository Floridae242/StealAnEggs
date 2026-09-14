--!strict

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local gameMap = Workspace:FindFirstChild("GameMap")
assert(gameMap and gameMap:IsA("Model"), "Workspace.GameMap must be a Model")

local function requireFolder(name: string): Folder
	local instance = gameMap:FindFirstChild(name)
	assert(instance and instance:IsA("Folder"), ("GameMap.%s must be a Folder"):format(name))
	return instance
end

local function collectParts(folder: Folder): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function assertUniqueNames(instances: { Instance }, collectionName: string)
	local names: { [string]: boolean } = {}
	for _, instance in instances do
		assert(not names[instance.Name], ("Duplicate name in %s: %s"):format(collectionName, instance.Name))
		names[instance.Name] = true
	end
end

local spawnPoints = collectParts(requireFolder("EggSpawnPoints"))
local depositZones = collectParts(requireFolder("EggDepositZones"))
local treadmills = collectParts(requireFolder("Treadmills"))
local playerBases = requireFolder("PlayerBases")

assert(#spawnPoints == 6, "The MVP map must contain exactly 6 egg spawn points")
assert(#depositZones == 8, "The MVP map must contain exactly 8 deposit zones")
assert(#treadmills == 4, "The MVP map must contain exactly 4 treadmill zones")
assertUniqueNames(spawnPoints, "EggSpawnPoints")
assertUniqueNames(depositZones, "EggDepositZones")
assertUniqueNames(treadmills, "Treadmills")
assertUniqueNames(playerBases:GetChildren(), "PlayerBases")

local depositCounts: { [string]: number } = {}
for _, depositZone in depositZones do
	local baseId = depositZone:GetAttribute("BaseId")
	assert(typeof(baseId) == "string" and baseId ~= "", depositZone:GetFullName() .. " requires BaseId")
	depositCounts[baseId] = (depositCounts[baseId] or 0) + 1
	assert(depositZone.Anchored, depositZone:GetFullName() .. " must be anchored")
	assert(CollectionService:HasTag(depositZone, "EggDepositZone"), depositZone:GetFullName() .. " is missing its tag")
end

local baseIds: { [string]: boolean } = {}
local baseCount = 0
for _, base in playerBases:GetChildren() do
	assert(base:IsA("Model"), "Every PlayerBases child must be a Model")
	local baseId = base:GetAttribute("BaseId")
	assert(typeof(baseId) == "string" and baseId ~= "", "Every base requires a string BaseId")
	assert(not baseIds[baseId], ("Duplicate BaseId: %s"):format(baseId))
	assert(depositCounts[baseId] == 1, ("Base %s requires exactly one deposit zone"):format(baseId))

	local spawn: SpawnLocation? = nil
	local hatchZone: BasePart? = nil
	local spawnCount = 0
	local hatchCount = 0
	for _, child in base:GetChildren() do
		if child.Name == "Spawn" then
			assert(child:IsA("SpawnLocation"), ("Base %s Spawn must be a SpawnLocation"):format(baseId))
			spawn = child
			spawnCount += 1
		elseif child.Name == "HatchZone" then
			assert(child:IsA("BasePart"), ("Base %s HatchZone must be a BasePart"):format(baseId))
			hatchZone = child
			hatchCount += 1
		end
	end
	assert(spawnCount == 1 and spawn, ("Base %s requires exactly one SpawnLocation named Spawn"):format(baseId))
	assert(hatchCount == 1 and hatchZone, ("Base %s requires exactly one HatchZone"):format(baseId))
	assert(spawn.Anchored, spawn:GetFullName() .. " must be anchored")

	assert(hatchZone.Anchored, hatchZone:GetFullName() .. " must be anchored")
	assert(hatchZone:GetAttribute("BaseId") == baseId, hatchZone:GetFullName() .. " has the wrong BaseId")
	assert(CollectionService:HasTag(hatchZone, "EggHatchZone"), hatchZone:GetFullName() .. " is missing its tag")

	baseIds[baseId] = true
	baseCount += 1
end
assert(baseCount == 8, "The MVP map must contain exactly 8 player bases")

for baseId, count in depositCounts do
	assert(baseIds[baseId], ("Deposit zone references unknown BaseId: %s"):format(baseId))
	assert(count == 1, ("Base %s has duplicate deposit zones"):format(baseId))
end

for _, spawnPoint in spawnPoints do
	assert(spawnPoint.Anchored, spawnPoint:GetFullName() .. " must be anchored")
	assert(CollectionService:HasTag(spawnPoint, "EggSpawnPoint"), spawnPoint:GetFullName() .. " is missing its tag")
end

for _, treadmill in treadmills do
	assert(treadmill.Anchored, treadmill:GetFullName() .. " must be anchored")
	assert(CollectionService:HasTag(treadmill, "TreadmillZone"), treadmill:GetFullName() .. " is missing its tag")
end

for _, geometryName in { "Floor", "CentralArena" } do
	local geometry = gameMap:FindFirstChild(geometryName)
	assert(geometry and geometry:IsA("BasePart"), ("GameMap.%s must be a BasePart"):format(geometryName))
	assert(geometry.Anchored, geometry:GetFullName() .. " must be anchored")
end

print("MapContractSpec passed")
