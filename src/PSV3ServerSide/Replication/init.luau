--[[--
	This is a part of ProfileStoreV3
    ProfileStoreV3 <https://github.com/Coffilhg/ProfileStoreV3>
    Copyright © 2026 Coffilhg (Roblox UserId 517222346)
    
	Licensed under the Apache License, Version 2.0 (the "License");
    see LICENSE & NOTICE or <http://www.apache.org/licenses/LICENSE-2.0>

    ProfileStoreV3 Version: 0.0.0
	Stars are appreciated!
--]]--

--!strict
--!optimize 2

local Players = game:GetService(`Players`)
local SSS = game:GetService(`ServerScriptService`)
local RS = game:GetService(`ReplicatedStorage`)

local SPackages = SSS.ServerPackages
local Packages = RS.Packages

local CoffeeRemotes = require(SPackages.CoffeeRemotesServer)
local CoffeeParser = require(Packages.CoffeeParser)
local CoffeeObjects = require(Packages.CoffeeObjects)
local Counter = require(Packages.Counter)
local Types = require(script.Parent.Types)
local DataConfig = require(script.Parent.DataConfig)
local IsSafeInteger = require(script.Parent.IsSafeInteger)

local Validate = require(script.Validate)

if not Validate() then
	error(`DataConfig is Invalid.`)
end



-- CoffeeRemotes
local RemoteEvent, RemoteFunction, URemoteEvent = CoffeeRemotes:Unpack()
-- CoffeeObjects
local ValNew = CoffeeObjects.CoffeeBaseValue.new
local ValidateVal = CoffeeObjects.CoffeeBaseValue.validateClass
local ValidateUVal = CoffeeObjects.CoffeeBaseValue.validateUnlinkedClass
local FolNew = CoffeeObjects.CoffeeFolder.new
local ValidateFol = CoffeeObjects.CoffeeFolder.validateClass
local ValidateUFol = CoffeeObjects.CoffeeFolder.validateUnlinkedClass








--- Create Replication Remotes ---
local Subscribe = RemoteFunction.new(`PSV3~Subscribe`)
local Unsubscribe = RemoteEvent.new(`PSV3~Unsubscribe`)
-- CoffeeBaseValue
local DataUpdateValue = RemoteEvent.new(`PSV3~DataUpdateValue`)
local DataUpdateValueSelf = RemoteEvent.new(`PSV3~DataUpdateValueSelf`)
-- CoffeeFolder
local FolderChildAdded = RemoteEvent.new(`PSV3~FolderChildAdded`)
local FolderChildAddedSelf = RemoteEvent.new(`PSV3~FolderChildAddedSelf`)
local FolderChildRemoved = RemoteEvent.new(`PSV3~FolderChildRemoved`)
local FolderChildRemovedSelf = RemoteEvent.new(`PSV3~FolderChildRemovedSelf`)

-- FolderReplicatedCDNs (CoffeeBaseValue)
-- For Public Folders like "Leaderstats" usually are
-- Updates of such are handled here.
local DataUpdatePublicFolderValueRemote = RemoteEvent.new(`PSV3~DataUpdatePublicFolderValueRemote`)
local UnreliableDataUpdatePublicFolderValueRemote = RemoteEvent.new(`PSV3~UnreliableDataUpdatePublicFolderValueRemote`)
local GetFolderReplicatedCDNs = RemoteFunction.new(`PSV3~GetFolderReplicatedCDNs`)
local LoadPublicFolderValues = RemoteFunction.new(`PSV3~LoadPublicFolderValues`)
local GetPathArrangements = RemoteFunction.new(`PSV3~GetPathArrangements`)





































local Build = require(script.Build)
local PathArrangements: Types.PathArrangements = Build.PathArrangements
local IsPublic: Types.IsPublic = Build.IsPublic
local IsSelfPublic: Types.IsSelfPublic = Build.IsSelfPublic
local IsPrivate: Types.IsPrivate = Build.IsPrivate
local IsAPublicFolderValue: Types.IsAPublicFolderValue = Build.IsAPublicFolderValue
local SubscribedPlayers: Types.SubscribedPlayers = Build.SubscribedPlayers

