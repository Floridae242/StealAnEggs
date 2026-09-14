--!strict

-- Pure, server-only profile schema logic. DataStore I/O is intentionally kept
-- out of this module until session locking and retry ownership are integrated.

export type CreatureRecord = {
	id: string,
	species: string,
	mutation: string,
}

export type Profile = {
	schemaVersion: number,
	revision: number,
	score: number,
	coins: number,
	speed: number,
	eggInventory: { [string]: number },
	creatures: { CreatureRecord },
	upgrades: { treadmill: number, storage: number },
}

export type ValidationOptions = {
	baseWalkSpeed: number,
	maxWalkSpeed: number,
	rarityNames: { string },
	isKnownCreature: (string) -> boolean,
	isKnownMutation: (string) -> boolean,
}

local SCHEMA_VERSION = 1
local MAX_CREATURES = 100
local MAX_INVENTORY_PER_RARITY = 999
local MAX_CURRENCY = 2_000_000_000
local MAX_UPGRADE_LEVEL = 100

local DataService = {}

local function nonNegativeInteger(value: unknown, maximum: number): number?
	if typeof(value) ~= "number" or value ~= value or value < 0 or value % 1 ~= 0 or value > maximum then
		return nil
	end
	return value
end

local function raritySet(rarityNames: { string }): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for _, rarityName in rarityNames do
		result[rarityName] = true
	end
	return result
end

function DataService.createDefault(options: ValidationOptions): Profile
	local eggInventory: { [string]: number } = {}
	for _, rarityName in options.rarityNames do
		eggInventory[rarityName] = 0
	end
	return {
		schemaVersion = SCHEMA_VERSION,
		revision = 0,
		score = 0,
		coins = 0,
		speed = options.baseWalkSpeed,
		eggInventory = eggInventory,
		creatures = {},
		upgrades = { treadmill = 0, storage = 0 },
	}
end

local function validateV1(raw: { [string]: unknown }, options: ValidationOptions): (Profile?, string?)
	local revision = nonNegativeInteger(raw.revision, MAX_CURRENCY)
	local score = nonNegativeInteger(raw.score, MAX_CURRENCY)
	local coins = nonNegativeInteger(raw.coins, MAX_CURRENCY)
	local speed = raw.speed
	if not revision or not score or not coins then
		return nil, "Profile currency or revision is invalid"
	end
	if typeof(speed) ~= "number" or speed ~= speed or speed < options.baseWalkSpeed or speed > options.maxWalkSpeed then
		return nil, "Profile speed is invalid"
	end

	local rawEggInventory = raw.eggInventory
	if typeof(rawEggInventory) ~= "table" then
		return nil, "Profile egg inventory is invalid"
	end
	local allowedRarities = raritySet(options.rarityNames)
	local eggInventory: { [string]: number } = {}
	for _, rarityName in options.rarityNames do
		local count = nonNegativeInteger(rawEggInventory[rarityName], MAX_INVENTORY_PER_RARITY)
		if not count then
			return nil, "Profile egg inventory contains an invalid count"
		end
		eggInventory[rarityName] = count
	end
	for rarityName in rawEggInventory do
		if typeof(rarityName) ~= "string" or not allowedRarities[rarityName] then
			return nil, "Profile egg inventory contains an unknown rarity"
		end
	end

	local rawCreatures = raw.creatures
	if typeof(rawCreatures) ~= "table" then
		return nil, "Profile creature inventory is invalid"
	end
	local creatures: { CreatureRecord } = {}
	local creatureIds: { [string]: boolean } = {}
	local creatureCount = 0
	for index, rawCreature in rawCreatures do
		if typeof(index) ~= "number" or index < 1 or index % 1 ~= 0 then
			return nil, "Profile creature inventory must be a sequential array"
		end
		creatureCount += 1
		if creatureCount > MAX_CREATURES then
			return nil, "Profile creature inventory is too large"
		end
		if typeof(rawCreature) ~= "table" then
			return nil, "Profile creature record is invalid"
		end
		local id = rawCreature.id
		local species = rawCreature.species
		local mutation = rawCreature.mutation
		if
			typeof(id) ~= "string"
			or id == ""
			or creatureIds[id]
			or typeof(species) ~= "string"
			or not options.isKnownCreature(species)
			or typeof(mutation) ~= "string"
			or not options.isKnownMutation(mutation)
		then
			return nil, "Profile creature record has an invalid ID, species, or mutation"
		end
		creatureIds[id] = true
		creatures[index] = { id = id, species = species, mutation = mutation }
	end
	for index = 1, creatureCount do
		if not creatures[index] then
			return nil, "Profile creature inventory must be a sequential array"
		end
	end

	local rawUpgrades = raw.upgrades
	if typeof(rawUpgrades) ~= "table" then
		return nil, "Profile upgrades are invalid"
	end
	local treadmill = nonNegativeInteger(rawUpgrades.treadmill, MAX_UPGRADE_LEVEL)
	local storage = nonNegativeInteger(rawUpgrades.storage, MAX_UPGRADE_LEVEL)
	if not treadmill or not storage then
		return nil, "Profile upgrades contain an invalid level"
	end
	for upgradeName in rawUpgrades do
		if upgradeName ~= "treadmill" and upgradeName ~= "storage" then
			return nil, "Profile upgrades contain an unknown upgrade"
		end
	end

	return {
		schemaVersion = SCHEMA_VERSION,
		revision = revision,
		score = score,
		coins = coins,
		speed = speed,
		eggInventory = eggInventory,
		creatures = creatures,
		upgrades = { treadmill = treadmill, storage = storage },
	}
end

function DataService.loadAndValidate(raw: unknown, options: ValidationOptions): (Profile?, string?)
	if raw == nil then
		return DataService.createDefault(options), nil
	end
	if typeof(raw) == "number" then
		local score = nonNegativeInteger(raw, MAX_CURRENCY)
		if not score then
			return nil, "Legacy profile score is invalid"
		end
		local migrated = DataService.createDefault(options)
		migrated.score = score
		return migrated, nil
	end
	if typeof(raw) ~= "table" then
		return nil, "Profile payload must be a table"
	end

	local schemaVersion = raw.schemaVersion
	if schemaVersion == nil or schemaVersion == 0 then
		local score = nonNegativeInteger(raw.score, MAX_CURRENCY)
		if not score then
			return nil, "Legacy profile score is invalid"
		end
		local migrated = DataService.createDefault(options)
		migrated.score = score
		return migrated, nil
	end
	if schemaVersion ~= SCHEMA_VERSION then
		return nil, "Unsupported profile schema version"
	end
	return validateV1(raw, options)
end

return DataService
