--[[--
	This is a part of ProfileStoreV3
    ProfileStoreV3 <https://github.com/Coffilhg/ProfileStoreV3>
    Copyright © 2026 Coffilhg (Roblox UserId 517222346)
    
	Licensed under the Apache License, Version 2.0 (the "License");
    see LICENSE & NOTICE or <http://www.apache.org/licenses/LICENSE-2.0>

    ProfileStoreV3 Version: 0.0.0
	Stars are appreciated!
--]]--

---		ProfileStoreV3 (PSV3)						---
---		GetDIIP ~ Get Data Instances Inside Player	---
---		This is part of the client-side of PSV3		---
--!strict

local Players = game:GetService(`Players`)
local RS = game:GetService(`ReplicatedStorage`)
local Packages = RS:WaitForChild(`Packages`)

local CoffeeRemotes = require(Packages:WaitForChild(`CoffeeRemotesClient`))
local RemoteEvent, RemoteFunction, URemoteEvent = CoffeeRemotes:Unpack()

-- For Public Folders like "Leaderstats" usually are
-- Updates of such are handled here.
local DataUpdatePublicFolderValueRemote = RemoteEvent.new(`PSV3~DataUpdatePublicFolderValueRemote`)
local UnreliableDataUpdatePublicFolderValueRemote = RemoteEvent.new(`PSV3~UnreliableDataUpdatePublicFolderValueRemote`)
local GetFolderReplicatedCDNs = RemoteFunction.new(`PSV3~GetFolderReplicatedCDNs`)
local LoadPublicFolderValues = RemoteFunction.new(`PSV3~LoadPublicFolderValues`)
local GetPathArrangements = RemoteFunction.new(`PSV3~GetPathArrangements`)



--- GetDIIP Main (Generally all Data about any Player) ---
local CoffeeObjects = require(script.GetDIIPCO)
local CoffeeBaseValue = CoffeeObjects.CoffeeBaseValue
local CoffeeFolder = CoffeeObjects.CoffeeFolder



local PlayersDataCache: {[number]: CoffeeObjects.CoffeeFolder} = {}
local LocalPlayer = Players.LocalPlayer :: Player
local GetDIIP = {} -- module
export type GetDIIP = typeof(GetDIIP)

-- player defaults to game.Players.LocalPlayer if nil
function GetDIIP.GetPlayerData(
	self: GetDIIP,
	player: Player?
)
	if not (typeof(player) == `Instance` and player.ClassName == `Player`) then
		player = LocalPlayer
	end

	local UID: number = (player :: Player).UserId

	local dataCache = PlayersDataCache[UID]
	if dataCache then
		return dataCache
	end

	local dataRoot = CoffeeFolder.new(nil, UID)
	PlayersDataCache[UID] = dataRoot

	return dataRoot
end
--- /E GetDIIP Main (Generally all Data about any Player) ---



--- GetDIIP Handling mainly for "Leaderstats" (technically works for any folder) ---
local PathArrangements = CoffeeObjects:GetPathArrangements()

local ValueInstanceClassNamePerType = {
	string = "StringValue",
	number = "NumberValue",
	boolean = "BoolValue",
	typeof = {
		BrickColor = "BrickColorValue",
		CFrame = "CFrameValue",
		Color3 = "Color3Value",
		Vector3 = "Vector3Value"
	},
}

type UID = number
type Path = string
type UpdateValueCallback = (newValue: any) -> ()
type FolderValues = {
	[Path]: UpdateValueCallback,
}
local PublicFolderValues: {[UID]: FolderValues} = {}



local function YieldRemoteFunctionUntilSuccess(RemoteFunction : CoffeeRemotes.RemoteFunctionType, interval: number?, ...): ...any
	local success, result = RemoteFunction:InvokeServer(...)
	if not success then
		repeat
			task.wait(interval)
			success, result = RemoteFunction:InvokeServer(...)
		until success
	end
	return result
end

local FolderReplicatedCDNs = YieldRemoteFunctionUntilSuccess(GetFolderReplicatedCDNs)

type ArrangementIndex = number
local LoadsPerPathIndex: {
	[ArrangementIndex]: {
		[UID]: any, -- Value
	},
} = {}
local function ApplyUpdate(UID: number, path: string, newValue)
	--Counter()

	local publicFolderValues = PublicFolderValues[UID]
	if not publicFolderValues then
		return
	end

	local valueInstanceUpdateCallback = publicFolderValues[path]
	if type(valueInstanceUpdateCallback) ~= "function" then
		return
	end

	valueInstanceUpdateCallback(newValue)
end