local PublicFolderValues = {} :: {[Player]: {[Types.PathIndex]: Types.Val}}

local FolderReplicatedCDNs : Types.FolderReplicatedCDNs = DataConfig.FolderReplicatedCDNs





















--- Helpers ---

-- Get the subscribedPlayers from SubscribedPlayers[pathIndex]
-- Creates an empty table if none exists yet
-- Just a utility to reuse code
local function GetSubscribedPlayers(pathIndex: Types.PathIndex)
	local subscribedPlayers = SubscribedPlayers[pathIndex]

	if not subscribedPlayers then
		SubscribedPlayers[pathIndex] = {}
		return SubscribedPlayers[pathIndex]
	end

	return subscribedPlayers
end

-- build path relationships consistently in ConnectReplication
local function BuildChildPathAndChildPathIndex(
	currentPath: Types.CDNPath,
	key: Types.TableIndex
): (Types.CDNPath, Types.PathIndex)
	local childPath: Types.CDNPath = (currentPath ~= nil and currentPath ~= "")
		and `{currentPath}.{key}`
		or `{key}`

	local childPathIndex: Types.PathIndex = PathArrangements[childPath]

	return childPath, childPathIndex
end



--[[
function debugIsAuthorized(player : Player, ownerPlayer : Player, pathIndex : Types.PathIndex, is : boolean)
	print(`Player "{player.Name}" {is and "is" or "is NOT"} authorized to view/subscribe {player.UserId == ownerPlayer.UserId and "own" or ownerPlayer.Name.."'s"} DataObject by pathCDN: "{PathArrangements:GetKeyByIndex(pathIndex)}"`)
end
function debugSubscriptionStatusChanged(player : Player, pathIndex : Types.PathIndex)
	local isSubscribed = ProfileStoreV3Replication:GetSubscribedPlayers(pathIndex)[player]
	
	print(`Player "{player.Name}" Subscription status for pathCDN "{PathArrangements:GetKeyByIndex(pathIndex)}" ({pathIndex}) has updated to {isSubscribed}`)
end
--]]

-- Determines whether the player can see data stored at pathIndex of ownerPlayer
local function IsAuthorized(player : Player, ownerPlayer : Player, pathIndex : Types.PathIndex): boolean
	-- add an override for admins here or anywhere in between the validations!

	local isAPublicFolderValue = IsAPublicFolderValue[pathIndex]
	if type(isAPublicFolderValue) == "table" then
		--debugIsAuthorized(player, ownerPlayer, pathIndex, true)
		return true
	end



	local isPrivate = IsPrivate[pathIndex]
	if isPrivate == true then
		--debugIsAuthorized(player, ownerPlayer, pathIndex, false)
		return false
	end



	local isPublic = IsPublic[pathIndex]
	if isPublic == true then
		--debugIsAuthorized(player, ownerPlayer, pathIndex, true)
		return true
	end



	local isSelfPublic = IsSelfPublic[pathIndex]
	if isSelfPublic == true and player.UserId == ownerPlayer.UserId then
		--debugIsAuthorized(player, ownerPlayer, pathIndex, true)
		return true
	end



	--debugIsAuthorized(player, ownerPlayer, pathIndex, false)
	return false -- none criteria was met for authorizing!
end

local function SubscribePlayerToPathIndex(player: Player, pathIndex: Types.PathIndex)
	local subscribedPlayers = GetSubscribedPlayers(pathIndex)
	--debugSubscriptionStatusChanged(player, pathIndex)
	subscribedPlayers[player] = true
end

