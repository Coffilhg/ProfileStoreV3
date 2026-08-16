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
--- Service & Dependency & RemoteInstance Definitons ---
local SSS = game:GetService(`ServerScriptService`)
local RS = game:GetService(`ReplicatedStorage`)

local SPackages = SSS.ServerPackages
local Packages = RS.Packages

local CoffeeRemotes = require(SPackages.CoffeeRemotesServer)
local CoffeeObjects = require(Packages.CoffeeObjects)
local Counter = require(Packages.Counter)
local Arrangement = require(Packages.Arrangement)
local Types = require(script.Parent.Types)
local IsSafeInteger = require(script.Parent.IsSafeInteger)

-- CoffeeRemotes
local RemoteEvent, RemoteFunction, URemoteEvent = CoffeeRemotes:Unpack()
-- CoffeeObjects
local ValNew = CoffeeObjects.CoffeeBaseValue.new
local ValidateVal = CoffeeObjects.CoffeeBaseValue.validateClass
local ValidateUVal = CoffeeObjects.CoffeeBaseValue.validateUnlinkedClass
local FolNew = CoffeeObjects.CoffeeFolder.new
local ValidateFol = CoffeeObjects.CoffeeFolder.validateClass
local ValidateUFol = CoffeeObjects.CoffeeFolder.validateUnlinkedClass
-- Arrangements & Subscriptions
local PathArrangements = Arrangement.new()
local SubscribedPlayers: Types.SubscribedPlayers = {}
-- Root
local Root: CoffeeFolder?
local function WipeRoot()
	Root = nil
end
local function IsRootNonexistent(): boolean
	return not ( Root and (ValidateFol(Root) or ValidateUFol(Root)) )
end



-- SVCS as a sub-prefix, because it's an extension. PSV3 works fine without this module.
local DataUpdateValueGlobal = RemoteEvent.new(`PSV3~SVCS~DataUpdateValueGlobal`)
local FolderChildAddedGlobal = RemoteEvent.new(`PSV3~SVCS~FolderChildAddedGlobal`)
local FolderChildRemovedGlobal = RemoteEvent.new(`PSV3~SVCS~FolderChildRemovedGlobal`)

local GlobalUnsubscribe = RemoteEvent.new(`PSV3~SVCS~GlobalUnsubscribe`)
local GlobalSubscribe = RemoteFunction.new(`PSV3~SVCS~GlobalSubscribe`)
--- /E Service & Dependency & RemoteInstance Definitons ---









--- Type Definitions ---
--- Re-export types ---
export type SupportedTypesList = CoffeeObjects.SupportedTypesList 
export type TableIndex = CoffeeObjects.TableIndex 
export type TableValue = CoffeeObjects.TableValue 
export type PrimitiveTable = CoffeeObjects.PrimitiveTable 
export type CoffeeFolder = CoffeeObjects.CoffeeFolder
export type CoffeeFolderStrict<T> = CoffeeObjects.CoffeeFolderStrict<T>
export type CoffeeFolderInternals<T> = CoffeeObjects.CoffeeFolderInternals<T>
export type CoffeeBaseValue = CoffeeObjects.CoffeeBaseValue 
export type CoffeeBaseValueStrict<T> = CoffeeObjects.CoffeeBaseValueStrict<T>
export type CoffeeBaseValueInternals<T> = CoffeeObjects.CoffeeBaseValueInternals<T>
--- /E Type Definitions ---



















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

local function SubscribePlayerToPathIndex(player: Player, pathIndex: Types.PathIndex)
	local subscribedPlayers = GetSubscribedPlayers(pathIndex)
	subscribedPlayers[player] = true
end

--- /E Helpers ---













--- Multiplexing to save memory ---
-- Create a single metatable to multiplex one function for multiple Objects (Saves Memory)
type DUVPublicStructureBase = { -- DUV -> Data Update: Value
	subscribedPlayers: Types.PlayerSet,
	pathIndex: Types.PathIndex,
}
type DUVPublicStructure = setmetatable<DUVPublicStructureBase, {
	__call: (self: DUVPublicStructure, v: Types.SupportedTypesList) -> (),
}>
local DataUpdateValueCallback = {}
function DataUpdateValueCallback.__call(self: DUVPublicStructure, v: Types.SupportedTypesList)
	for subscribedPlayer in self.subscribedPlayers do
		DataUpdateValueGlobal:FireClient(subscribedPlayer, self.pathIndex, v)
	end
end
--- /E Multiplexing to save memory ---













--- Core ---

