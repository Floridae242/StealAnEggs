--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(ServerScriptService.Services.DataService)

local options = {
	baseWalkSpeed = 16,
	maxWalkSpeed = 40,
	rarityNames = { "Common", "Rare", "Legendary" },
	isKnownCreature = function(name: string): boolean
		return name == "Chick" or name == "Bunny"
	end,
	isKnownMutation = function(name: string): boolean
		return name == "None" or name == "Lumina"
	end,
}

local default = DataService.createDefault(options)
assert(default.schemaVersion == 1, "Default profile must use schema v1")
assert(default.score == 0 and default.coins == 0, "Default profile must start with zero currency")
assert(default.speed == 16, "Default profile must use the configured base walk speed")
assert(default.eggInventory.Common == 0, "Default inventory must include every configured rarity")

local migrated, migrationError = DataService.loadAndValidate({ schemaVersion = 0, score = 12 }, options)
assert(migrated and not migrationError, "Legacy score data must migrate")
assert(migrated.score == 12 and migrated.coins == 0, "Migration must retain legacy score only")

local numericLegacy, numericLegacyError = DataService.loadAndValidate(18, options)
assert(numericLegacy and not numericLegacyError, "Legacy numeric score data must migrate")
assert(numericLegacy.score == 18, "Numeric migration must retain the prior score")

local invalidLegacy, invalidLegacyError = DataService.loadAndValidate(-1, options)
assert(invalidLegacy == nil and invalidLegacyError, "Invalid numeric legacy score data must be rejected")

local valid, validError = DataService.loadAndValidate({
	schemaVersion = 1,
	revision = 3,
	score = 15,
	coins = 80,
	speed = 20,
	eggInventory = { Common = 2, Rare = 1, Legendary = 0 },
	creatures = { { id = "pet_001", species = "Chick", mutation = "None" } },
	upgrades = { treadmill = 1, storage = 2 },
}, options)
assert(valid and not validError, "Well-formed v1 data must be accepted")
assert(valid.creatures[1].species == "Chick", "Valid creature data must be retained")

local invalidCreature, invalidCreatureError = DataService.loadAndValidate({
	schemaVersion = 1,
	revision = 0,
	score = 0,
	coins = 0,
	speed = 16,
	eggInventory = { Common = 0, Rare = 0, Legendary = 0 },
	creatures = { { id = "pet_001", species = "Unknown", mutation = "None" } },
	upgrades = { treadmill = 0, storage = 0 },
}, options)
assert(invalidCreature == nil and invalidCreatureError, "Unknown creature species must be rejected")

local duplicateId, duplicateIdError = DataService.loadAndValidate({
	schemaVersion = 1,
	revision = 0,
	score = 0,
	coins = 0,
	speed = 16,
	eggInventory = { Common = 0, Rare = 0, Legendary = 0 },
	creatures = {
		{ id = "pet_001", species = "Chick", mutation = "None" },
		{ id = "pet_001", species = "Bunny", mutation = "None" },
	},
	upgrades = { treadmill = 0, storage = 0 },
}, options)
assert(duplicateId == nil and duplicateIdError, "Duplicate creature IDs must be rejected")

local sparseCreatures, sparseCreaturesError = DataService.loadAndValidate({
	schemaVersion = 1,
	revision = 0,
	score = 0,
	coins = 0,
	speed = 16,
	eggInventory = { Common = 0, Rare = 0, Legendary = 0 },
	creatures = {
		[1] = { id = "pet_001", species = "Chick", mutation = "None" },
		[3] = { id = "pet_003", species = "Bunny", mutation = "None" },
	},
	upgrades = { treadmill = 0, storage = 0 },
}, options)
assert(sparseCreatures == nil and sparseCreaturesError, "Sparse creature inventories must be rejected")

local unknownUpgrade, unknownUpgradeError = DataService.loadAndValidate({
	schemaVersion = 1,
	revision = 0,
	score = 0,
	coins = 0,
	speed = 16,
	eggInventory = { Common = 0, Rare = 0, Legendary = 0 },
	creatures = {},
	upgrades = { treadmill = 0, storage = 0, hidden = 1 },
}, options)
assert(unknownUpgrade == nil and unknownUpgradeError, "Unknown upgrades must be rejected")

print("DataServiceSpec passed")
