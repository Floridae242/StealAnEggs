--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(ServerScriptService.Services.DataService)
local ProfileStoreService = require(ServerScriptService.Services.ProfileStoreService)

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

local records: { [string]: unknown } = {}
local mockStore = {}
function mockStore:UpdateAsync(key: string, transform: (unknown) -> unknown): unknown
	local nextValue = transform(records[key])
	records[key] = nextValue
	return nextValue
end

local key = "Player_42"
local firstClaim, firstClaimError = ProfileStoreService.claim(mockStore, key, "server-A", 100, 30, options)
assert(firstClaim and not firstClaimError, "First server must claim an unowned profile")
assert(firstClaim.profile.revision == 0, "New profile must start with revision zero")

local secondClaim, secondClaimError = ProfileStoreService.claim(mockStore, key, "server-B", 105, 30, options)
assert(
	secondClaim == nil and secondClaimError == "Profile is active on another server",
	"Active lease must exclude another server"
)

local changed = DataService.createDefault(options)
changed.coins = 75
local saved, saveError = ProfileStoreService.save(mockStore, key, "server-A", 110, 30, 0, changed, options)
assert(saved and not saveError, "Lease owner must save a matching revision")
assert(saved.profile.revision == 1 and saved.profile.coins == 75, "Save must increment revision exactly once")

local stale, staleError = ProfileStoreService.save(mockStore, key, "server-A", 115, 30, 0, changed, options)
assert(stale == nil and staleError == "Profile revision is stale", "Stale full-profile writes must be rejected")

local unclaimed, unclaimedError =
	ProfileStoreService.save(mockStore, "Player_unclaimed", "server-A", 120, 30, 0, changed, options)
assert(
	unclaimed == nil and unclaimedError == "Profile has no active lease",
	"Unclaimed profiles must return a lease error"
)

local invalidLease, invalidLeaseError =
	ProfileStoreService.claim(mockStore, "Player_overflow", "server-A", 1e308, 1e308, options)
assert(invalidLease == nil and invalidLeaseError == "Invalid profile lease request", "Lease expiry must remain finite")

local recovered, recoveredError = ProfileStoreService.claim(mockStore, key, "server-B", 141, 30, options)
assert(recovered and not recoveredError, "A lease-expired profile must recover for a new server")
assert(
	recovered.profile.revision == 1 and recovered.profile.coins == 75,
	"Recovery must retain the newest saved profile"
)

local releaseOk, releaseError = ProfileStoreService.release(mockStore, key, "server-B", options)
assert(releaseOk and not releaseError, "Lease owner must release its profile")

local missingRelease, missingReleaseError =
	ProfileStoreService.release(mockStore, "Player_unclaimed", "server-A", options)
assert(
	not missingRelease and missingReleaseError == "Profile lease belongs to another server",
	"Releasing an unclaimed profile must fail explicitly"
)

records.Player_corrupt = { envelopeVersion = 1, profile = "not-a-profile", lease = nil }
local corrupt, corruptError = ProfileStoreService.claim(mockStore, "Player_corrupt", "server-A", 200, 30, options)
assert(corrupt == nil and corruptError, "Corrupt profile data must not be overwritten during claim")
assert(records.Player_corrupt.profile == "not-a-profile", "Failed load must preserve existing profile data")

print("ProfileStoreServiceSpec passed")
