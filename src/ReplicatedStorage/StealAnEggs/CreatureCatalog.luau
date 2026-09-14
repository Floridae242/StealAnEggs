--!strict

export type Creature = {
	rarity: string,
	passiveCoinsPerSecond: number,
}

local creatures: { [string]: Creature } = {
	Chick = { rarity = "Common", passiveCoinsPerSecond = 0.25 },
	Bunny = { rarity = "Common", passiveCoinsPerSecond = 0.3 },
	Bluebird = { rarity = "Rare", passiveCoinsPerSecond = 0.9 },
	Fox = { rarity = "Rare", passiveCoinsPerSecond = 1.1 },
	Phoenix = { rarity = "Legendary", passiveCoinsPerSecond = 4 },
}

local mutationMultipliers: { [string]: number } = {
	None = 1,
	Lumina = 2,
	Void = 4,
}

local CreatureCatalog = {}

function CreatureCatalog.get(creatureName: string): Creature?
	return creatures[creatureName]
end

function CreatureCatalog.isKnownCreature(creatureName: string): boolean
	return creatures[creatureName] ~= nil
end

function CreatureCatalog.isKnownMutation(mutationName: string): boolean
	return mutationMultipliers[mutationName] ~= nil
end

function CreatureCatalog.getMutationMultiplier(mutationName: string?): number
	if not mutationName then
		return 1
	end
	return mutationMultipliers[mutationName] or 1
end

return CreatureCatalog