--[[-- Something like this will be implemented soon...
-- GetSubscribedPlayers for the wanted pathIndex and add the authorized
-- Player (admin/moderator/dev) instance in there with value = true; e.g.:

function AuthorizeSecurityBypass(pathIndex : Types.PathIndex, authorizedPlayer : Player)
	local subscribedPlayers = GetSubscribedPlayers(pathIndex)
	
	subscribedPlayers[authorizedPlayer] = true
end

-- NOTE: This must be done every time after the authorized player unsubscribes from this pathIndex
-- Unsubscribe happens automatically whenever you :Destroy the respective CoffeeObject on the Client
--]]

--- /E Helpers ---
















--- Multiplexing to save memory ---
-- Create a single metatable to multiplex one function for multiple Objects (Saves Memory)
type DUVPublicStructureBase = { -- DUV -> Data Update: Value
	UID: number,
	pathIndex: Types.PathIndex,
}
type DUVPublicStructure = setmetatable<DUVPublicStructureBase, {
	__call: (self: DUVPublicStructure, v: Types.SupportedTypesList) -> (),
}>

type DUVStructureBase = DUVPublicStructureBase & {
	subscribedPlayers: Types.PlayerSet,
	player: Player,
}
type DUVStructure = setmetatable<DUVStructureBase, {
	__call: (self: DUVStructure, v: Types.SupportedTypesList) -> (),
}>
type ReplicateCallMetamethod = (self: DUVPublicStructure | DUVStructure, v: Types.SupportedTypesList) -> ()


local DataUpdatePublicFolderValueCallback = {}
function DataUpdatePublicFolderValueCallback.__call(self: DUVPublicStructure, v: Types.SupportedTypesList)
	DataUpdatePublicFolderValueRemote:FireAllClients(self.UID, self.pathIndex, v)
end

local DataUpdateValueCallback = {}
function DataUpdateValueCallback.__call(self: DUVStructure, v: Types.SupportedTypesList)
	for subscribedPlayer in pairs(self.subscribedPlayers) do
		if subscribedPlayer.UserId == self.UID then
			DataUpdateValueSelf:FireClient(self.player, self.pathIndex, v)
			continue
		end
		DataUpdateValue:FireClient(subscribedPlayer, self.UID, self.pathIndex, v)
	end
end
--- /E Multiplexing to save memory ---


















local ProfileStoreV3Replication = {}
export type Replication = typeof(ProfileStoreV3Replication)

function ProfileStoreV3Replication.PrintDebugReplicationLookup(self : Replication)
	print(`DebugReplicationLookup:`, self:GetDebugReplicationLookup())
