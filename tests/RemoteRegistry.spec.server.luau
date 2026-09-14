--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local RemoteRegistry = require(ServerScriptService.Services.RemoteRegistry)

local remotes = Instance.new("Folder")
remotes.Name = "RemoteRegistrySpec"
remotes.Parent = ServerScriptService

local created = RemoteRegistry.getOrCreate(remotes, "RequestDrop")
assert(created:IsA("RemoteEvent"), "Registry must create a RemoteEvent")
assert(created.Parent == remotes, "Registry must parent the created remote")

local reused = RemoteRegistry.getOrCreate(remotes, "RequestDrop")
assert(reused == created, "Registry must reuse a matching RemoteEvent")
assert(#remotes:GetChildren() == 1, "Registry must not duplicate a matching remote")

local invalid = Instance.new("Folder")
invalid.Name = "Feedback"
invalid.Parent = remotes
local ok = pcall(function()
	RemoteRegistry.getOrCreate(remotes, "Feedback")
end)
assert(not ok, "Registry must reject a name occupied by the wrong Instance class")

remotes:Destroy()
print("RemoteRegistrySpec passed")
