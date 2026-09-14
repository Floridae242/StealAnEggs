--!strict

-- This geometry contract protects the prototype's risk/reward loop. It does
-- not replace the manual multiplayer path test around cover and obstacles.

local Workspace = game:GetService("Workspace")

local gameMap = Workspace:WaitForChild("GameMap")
local playerBases = gameMap:WaitForChild("PlayerBases")
local spawnPoints = gameMap:WaitForChild("EggSpawnPoints")
local centralArena = gameMap:WaitForChild("CentralArena")
assert(centralArena:IsA("BasePart"), "Travel contract requires CentralArena to be a BasePart")

local BASE_WALK_SPEED = 16
local MINIMUM_BASE_TO_EGG_SECONDS = 6
local MAXIMUM_BASE_TO_EGG_SECONDS = 18
local MINIMUM_BASE_TO_CENTER_SECONDS = 10
local MAXIMUM_BASE_TO_CENTER_SECONDS = 17
local MINIMUM_NEIGHBOR_BASE_SECONDS = 6
local MAXIMUM_NEIGHBOR_BASE_SECONDS = 9

local eggPoints: { BasePart } = {}
for _, descendant in spawnPoints:GetDescendants() do
	if descendant:IsA("BasePart") then
		table.insert(eggPoints, descendant)
	end
end

assert(#eggPoints > 0, "Travel contract requires egg spawn points")
assert(#playerBases:GetChildren() == 8, "Travel contract requires exactly 8 player bases")

local baseSpawns: { SpawnLocation } = {}
for _, base in playerBases:GetChildren() do
	assert(base:IsA("Model"), "Every player base must be a Model")
	local spawn = base:FindFirstChild("Spawn")
	assert(spawn and spawn:IsA("SpawnLocation"), base.Name .. " requires a SpawnLocation")
	table.insert(baseSpawns, spawn)
end

for _, spawn in baseSpawns do
	local closestDistance = math.huge
	for _, eggPoint in eggPoints do
		closestDistance = math.min(closestDistance, (spawn.Position - eggPoint.Position).Magnitude)
	end

	local baseName = spawn.Parent and spawn.Parent.Name or spawn.Name
	local eggTravelSeconds = closestDistance / BASE_WALK_SPEED
	assert(
		eggTravelSeconds >= MINIMUM_BASE_TO_EGG_SECONDS and eggTravelSeconds <= MAXIMUM_BASE_TO_EGG_SECONDS,
		("%s estimated base-to-egg travel %.1fs is outside the MVP target"):format(baseName, eggTravelSeconds)
	)

	local centerTravelSeconds = (spawn.Position - centralArena.Position).Magnitude / BASE_WALK_SPEED
	assert(
		centerTravelSeconds >= MINIMUM_BASE_TO_CENTER_SECONDS and centerTravelSeconds <= MAXIMUM_BASE_TO_CENTER_SECONDS,
		("%s estimated base-to-center travel %.1fs is outside the MVP target"):format(baseName, centerTravelSeconds)
	)

	local closestNeighborDistance = math.huge
	for _, otherSpawn in baseSpawns do
		if otherSpawn ~= spawn then
			closestNeighborDistance =
				math.min(closestNeighborDistance, (spawn.Position - otherSpawn.Position).Magnitude)
		end
	end
	local neighborTravelSeconds = closestNeighborDistance / BASE_WALK_SPEED
	assert(
		neighborTravelSeconds >= MINIMUM_NEIGHBOR_BASE_SECONDS
			and neighborTravelSeconds <= MAXIMUM_NEIGHBOR_BASE_SECONDS,
		("%s estimated nearest base-to-base travel %.1fs is outside the MVP target"):format(
			baseName,
			neighborTravelSeconds
		)
	)
end

print("MapTravelTimeSpec passed")