end
function ProfileStoreV3Replication.GetDebugReplicationLookup(self : Replication)
	-- for debugging purposes, compile a replication lookup!

	local DebugReplicationLookup = {}
	local function addToDebugLookupByPathIndex(pathIndex : Types.PathIndex)
		if DebugReplicationLookup[pathIndex] then
			-- already added!
			return
		end

		local lookup = {}
		--- ! is used so this entry appears above all other. (it's sorted alphabetically in Roblox Studio Output)
		lookup[`! CDN (CodeDataName), The Full Path`] = PathArrangements:GetKeyByIndex(pathIndex)

		lookup[`IsPublic`] = IsPublic[pathIndex]
		lookup[`IsSelfPublic`] = IsSelfPublic[pathIndex]
		lookup[`IsPrivate`] = IsPrivate[pathIndex]
		lookup[`IsAPublicFolderValue`] = IsAPublicFolderValue[pathIndex]
		lookup[`SubscribedPlayers`] = SubscribedPlayers[pathIndex]

		DebugReplicationLookup[pathIndex] = lookup
	end

	local function collectPathIndexKeys(dict: {[Types.PathIndex]: any})
		for pathIndex: Types.PathIndex in dict do
			addToDebugLookupByPathIndex(pathIndex)
		end
	end

	collectPathIndexKeys(IsPublic)
	collectPathIndexKeys(IsSelfPublic)
	collectPathIndexKeys(IsPrivate)
	collectPathIndexKeys(IsAPublicFolderValue)
	collectPathIndexKeys(SubscribedPlayers)

	return DebugReplicationLookup
end











--- Core ---

-- Recursively traverse the ALREADY COFFEIFIED data and connect replication
function ProfileStoreV3Replication.ConnectReplication(
	self: Replication,
	coffeeObject: Types.Val | Types.Fol,
	pathPrefix: Types.CDNPath?,
	player: Player,
	previousPathIndex: Types.PathIndex?
)
	local currentPath: Types.CDNPath = pathPrefix or ""
	local UID: number = player.UserId
	local pathIndex: Types.PathIndex = PathArrangements[currentPath]



	-- inherit Public statuses from parent objects in the tree
	if IsSafeInteger(
		previousPathIndex -- makes sure previousPathIndex is an integer (not nil)
	) then
		local isPublic: true? = IsPublic[pathIndex]
		if isPublic ~= true then
			IsPublic[pathIndex] = IsPublic[previousPathIndex :: Types.PathIndex]
		end

		local isSelfPublic: true? = IsSelfPublic[pathIndex]
		if isSelfPublic ~= true then
			IsSelfPublic[pathIndex] = IsSelfPublic[previousPathIndex :: Types.PathIndex]
		end

		local isPrivate: true? = IsPrivate[pathIndex]
		if isPrivate ~= true then
			IsPrivate[pathIndex] = IsPrivate[previousPathIndex :: Types.PathIndex]
		end
	end





	if ValidateVal(coffeeObject) or ValidateUVal(coffeeObject) then
		local frequencyCounter = Counter.new():setInterval(1/8) -- up to 8 updates per second
		local waiting: boolean = false

		local replicate: DUVPublicStructureBase | DUVStructureBase = {
			UID = UID,
			pathIndex = pathIndex,
		}


		if IsAPublicFolderValue[pathIndex] then

			setmetatable(replicate, DataUpdatePublicFolderValueCallback)

			-- specific part only for IsAPublicFolderValue;
			-- Required to load leaderstats and other folder values for new players who join this server

			local publicFolderValues = PublicFolderValues[player]
			if not publicFolderValues then
				publicFolderValues = {}
				PublicFolderValues[player] = publicFolderValues
			end
			-- we could just link instead of creating a whole function; This should save memory.
			publicFolderValues[pathIndex] = coffeeObject

		else
			-- GetSubscribedPlayers(pathIndex) is only true for those caught by IsAPublicFolderValue[pathIndex] above
			(replicate :: DUVStructure)["subscribedPlayers"] = GetSubscribedPlayers(pathIndex)
			;(replicate :: DUVStructure)["player"] = player
			setmetatable(replicate, DataUpdateValueCallback)
		end

		-- we can't multiplex this, since it has no limits as to the run frequency
		-- => using __call metamethod would be bad.
		local function onChange(_, newVal: Types.SupportedTypesList)
			--print("Changed")
			if frequencyCounter.count > 0 then
				--awaitThrottle()
				if waiting then
					return
				end
				waiting = true

				repeat
					frequencyCounter.Changed:Wait()
				until frequencyCounter.count < 1

				waiting = false

				frequencyCounter()
				replicate((coffeeObject :: Types.Val).Value)
				--/E awaitThrottle()
				return
			end

			frequencyCounter();
			replicate(newVal)
		end

		onChange(nil, (coffeeObject :: Types.Val).Value);
		(coffeeObject :: Types.Val).Changed:Connect(onChange)

	elseif ValidateFol(coffeeObject) or ValidateUFol(coffeeObject) then

		local subscribedPlayers = GetSubscribedPlayers(pathIndex)

		-- No multiplexing here, because the rate can be more than max of {fixed amount} new/destroyed children

		local function NewChild(key: Types.TableIndex, value : Types.Val | Types.Fol)
			
			local childPath, childPathIndex = BuildChildPathAndChildPathIndex(currentPath, key)
			--local childPath = (currentPath ~= nil and currentPath ~= "") and `{currentPath}.{key}` or `{key}`

			self:ConnectReplication(value, childPath, player, pathIndex)

			--print(`Child Added to {currentPath}. Key={key} Value={value}`)

			-- do subscriptions for FolderChildAdded(Self); Example:
			-- FolderChildAdded:FireClient(subscribedPlayer, UID, PathArrangements[currentPath], key, PathArrangements[`{currentPath}.{key}`], 0 for Value OR 1 for Folder, Value of the Value if its not a Folder)

			--local childPathIndex = PathArrangements[childPath]

			for subscribedPlayer in subscribedPlayers do



				if subscribedPlayer.UserId == UID then

					if ValidateVal(value) or ValidateUVal(value) then
						FolderChildAddedSelf:FireClient(
							subscribedPlayer,
							pathIndex,
							key,
							childPathIndex,
							0,
							value.Value
						)
					else
						FolderChildAddedSelf:FireClient(
							subscribedPlayer,
							pathIndex,
							key,
							childPathIndex,
							1
						)
					end

				else

					if ValidateVal(value) or ValidateUVal(value :: any) then
						FolderChildAdded:FireClient(
							subscribedPlayer,
							UID,
							pathIndex,
							key,
							childPathIndex,
							0,
							value.Value
						)
					else
						FolderChildAdded:FireClient(
							subscribedPlayer,
							UID,
							pathIndex,
							key,
							childPathIndex,
							1
						)
					end

				end



			end
		end

		-- its a CoffeeFolder
		for key, value in (coffeeObject :: Types.Fol) do
			NewChild(key, value)
		end
		(coffeeObject :: Types.Fol).ChildAdded:Connect(NewChild)
		;(coffeeObject :: Types.Fol).ChildRemoved:Connect(function(key)
			-- do subscriptions for FolderChildRemoved(Self); Example:
			-- FolderChildRemoved:FireClient(subscribedPlayer, UID, PathArrangements[`{currentPath}.{key}`])
			
			local childPath, childPathIndex = BuildChildPathAndChildPathIndex(currentPath, key)

			--local childPath = (currentPath ~= nil and currentPath ~= "") and `{currentPath}.{key}` or `{key}`
			--local childPathIndex = PathArrangements[childPath]

			for subscribedPlayer in subscribedPlayers do

				if subscribedPlayer.UserId == UID then
					FolderChildRemovedSelf:FireClient(subscribedPlayer, childPathIndex)
				else
					FolderChildRemoved:FireClient(subscribedPlayer, UID, childPathIndex)
				end

			end
		end)
	end
end






function ScrapeChildrenAndSubscribe(
	coffeeFolder : Types.Fol,
	player : Player,
	ownerPlayer : Player
): {Types.ObjectInfo}
	local result: {Types.ObjectInfo} = {}
	
	-- it is expected you did NOT modify the CoffeeObjects module Source, which means all
	-- children of a CoffeeFolder are either CoffeeBaseValue or CoffeeFolder instances
	-- because of this, and to optimise this code, there is NO checks to prevent
	-- errors in case the CoffeeObjects module source was modified
	
	for key, childObject: Types.Val | Types.Fol in coffeeFolder:GetChildren() do
		
		local currentPath: Types.CDNPath = (childObject :: any):GetFullName()
		local pathIndex: Types.PathIndex = PathArrangements[currentPath]

		if not IsAuthorized(player, ownerPlayer, pathIndex) then
			continue -- just skip over this childObject; Reason: Unauthorized.
		end
		
		SubscribePlayerToPathIndex(player, pathIndex)

		if ValidateVal(childObject) or ValidateUVal(childObject) then
			--print("V", subscribeToObject)

			--result[key] = 
			table.insert(result, {
				k = (childObject :: Types.IVal)._key,
				t = 0, -- objectType,
				a = pathIndex,
				v = (childObject :: Types.Val).Value,
			})
			continue
		end
		--if ValidateFol(childObject) or ValidateUFol(childObject) then
		--print("F", subscribeToObject)

		--result[key] = 
		table.insert(result, {
			k = (childObject :: Types.IFol)._key,
			t = 1, -- objectType,
			a = pathIndex,
			c = ScrapeChildrenAndSubscribe(
				childObject :: Types.Fol,
				player,
				ownerPlayer
			),
		})
	end

	return result
end

-- Returns true if the operation was NOT successfull
function InsertObject(
	objectInfos: {Types.ObjectInfo},
	subscribeToObject: Types.Val | Types.Fol,
	currentPath: Types.CDNPath,
	isLast: boolean,
	player: Player,
	ownerPlayer: Player
): boolean
	local pathIndex = PathArrangements[currentPath]
	if not IsAuthorized(player, ownerPlayer, pathIndex) then
		return true -- not success.
	end

	if ValidateVal(subscribeToObject) or ValidateUVal(subscribeToObject) then
		--print("V", subscribeToObject)
		
		table.insert(objectInfos, {
			t = 0, -- objectType,
			v = (subscribeToObject :: Types.Val).Value,
			a = pathIndex,
		})
		
		SubscribePlayerToPathIndex(player, pathIndex)
		
		return false
		
	elseif ValidateFol(subscribeToObject) or ValidateUFol(subscribeToObject) then
		--print("F", subscribeToObject)

		local folderInfo = {
			--k = subscribeToObject._key,
			t = 1, -- objectType,
			a = pathIndex,
		}

		if isLast then
			folderInfo["c"] = ScrapeChildrenAndSubscribe(
				subscribeToObject :: Types.Fol,
				player,
				ownerPlayer
			)
		end

		table.insert(objectInfos, folderInfo :: Types.ObjectInfo)

		SubscribePlayerToPathIndex(player, pathIndex)
		
		return false
	end
	return true
end

--- /E Core ---

























--- Network ---

-- If client doesn't yet know which path is encoded by index, they send the index and receive an answer here
function GetPathArrangement(
	player : Player,
	index : Types.PathIndex
): (boolean, boolean | Types.CDNPath)
	if not IsSafeInteger(index) then
		return true, false
	end
	return true, PathArrangements:GetKeyByIndex(index)
end

function GetFolderReplicatedCDNsCallback(player : Player)
	return true, FolderReplicatedCDNs
end
-- load values of the FolderReplicatedCDNs
function LoadPublicFolderValuesCallback(player : Player, subjectPlayerUID : number)
	if not IsSafeInteger(subjectPlayerUID) then
		return true, {}
	end

	local subjectPlayer : Player? = Players:GetPlayerByUserId(subjectPlayerUID :: any) -- any is here to suppress an incorrect type definition of the param here expected to be `User`; This comment and `any` use shall be removed once Roblox patches this
	if not subjectPlayer then
		return true, {}
	end

	local valuesPerPath = PublicFolderValues[subjectPlayer]
	if not valuesPerPath then
		return true, {}
	end

	local result = {}
	for path, value in pairs(valuesPerPath) do
		result[path] = value.Value
	end

	return true, result
end

local function UnsubscribeCallback(player : Player, unsubscribePathArrangementIndex : Types.PathIndex)
	if not IsSafeInteger(unsubscribePathArrangementIndex) then
		return
	end

	-- We don't use GetSubscribedPlayers, because it would create a table for any
	-- given pathIndex if none exists yet; This would allow memory leaks if an exploiter
	-- spams this remote with a new number all the time.

	local subscribedPlayers = SubscribedPlayers[unsubscribePathArrangementIndex]
	if not subscribedPlayers then
		return
	end

	subscribedPlayers[player] = nil
end
















--- Wire the crucial network layer ---
GetPathArrangements:SetCooldown(0).OnServerInvoke = GetPathArrangement

GetFolderReplicatedCDNs.OnServerInvoke = GetFolderReplicatedCDNsCallback
LoadPublicFolderValues:SetCooldown(1).OnServerInvoke = LoadPublicFolderValuesCallback

Unsubscribe:SetCooldown(0):Connect(UnsubscribeCallback)


local IsNotInitialized: true? = true
-- Wires the crucial network layer
function ProfileStoreV3Replication.Init(
	self: Replication,
	Profiles: Types.Profiles,
	PlayersLoaded: Types.PlayersLoaded
): ()
	if IsNotInitialized ~= true then
		return
	end
	IsNotInitialized = nil -- let gc collect it now
	
	Subscribe.OnServerInvoke = function(
		player : Player,
		subscribeToPlayerUID : number,
		path : {[number]: Types.TableIndex},
		subscribeFromIndex : number -- optional - start subscribing from path[subscribeFromIndex]
	): (boolean, boolean | {Types.ObjectInfo})
		if not IsSafeInteger(subscribeFromIndex) then
			subscribeFromIndex = 1
		end
		print("RemoteReceived", player, subscribeToPlayerUID, path, subscribeFromIndex)
		if not (
			IsSafeInteger(subscribeToPlayerUID) and 
				type(path) == "table"-- and 
			--(type(requiredKey) == "string" or type(requiredKey) == "number")
			) then
			print("UID not a number OR path not a table")
			return true, false
		end



		-- go thru the path
		-- keep track based on subscribeFromIndex
		-- if its the last element of path - scrape it

		local subscribeToPlayer = Players:GetPlayerByUserId(subscribeToPlayerUID :: any) -- any is here to suppress an incorrect type definition of the param here expected to be `User`; This comment and `any` use shall be removed once Roblox patches this
		if not subscribeToPlayer then
			print("Player not in server")
			return true, false
		end

		local subscribeToPlayerData: Types.PlayerProfile? = Profiles[subscribeToPlayer]
		if not subscribeToPlayerData then
			return true, false
		end
		--print("subscribeToPlayerData", subscribeToPlayerData)
		--local subscribingToSelf = player.UserId == subscribeToPlayerUID

		if not PlayersLoaded[player] then
			repeat 
				task.wait()
			until PlayersLoaded[player] == true
		end
		if PlayersLoaded[player] == nil then
			print("Player left")
			return true, false
		end



		local objectInfos: {Types.ObjectInfo} = {}
		local subscribeToObject = subscribeToPlayerData.Data

		for i, key in ipairs(path) do
			--print("iterating", i, key)
			if not subscribeToObject[key] then
				--print(key, "not found")
				break --return true, objectInfos
			end

			local currentPath = table.concat(path, ".", 1, i)
			subscribeToObject = subscribeToObject[key]
			--print("iteration obj:", subscribeToObject)
			--print(CoffeeBaseValue.validateClass(subscribeToObject), CoffeeBaseValue.validateUnlinkedClass(subscribeToObject))

			if i <= subscribeFromIndex then
				--print(i, subscribeFromIndex, "skip")
				-- (traversing to the next object)
				continue
			end

			--local pathIndex : Types.PathIndex = PathArrangements[currentPath]
			
			if InsertObject(objectInfos, subscribeToObject, currentPath, i == #path, player, subscribeToPlayer) then
				break -- failed to insert
			end
		end

		--print("did not validate as an object")
		--print("subscribeToPlayerData before return", subscribeToPlayerData)
		return true, objectInfos
	end
end
--- /E Wire the crucial network layer ---
--- /E Network ---



--- Expose Some Helpers ---
function ProfileStoreV3Replication.GetSubscribedPlayers(self : Replication, ...)
	return GetSubscribedPlayers(...)
end
function ProfileStoreV3Replication.IsAuthorized(self : Replication, ...)
	return IsAuthorized(...)
end
--- /E Expose Some Helpers ---



--- Cleanup on Player leave ---
Players.PlayerRemoving:Connect(function(player: Player)
	for _, playerSet: Types.PlayerSet in SubscribedPlayers do
		playerSet[player] = nil
	end
end)
--- /E Cleanup on Player leave ---

return ProfileStoreV3Replication