-- Recursively traverse the ALREADY COFFEIFIED data
local function ConnectReplication(
	coffeeObject : CoffeeObjects.CoffeeBaseValue | CoffeeObjects.CoffeeFolder,
	pathPrefix: Types.CDNPath?
)
	local currentPath: Types.CDNPath = pathPrefix or ""
	local pathIndex: Types.PathIndex = PathArrangements[currentPath]
	
	local subscribedPlayers: Types.PlayerSet = GetSubscribedPlayers(pathIndex)
	
	if ValidateVal(coffeeObject) or ValidateUVal(coffeeObject) then
		local frequencyCounter = Counter.new():setInterval(1/8) -- up to 8 updates per second
		local waiting: boolean = false

		local replicate: DUVPublicStructure = setmetatable(
			{
				pathIndex = pathIndex,
				subscribedPlayers = subscribedPlayers,
			},
			DataUpdateValueCallback
		)

		-- we can't multiplex this, since it has no limits as to the run frequency
		-- => using __call metamethod would be bad.
		local function onChange(oldVal, newVal)
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
				replicate(coffeeObject.Value)
				--/E awaitThrottle()
				return
			end

			frequencyCounter()
			replicate(newVal)
		end

		onChange(nil, coffeeObject.Value)
		coffeeObject.Changed:Connect(onChange)

	elseif ValidateFol(coffeeObject) or ValidateUFol(coffeeObject) then

		local function NewChild(key: Types.TableIndex, value : Types.Val | Types.Fol)

			--local childPath = (currentPath ~= nil and currentPath ~= "") and `{currentPath}.{key}` or `{key}`
			local childPath, childPathIndex = BuildChildPathAndChildPathIndex(currentPath, key)

			ConnectReplication(value, childPath)

			--print(`Child Added to {currentPath}. Key={key} Value={value}`)

			-- do subscriptions for FolderChildAdded(Self); Example:
			-- FolderChildAdded:FireClient(subscribedPlayer, UID, PathArrangements[currentPath], key, PathArrangements[`{currentPath}.{key}`], 0 for Value OR 1 for Folder, Value of the Value if its not a Folder)

			for subscribedPlayer in subscribedPlayers do



				if ValidateVal(value) or ValidateUVal(value) then
					FolderChildAddedGlobal:FireClient(
						subscribedPlayer,
						pathIndex,
						key,
						childPathIndex,
						0,
						value.Value
					)
				else
					FolderChildAddedGlobal:FireClient(
						subscribedPlayer,
						pathIndex,
						key,
						childPathIndex,
						1
					)
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

			--local childPath = (currentPath ~= nil and currentPath ~= "") and `{currentPath}.{key}` or `{key}`
			
			local childPath, childPathIndex = BuildChildPathAndChildPathIndex(currentPath, key)

			for subscribedPlayer in subscribedPlayers do
				FolderChildRemovedGlobal:FireClient(subscribedPlayer, childPathIndex)
			end
		end)
	end
end






local function ScrapeChildrenAndSubscribe(
	coffeeFolder : CoffeeObjects.CoffeeFolder,
	player : Player
): {Types.ObjectInfo}
	local result: {Types.ObjectInfo} = {}
	
	-- it is expected you did NOT modify the CoffeeObjects, which means all
	-- children of a CoffeeFolder are either CoffeeBaseValue or CoffeeFolder instances
	-- because of this, and to optimise this code, there is NO checks to prevent
	-- errors in case the CoffeeObjects was modified

	for key, childObject: Types.Val | Types.Fol in coffeeFolder:GetChildren() do
		
		local currentPath: Types.CDNPath = (childObject :: any):GetFullName()
		local pathIndex: Types.PathIndex = PathArrangements[currentPath]
		
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
		
		--if CoffeeFolder.validateClass(childObject) or CoffeeFolder.validateUnlinkedClass(childObject) then
		--print("F", subscribeToObject)

		--result[key] = 
		table.insert(result, {
			k = (childObject :: Types.IFol)._key,
			t = 1, -- objectType,
			a = pathIndex,
			c = ScrapeChildrenAndSubscribe(
				childObject :: Types.Fol,
				player
			)
		})
	end

	return result
end

-- Returns true if the operation was NOT successfull
local function InsertObject(
	objectInfos: {Types.ObjectInfo},
	subscribeToObject,
	currentPath: Types.CDNPath,
	isLast: boolean,
	player: Player
): boolean
	local pathIndex = PathArrangements[currentPath]
	
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
				player
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

GlobalSubscribe.OnServerInvoke = function(
	player : Player,
	path : {[number]: Types.TableIndex},
	subscribeFromIndex : number  -- optional - start subscribing from path[subscribeFromIndex]
): (boolean, boolean | {Types.ObjectInfo})
	if not IsSafeInteger(subscribeFromIndex) then
		subscribeFromIndex = 1
	end
	--print("RemoteReceived", player, path, subscribeFromIndex)
	if type(path) ~= "table" then
		print("path not a table")
		return true, false
	end
	
	
	
	if IsRootNonexistent() then
		print("root not initialized or destroyed")
		-- you could return false, false instead
		-- the client would then :Await
		-- indefinitely, because you're returning false
		-- as the success status, which, usually means
		-- that the call has been throttled by the cooldown
		return true, false
	end



	local objectInfos: {Types.ObjectInfo} = {}
	local subscribeToObject = Root :: Types.Fol

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
			continue
		end

		if InsertObject(objectInfos, subscribeToObject, currentPath, i == #path, player) then
			break -- failed to insert
		end
	end

	return true, objectInfos
end
GlobalUnsubscribe:SetCooldown(0).OnServerEvent:Connect(UnsubscribeCallback)









-- SVSS -> Server Values Server Side
local SVSS = {}

-- Get the root CoffeeFolder for server values. Creates a new one if it was destroyed (or not initialized).
function SVSS.GetRoot(self: SVSS): CoffeeFolder
	if IsRootNonexistent() then
		Root = FolNew()
		ConnectReplication(Root :: CoffeeFolder, "")
		;(Root :: CoffeeFolderInternals<PrimitiveTable>)._Destroying:Connect(WipeRoot)
	end

	return Root :: CoffeeFolder
end

table.freeze(SVSS)
export type SVSS = typeof(SVSS)

return SVSS