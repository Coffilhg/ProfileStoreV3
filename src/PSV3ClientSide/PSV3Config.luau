--[[--
	This is a part of ProfileStoreV3
    ProfileStoreV3 <https://github.com/Coffilhg/ProfileStoreV3>
    Copyright © 2026 Coffilhg (Roblox UserId 517222346)
    
	Licensed under the Apache License, Version 2.0 (the "License");
    see LICENSE & NOTICE or <http://www.apache.org/licenses/LICENSE-2.0>

    ProfileStoreV3 Version: 0.0.0
	Stars are appreciated!
--]]--

local RS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")

local ProfileStoreV3Config = {}
export type ProfileStoreV3Config = {
    [
        "DataUpdateValueGlobal" |
        "FolderChildAddedGlobal" |
        "FolderChildRemovedGlobal" |
        "GlobalUnsubscribe"
    ]: RemoteEvent
}


local DefaultPath: string = `ReplicatedStorage.ProfileStoreV3Remotes`
local ServerValuesPath: string = DefaultPath..`.Global`
local LocalPlayerReplicationPath: string = DefaultPath..`.Self`
local PlayersReplicationPath: string = DefaultPath..`.Players`

local RemotesSetup: {[string]: { Path: string, Events: {string}, Functions: {string} }} = {
    ServerValues = {
        Path = ServerValuesPath,
        Events = {
            "DataUpdateValueGlobal",
            "FolderChildAddedGlobal",
            "FolderChildRemovedGlobal",
            "GlobalUnsubscribe",
        },
        Functions = {
            "GlobalSubscribe"
        },
    },
    Players = {
        Path = PlayersReplicationPath,
        Events = {
            "DataUpdateValue",
            "FolderChildAdded",
            "FolderChildRemoved"
        },
        Functions = {},
    },
    LocalPlayer = {
        Path = LocalPlayerReplicationPath,
        Events = {},
        Functions = {},
    }
}

local function SetupRemotes()
    for category, setup in pairs(RemotesSetup) do
        local path = setup.Path
        for _, remoteEvent in ipairs(setup.Events) do
            ProfileStoreV3Config[remoteEvent] = CreateRemote(true, remoteEvent, path)
        end
        for _, remoteFunction in ipairs(setup.Functions) do
            ProfileStoreV3Config[remoteFunction] = CreateRemote(false, remoteFunction, path)
        end
    end
end


































-- Helpers
function CreateRemote(isRemoteEvent: boolean, name: string, parentPath: string?): RemoteEvent | RemoteFunction
    local remote = Instance.new(isRemoteEvent and `RemotEvent` or `RemoteFunction`)
    remote.Name = `{name}`
    -- CreateRemote is only intended to be used on server side.
    remote.Parent = CreateOrGetFolderByPath(type(parentPath) == `string` and parentPath or DefaultPath)
    return remote
end
function CreateOrGetFolderByPath(path: string): Folder | Instance
    local returnedInstance = game
    for _, name in ipairs(path:split(`.`)) do
        local child = returnedInstance:FindFirstChild(name)
        if not child then
            child = Instance.new(`Folder`)
            child.Name = name
            child.Parent = returnedInstance
        end

        returnedInstance = child
    end
    return returnedInstance
end
function GetChildByPathFromInstanceAwait(instance: Instance, path: string): Instance
	-- if type(path) ~= `string` then
	-- 	error(`GetChildByPathFromInstanceAwait "path" misinput: expected string, got {path} of type {type(path)}`)
	-- end
	-- if typeof(instance) ~= `Instance` then
	-- 	error(`GetChildByPathFromInstanceAwait "instance" misinput: expected Instance, got {instance} of typeof {typeof(instance)}`)
	-- end
	
	for _, name in ipairs(path:split(`.`)) do
		if not instance then
			break
		end
		instance = instance:WaitForChild(name) :: Instance -- hide the strict and reuse the variable
	end
	
	return instance
end

SetupRemotes()

return ProfileStoreV3Config