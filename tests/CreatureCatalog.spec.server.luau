--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreatureCatalog = require(ReplicatedStorage.StealAnEggs.CreatureCatalog)

local chick = CreatureCatalog.get("Chick")
if not chick then
	error("Chick must exist")
end
assert(chick.passiveCoinsPerSecond > 0, "Creatures need positive passive income")
assert(CreatureCatalog.get("UnknownCreature") == nil, "Unknown creatures must be rejected")
assert(CreatureCatalog.isKnownCreature("Chick"), "Known creature validation must succeed")
assert(not CreatureCatalog.isKnownCreature("UnknownCreature"), "Unknown creature validation must fail")
assert(CreatureCatalog.isKnownMutation("Lumina"), "Known mutation validation must succeed")
assert(not CreatureCatalog.isKnownMutation("UnknownMutation"), "Unknown mutation validation must fail")
assert(CreatureCatalog.getMutationMultiplier("Lumina") > 1, "Lumina must be a positive bonus")
assert(CreatureCatalog.getMutationMultiplier("UnknownMutation") == 1, "Unknown mutations must not grant bonuses")

print("CreatureCatalogSpec passed")
