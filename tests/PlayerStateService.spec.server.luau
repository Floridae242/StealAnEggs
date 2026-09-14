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

local duplicateOk = pcall(function()
	PlayerStateService.createSessionContainers(host, { "Common" }, 16)
end)
assert(not duplicateOk, "Service must reject duplicate player session state")

host:Destroy()
print("PlayerStateServiceSpec passed")