-- Used to resolve Paths that are not yet cached
-- 
function LoadArrangement(index : number, UID : number, newValue): Path?
	local path = PathArrangements[index]
	if path then
		-- Path is already resolved (known);
		-- Exit because there's no need to cache
		-- the newValue and wait until path is resolved
		return path
	end



	if LoadsPerPathIndex[index] then
		-- already Yielding to resolve the path of index,
		-- only update the value that should be written once
		-- the path of index is resolved (known)
		LoadsPerPathIndex[index][UID] = newValue
		return nil
	end
	
	-- Not yielding to resolve a path yet, create a table
	-- to store all incoming data by that index, so that
	-- once the path is resolved (known), we can apply
	-- that value
	LoadsPerPathIndex[index] = {}
	LoadsPerPathIndex[index][UID] = newValue



	--print("Loading PathArrangement for", index)
	-- Start yielding to resolve the path by index
	local path: string = YieldRemoteFunctionUntilSuccess(GetPathArrangements, nil, index)
	PathArrangements[index] = path
	-- yielding complete, we now know path by index
	--print(`PathArrangements[{index}]:`, PathArrangements[index])
	
	-- apply all of the latest updates received for the index
	-- whilst we were yielding to resolve the path, now with
	-- the resolved (known) path
	for uid, value in pairs(LoadsPerPathIndex[index]) do
		ApplyUpdate(uid, path, value)
	end
	-- clear cache
	LoadsPerPathIndex[index] = nil

	return nil -- makes DUF stop; (We've already handled the update above in here)
end

-- DataUpdateFolder
local function DUF(UID : number, pathIndex : number, newValue)
	--print("DUF", UID, pathIndex, newValue)
	local path = LoadArrangement(pathIndex, UID, newValue)
	if not path then
		return
	end
	
	ApplyUpdate(UID, path, newValue)
end
DataUpdatePublicFolderValueRemote:Connect(DUF)
UnreliableDataUpdatePublicFolderValueRemote:Connect(DUF)

local function updateValueInstance(value: any?, parent: Folder, valueInstance: ValueBase?, name: string?, UID: number): ValueBase?
	--print(`Updating "{name}" for Player~{UID}`)

	if valueInstance then
		local valueInstanceClassName = "NumberValue"
		if value then
			valueInstanceClassName = ValueInstanceClassNamePerType[type(value)]
			if not valueInstanceClassName then
				valueInstanceClassName = ValueInstanceClassNamePerType["typeof"][typeof(value)]
			end
			if not valueInstanceClassName then
				warn(`Can't apply a new value ({typeof(value)}: {value}) to Player_{UID}.{parent.Name}.{valueInstance.Name}`)
				return nil
			end
		end

		if valueInstanceClassName ~= valueInstance.ClassName then
			valueInstance:Destroy()
			valueInstance = Instance.new(valueInstanceClassName, parent)
			valueInstance.Name = `{name}`
		end

		valueInstance.Value = value

		return valueInstance :: ValueBase | any
	end


	if not value then
		valueInstance = Instance.new("NumberValue", parent)
		valueInstance.Name = `{name}`
	else
		local valueInstanceClassName = ValueInstanceClassNamePerType[type(value)]
		if not valueInstanceClassName then
			valueInstanceClassName = ValueInstanceClassNamePerType["typeof"][typeof(value)]
		end
		if not valueInstanceClassName then
			warn(`Can't apply a value ({typeof(value)}: {value}) to Player_{UID}.{parent.Name}.{name}{valueInstance and "" or " (The valueInstance is missing)"}`)
			return nil
		end

		valueInstance = Instance.new(valueInstanceClassName, parent)
		valueInstance.Value = value
		valueInstance.Name = `{name}`
	end

	return valueInstance
end

function PlayerAdded(player : Player)
	local UID = player.UserId
	local folderValues: FolderValues = {}
	PublicFolderValues[UID] = folderValues
	
	local publicFolderValues = YieldRemoteFunctionUntilSuccess(LoadPublicFolderValues, 0.3, UID)

	for folderName, folderCDNs in pairs(FolderReplicatedCDNs) do
		local folder = Instance.new("Folder", player)
		folder.Name = folderName

		for _, CDNInfo in ipairs(folderCDNs) do
			local path: string? = CDNInfo["CDN"]

			if not path then
				continue
			end

			local value = publicFolderValues[path]
			local name: string? = CDNInfo["DisplayName"] or path
			local valueInstance = updateValueInstance(value, folder, nil, name, UID)

			folderValues[path] = function(newValue)
				valueInstance = updateValueInstance(newValue, folder, valueInstance, name, UID)
			end
		end
	end
end
for _, player in Players:GetPlayers() do
	task.spawn(PlayerAdded, player)
end
Players.PlayerAdded:Connect(PlayerAdded)
local function OnPlayerRemoving(player : Player)
	local UID = player.UserId

	if UID == LocalPlayer.UserId then
		return
	end
	
	local CachedRoot = PlayersDataCache[UID]
	if CachedRoot then
		CachedRoot:Destroy()
	end

	PlayersDataCache[UID] = nil
end
Players.PlayerRemoving:Connect(OnPlayerRemoving)

return GetDIIP