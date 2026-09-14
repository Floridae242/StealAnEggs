--!strict

-- Owns the DataStore envelope, session lease, and revision checks. Gameplay
-- services provide only a validated profile snapshot and never write a key
-- directly.

local DataService = require(script.Parent:WaitForChild("DataService"))

export type Lease = {
	token: string,
	expiresAt: number,
}

export type ClaimResult = {
	profile: DataService.Profile,
	lease: Lease,
}

export type SaveResult = {
	profile: DataService.Profile,
	lease: Lease,
}

local ENVELOPE_VERSION = 1
local MAX_LEASE_SECONDS = 300
local ProfileStoreService = {}

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function cloneLease(token: string, expiresAt: number): Lease
	return { token = token, expiresAt = expiresAt }
end

local function decodeEnvelope(
	raw: unknown,
	options: DataService.ValidationOptions
): (DataService.Profile?, Lease?, string?)
	if raw == nil or typeof(raw) == "number" then
		local profile, profileError = DataService.loadAndValidate(raw, options)
		return profile, nil, profileError
	end
	if typeof(raw) ~= "table" then
		return nil, nil, "Profile payload must be a table"
	end

	if raw.envelopeVersion == nil then
		local profile, profileError = DataService.loadAndValidate(raw, options)
		return profile, nil, profileError
	end
	if raw.envelopeVersion ~= ENVELOPE_VERSION or typeof(raw.profile) ~= "table" then
		return nil, nil, "Profile envelope is invalid"
	end

	local profile, profileError = DataService.loadAndValidate(raw.profile, options)
	if not profile then
		return nil, nil, profileError
	end

	if raw.lease == nil then
		return profile, nil, nil
	end
	if typeof(raw.lease) ~= "table" or typeof(raw.lease.token) ~= "string" or raw.lease.token == "" then
		return nil, nil, "Profile lease is invalid"
	end
	if not isFiniteNumber(raw.lease.expiresAt) then
		return nil, nil, "Profile lease expiry is invalid"
	end
	return profile, cloneLease(raw.lease.token, raw.lease.expiresAt), nil
end

local function encodeEnvelope(profile: DataService.Profile, lease: Lease?): { [string]: unknown }
	return {
		envelopeVersion = ENVELOPE_VERSION,
		profile = profile,
		lease = lease and cloneLease(lease.token, lease.expiresAt) or nil,
	}
end

local function update(dataStore: any, key: string, transform: (unknown) -> unknown): (boolean, unknown?, string?)
	local success, valueOrError = pcall(function()
		return dataStore:UpdateAsync(key, transform)
	end)
	if not success then
		return false, nil, "DataStore request failed: " .. tostring(valueOrError)
	end
	return true, valueOrError, nil
end

local function isValidLeaseRequest(token: string, now: number, leaseSeconds: number): boolean
	return token ~= ""
		and isFiniteNumber(now)
		and isFiniteNumber(leaseSeconds)
		and leaseSeconds > 0
		and leaseSeconds <= MAX_LEASE_SECONDS
		and isFiniteNumber(now + leaseSeconds)
end

function ProfileStoreService.claim(
	dataStore: any,
	key: string,
	token: string,
	now: number,
	leaseSeconds: number,
	options: DataService.ValidationOptions
): (ClaimResult?, string?)
	if not isValidLeaseRequest(token, now, leaseSeconds) then
		return nil, "Invalid profile lease request"
	end

	local transformError: string? = nil
	local requestOk, updated, updateError = update(dataStore, key, function(raw)
		local profile, lease, decodeError = decodeEnvelope(raw, options)
		if not profile then
			transformError = decodeError or "Profile data is invalid"
			return raw
		end
		if lease and lease.token ~= token and lease.expiresAt > now then
			return raw
		end
		return encodeEnvelope(profile, cloneLease(token, now + leaseSeconds))
	end)
	if not requestOk then
		return nil, updateError
	end
	if transformError then
		return nil, transformError
	end
	if updated == nil then
		return nil, "Profile claim was cancelled"
	end

	local profile, lease, decodeError = decodeEnvelope(updated, options)
	if not profile or not lease then
		return nil, decodeError or "Profile claim did not return a lease"
	end
	if lease.token ~= token then
		return nil, "Profile is active on another server"
	end
	return { profile = profile, lease = lease }, nil
end

function ProfileStoreService.save(
	dataStore: any,
	key: string,
	token: string,
	now: number,
	leaseSeconds: number,
	expectedRevision: number,
	candidate: unknown,
	options: DataService.ValidationOptions
): (SaveResult?, string?)
	if not isValidLeaseRequest(token, now, leaseSeconds) then
		return nil, "Invalid profile save request"
	end
	if typeof(expectedRevision) ~= "number" or expectedRevision < 0 or expectedRevision % 1 ~= 0 then
		return nil, "Invalid expected profile revision"
	end
	local validatedCandidate, candidateError = DataService.loadAndValidate(candidate, options)
	if not validatedCandidate then
		return nil, candidateError
	end

	local transformError: string? = nil
	local requestOk, updated, updateError = update(dataStore, key, function(raw)
		local stored, lease, decodeError = decodeEnvelope(raw, options)
		if not stored or not lease then
			transformError = decodeError or "Profile has no active lease"
			return raw
		end
		if lease.token ~= token or lease.expiresAt <= now then
			transformError = "Profile lease is no longer owned by this server"
			return raw
		end
		if stored.revision ~= expectedRevision then
			transformError = "Profile revision is stale"
			return raw
		end

		validatedCandidate.revision = expectedRevision + 1
		return encodeEnvelope(validatedCandidate, cloneLease(token, now + leaseSeconds))
	end)
	if not requestOk then
		return nil, updateError
	end
	if transformError then
		return nil, transformError
	end
	if updated == nil then
		return nil, "Profile save was cancelled"
	end

	local profile, lease, decodeError = decodeEnvelope(updated, options)
	if not profile or not lease or lease.token ~= token then
		return nil, decodeError or "Profile save did not retain this lease"
	end
	return { profile = profile, lease = lease }, nil
end

function ProfileStoreService.release(
	dataStore: any,
	key: string,
	token: string,
	options: DataService.ValidationOptions
): (boolean, string?)
	if token == "" then
		return false, "Invalid profile lease token"
	end
	local transformError: string? = nil
	local requestOk, updated, updateError = update(dataStore, key, function(raw)
		local profile, lease, decodeError = decodeEnvelope(raw, options)
		if not profile then
			transformError = decodeError or "Profile data is invalid"
			return raw
		end
		if not lease or lease.token ~= token then
			transformError = "Profile lease belongs to another server"
			return raw
		end
		return encodeEnvelope(profile, nil)
	end)
	if not requestOk then
		return false, updateError
	end
	if transformError then
		return false, transformError
	end
	if updated == nil then
		return false, "Profile release was cancelled"
	end
	local _, lease, decodeError = decodeEnvelope(updated, options)
	if decodeError then
		return false, decodeError
	end
	return lease == nil, if lease == nil then nil else "Profile lease belongs to another server"
end

return ProfileStoreService
