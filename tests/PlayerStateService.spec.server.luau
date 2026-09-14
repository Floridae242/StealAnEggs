--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerStateService = require(ServerScriptService.Services.PlayerStateService)

local host = Instance.new("Folder")
host.Name = "PlayerStateServiceSpec"
host.Parent = ServerScriptService

assert(not PlayerStateService.hasSessionContainers(host), "New session host must be uninitialized")
local containers = PlayerStateService.createSessionContainers(host, { "Common", "Rare", "Legendary" }, 16)

assert(PlayerStateService.hasSessionContainers(host), "Created session host must be recognized as initialized")
assert(containers.stats.Name == "leaderstats", "Service must create leaderstats")
assert(containers.score.Value == 0, "Score must begin at zero")
assert(containers.coins.Value == 0, "Coins must begin at zero")
assert(containers.speed.Value == 16, "Speed must begin at the requested value")
assert(containers.eggInventory:FindFirstChild("Common"), "Egg inventory must include every rarity")
assert(containers.eggInventory:FindFirstChild("Rare"), "Egg inventory must include every rarity")
assert(containers.eggInventory:FindFirstChild("Legendary"), "Egg inventory must include every rarity")
assert(containers.petInventory.Parent == host, "Pet inventory must be parented to the session host")
assert(PlayerStateService.getSessionContainers(host) ~= nil, "Complete session state must be discoverable")

PlayerStateService.applyPersistentState(containers, {
	score = 8,
	coins = 44,
	speed = 22,
	eggInventory = { Common = 2, Rare = 1, Legendary = 0 },
	creatures = { { id = "pet_001", species = "Chick", mutation = "Lumina" } },
})
assert(containers.score.Value == 8 and containers.coins.Value == 44, "Persistent currency must hydrate")
assert(containers.speed.Value == 22, "Persistent speed must hydrate")
local hydratedCommon = containers.eggInventory:FindFirstChild("Common")
assert(
	hydratedCommon and hydratedCommon:IsA("IntValue") and hydratedCommon.Value == 2,
	"Persistent egg inventory must hydrate"
)
local hydratedPet = containers.petInventory:FindFirstChild("pet_001")
assert(hydratedPet and hydratedPet:IsA("StringValue"), "Persistent creature must hydrate")
assert(hydratedPet.Value == "Chick" and hydratedPet:GetAttribute("Mutation") == "Lumina", "Creature state must hydrate")

local snapshot = PlayerStateService.snapshotPersistentState(containers, { "Common", "Rare", "Legendary" })
assert(snapshot.score == 8 and snapshot.coins == 44 and snapshot.speed == 22, "Persistent state must snapshot")
assert(snapshot.eggInventory.Rare == 1, "Egg inventory snapshot must retain every rarity")
assert(#snapshot.creatures == 1 and snapshot.creatures[1].id == "pet_001", "Creature snapshot must retain its ID")

local duplicateOk = pcall(function()
	PlayerStateService.createSessionContainers(host, { "Common" }, 16)
end)
assert(not duplicateOk, "Service must reject duplicate player session state")

host:Destroy()
print("PlayerStateServiceSpec passed")
