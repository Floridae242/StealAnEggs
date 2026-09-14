--!strict

-- Server-only remote creation. A conflicting class is a deployment error, not
-- something gameplay should silently replace or work around.

local RemoteRegistry = {}

function RemoteRegistry.getOrCreate(parent: Instance, name: string): RemoteEvent
	assert(typeof(name) == "string" and name ~= "", "Remote name must be a non-empty string")

	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteEvent"), ("Remote %q exists with class %s"):format(name, existing.ClassName))
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

return RemoteRegistry
