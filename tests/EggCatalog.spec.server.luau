--!strict

-- Run in Roblox Studio after Rojo sync. This is intentionally written before
-- EggCatalog so the expected rarity and hatch contracts are explicit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggCatalog = require(ReplicatedStorage.StealAnEggs.EggCatalog)

local function expect(condition: boolean, message: string)
	assert(condition, message)
end

local common = EggCatalog.getRarity("Common")
if not common then
	error("Common rarity must exist")
end
expect(common.depositCoins > 0, "Common eggs must award positive coins")

expect(EggCatalog.getRarity("NotARarity") == nil, "Unknown rarity must be rejected")
expect(EggCatalog.choosePet("Common", Random.new(7)) ~= nil, "Common eggs must hatch a pet")
expect(EggCatalog.choosePet("NotARarity", Random.new(7)) == nil, "Unknown rarity cannot hatch")

print("EggCatalogSpec passed")
