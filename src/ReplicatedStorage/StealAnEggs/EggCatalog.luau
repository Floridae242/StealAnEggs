--!strict

export type Rarity = {
	weight: number,
	color: Color3,
	depositCoins: number,
	pets: { string },
}

local rarities: { [string]: Rarity } = {
	Common = {
		weight = 70,
		color = Color3.fromRGB(236, 240, 241),
		depositCoins = 12,
		pets = { "Chick", "Bunny" },
	},
	Rare = {
		weight = 25,
		color = Color3.fromRGB(52, 152, 219),
		depositCoins = 45,
		pets = { "Bluebird", "Fox" },
	},
	Legendary = {
		weight = 5,
		color = Color3.fromRGB(241, 196, 15),
		depositCoins = 180,
		pets = { "Phoenix" },
	},
}

local orderedRarities = { "Common", "Rare", "Legendary" }

local EggCatalog = {}

function EggCatalog.getRarity(rarityName: string): Rarity?
	return rarities[rarityName]
end

function EggCatalog.roll(random: Random): string
	local target = random:NextNumber(0, 100)
	local total = 0
	for _, rarityName in orderedRarities do
		total += rarities[rarityName].weight
		if target <= total then
			return rarityName
		end
	end
	return "Common"
end

function EggCatalog.choosePet(rarityName: string, random: Random): string?
	local rarity = rarities[rarityName]
	if not rarity or #rarity.pets == 0 then
		return nil
	end
	return rarity.pets[random:NextInteger(1, #rarity.pets)]
end

function EggCatalog.getRarityNames(): { string }
	return table.clone(orderedRarities)
end

return EggCatalog
