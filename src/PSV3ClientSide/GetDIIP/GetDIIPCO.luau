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
local Players = game:GetService(`Players`)

local RS = game:GetService(`ReplicatedStorage`)
local Packages = RS:WaitForChild(`Packages`)

local CoffeeRemotes = require(Packages:WaitForChild(`CoffeeRemotesClient`))
local RemoteEvent, RemoteFunction, URemoteEvent = CoffeeRemotes:Unpack()

local REQUIRED_MODULE = require(script.Parent.Parent.CoffeeObjects)

local LemonSignal = REQUIRED_MODULE.LemonSignal
local GetPathMethod = REQUIRED_MODULE.GetPathMethod
local GetFullNameMethod = REQUIRED_MODULE.GetFullNameMethod
local IsArrayORTupleMethod = REQUIRED_MODULE.IsArrayORTupleMethod
local InsertMethod = REQUIRED_MODULE.InsertMethod
local GetChildrenMethod = REQUIRED_MODULE.GetChildrenMethod
local DestroyMethod = REQUIRED_MODULE.DestroyMethod
local ObjectAwaitMethod = REQUIRED_MODULE.ObjectAwaitMethod

local Context = REQUIRED_MODULE:CreateContext()
local Folder = Context._Folder
local CoffeeBaseValue = Context.CoffeeBaseValue
local CoffeeFolder = Context.CoffeeFolder

local GetDIIPCO = {
	CoffeeBaseValue = CoffeeBaseValue,
	CoffeeFolder = CoffeeFolder,
}




local Subscribe = RemoteFunction.new(`PSV3~Subscribe`)
local Unsubscribe = RemoteEvent.new(`PSV3~Unsubscribe`)
local DataUpdateValue = RemoteEvent.new(`PSV3~DataUpdateValue`)
local DataUpdateValueSelf = RemoteEvent.new(`PSV3~DataUpdateValueSelf`)
local FolderChildAdded = RemoteEvent.new(`PSV3~FolderChildAdded`)
local FolderChildAddedSelf = RemoteEvent.new(`PSV3~FolderChildAddedSelf`)
local FolderChildRemoved = RemoteEvent.new(`PSV3~FolderChildRemoved`)
local FolderChildRemovedSelf = RemoteEvent.new(`PSV3~FolderChildRemovedSelf`)

local player = Players.LocalPlayer :: Player
local selfUID = player.UserId
--- /E Service & Dependency & RemoteInstance Definitons ---


--- Type Definitions ---
--- Misc Types (Just for readability and linter suppression) ---
type DestroyMethod = (self: CoffeeBaseValue | CoffeeFolder) -> ()
type UID = number
type Validator = {
	validateClass: (v: any) -> boolean,
	validateUnlinkedClass: (v: any) -> boolean,
}
type ArrangementObjectPairs = {
	[ArrangementIndex]: 
		CoffeeBaseValueInternals<SupportedTypesList>
		| CoffeeFolderInternals<PrimitiveTable>
		| CoffeeBaseValue
		| CoffeeFolder,
}
--- Type Patch Addition ---
type CoffeeFolderPatch = {
	["UID"]: number, -- "UID" is the string literal key, not the UID type defined above
}
--- Re-export types ---
export type SupportedTypesList = REQUIRED_MODULE.SupportedTypesList 
export type TableIndex = REQUIRED_MODULE.TableIndex 
export type TableValue = REQUIRED_MODULE.TableValue 
export type PrimitiveTable = REQUIRED_MODULE.PrimitiveTable 
export type CoffeeFolder = CoffeeFolderPatch & REQUIRED_MODULE.CoffeeFolder
export type CoffeeFolderStrict<T> = CoffeeFolderPatch & REQUIRED_MODULE.CoffeeFolderStrict<T>
export type CoffeeFolderInternals<T> = CoffeeFolderPatch & REQUIRED_MODULE.CoffeeFolderInternals<T>
export type CoffeeBaseValue = REQUIRED_MODULE.CoffeeBaseValue 
export type CoffeeBaseValueStrict<T> = REQUIRED_MODULE.CoffeeBaseValueStrict<T>
export type CoffeeBaseValueInternals<T> = REQUIRED_MODULE.CoffeeBaseValueInternals<T>
--- /E Type Definitions ---









--- Wire Unsubscribe, DUV, FCA and FCR ---
local UIDtoArrangementObjectPairs: {[UID]: ArrangementObjectPairs} = {}

-- Create a single metatable to miltiplex one function for multiple Objects (Saves Memory)
--local CoffeeObjectReservedDestryoingCallback = {a=-1} -- default fallback for "a", the arrangementIndex, if something goes wrong
--function CoffeeObjectReservedDestryoingCallback:__call()
--	local arrangementIndex = self["a"]
--	Unsubscribe:FireServer(arrangementIndex)
--	if self["b"] then
--		self["b"][arrangementIndex] = nil
--	end
--end

local function objectLoaded(
	object : CoffeeBaseValueInternals<SupportedTypesList> | CoffeeFolderInternals<PrimitiveTable>,
	arrangementObjectPairs : ArrangementObjectPairs,
	arrangementIndex : number
)
	-- irrelevant old comment:
	-- path of a CoffeeBaseValue will be "" unless it's inside a CoffeeFolder: --table.concat(object:GetPath(), ".")
	arrangementObjectPairs[arrangementIndex] = object
	-- Might be useful for debugging later RunService:IsStudio()
	-- module:GetPathArrangements()[arrangementIndex] = table.concat(object:GetPath(), ".")
	
	object._Destroying:Connect(function()
		Unsubscribe:FireServer(arrangementIndex)
		arrangementObjectPairs[arrangementIndex] = nil
	end)

	--rawset(
	--	object,
	--	"___D",
	--	setmetatable(
	--		{
	--			a = arrangementIndex,
	--			b = arrangementObjectPairs,
	--		},
	--		CoffeeObjectReservedDestryoingCallback
	--	)
	--)
end



local function DUV(UID : number, pathIndex : number, newValue) -- DataUpdateValue
	--print("DUV", UID, pathIndex, newValue)
	local arrangementObjectPairs = UIDtoArrangementObjectPairs[UID]
	if not arrangementObjectPairs then
		return
	end

	local object = arrangementObjectPairs[pathIndex] :: CoffeeBaseValue?
	if not object then
		return
	end
	object.Value = newValue
end

DataUpdateValue.OnClientEvent:Connect(DUV)
DataUpdateValueSelf.OnClientEvent:Connect(function(...)
	DUV(selfUID, ...)
end)

local function FCA(
	UID : number,
	currentPathArrangement : number, -- same as pathIndex in DUV; Parent path
	key : number | string, -- Child's key as index for Parenting;
	childPathArrangement : number, -- same as pathIndex in DUV; Parent.key path
	typeHeader : number, -- header to indicate CoffeeObjectType; > 0 ~> Folder; Value ~> <= 0
	value : SupportedTypesList? -- only there if it's a CoffeeBaseValue (typeHeader <= 0)
)	-- FolderChildAdded
	--print("FCA", UID, currentPathArrangement, key, childPathArrangement, typeHeader, value)

	local arrangementObjectPairs = UIDtoArrangementObjectPairs[UID]
	if not arrangementObjectPairs then
		return
	end

	local object = arrangementObjectPairs[currentPathArrangement] :: CoffeeFolder?
	if not object then
		return
	end

	local childObject = typeHeader > 0 and CoffeeFolder.new(nil, UID) or CoffeeBaseValue.new(value :: SupportedTypesList)


	objectLoaded(childObject, arrangementObjectPairs, childPathArrangement)
	object[key] = childObject
end
FolderChildAdded.OnClientEvent:Connect(FCA)
FolderChildAddedSelf.OnClientEvent:Connect(function(...)
	FCA(selfUID, ...)
end)

local function FCR(UID : number, childPathArrangement : number)
	local arrangementObjectPairs = UIDtoArrangementObjectPairs[UID]
	if not arrangementObjectPairs then
		return
	end

	local object = arrangementObjectPairs[childPathArrangement] :: (CoffeeBaseValue | CoffeeFolder)?
	if type(object) ~= `table` then
		return
	end
	local destroy = object["Destroy"]
	if type(destroy) ~= `function` then
		return
	end
	
	(destroy :: DestroyMethod)(object) -- object:Destroy()
end
FolderChildRemoved.OnClientEvent:Connect(FCR)
FolderChildRemovedSelf.OnClientEvent:Connect(function(...)
	FCR(selfUID, ...)
end)

--- /E Wire Unsubscribe, DUV, FCA and FCR ---













--- Useful for Debug ---
type ArrangementIndex = number
type Path = string
export type PathArrangements = {
	[ArrangementIndex]: Path,
}

function GetDIIPCO:GetPathArrangements(): PathArrangements
	local pathArrangements = GetDIIPCO["PathArrangements"]
	if not pathArrangements then
		GetDIIPCO.PathArrangements = {}
	end
	return pathArrangements
end
--- /E Useful for Debug ---





--- Define Accelerator & Patch CoffeeFolder/it's metatable ---
local Accelerator = {}
export type Accelerator = typeof(Accelerator)

function Folder.__index(
	self: CoffeeFolder,
	key: any
)
	local value = rawget(self._data, key)
	if value then
		return value
	end

	--print("C Stack", key)
	--print("C Stack", self)
	--print("C Stack", self.UID)
	--print("C Stack", self:GetPath())
	return Accelerator.new(self.UID, self, self:GetPath(), {key})
end

--- Literally a copy of CoffeeFolder.new, except the lines marked as -- ADDITION

-- Creates a new CoffeeFolder instance, mimicking a Roblox Folder Instance.
-- @param data Optional initial table to populate the folder with.
-- @return A CoffeeFolder instance with ChildAdded, ChildRemoved, and tree-traversal methods.
function CoffeeFolder.new(
	data : ({} & PrimitiveTable)?,
	playerUID : number -- ADDITION
) : CoffeeFolder
	local self = setmetatable({}, Folder) :: CoffeeFolder
	rawset(self, "_data", {})
	rawset(self, "ChildAdded", LemonSignal.new())
	rawset(self, "ChildRemoved", LemonSignal.new())
	rawset(self, "Destroying", LemonSignal.new())
	rawset(self, "_Destroying", LemonSignal.new())
	rawset(self, "_IsArrayORTuple", IsArrayORTupleMethod)
	rawset(self, "Insert", InsertMethod)
	rawset(self, "GetPath", GetPathMethod)
	rawset(self, "GetFullName", GetFullNameMethod)
	rawset(self, "GetChildren", GetChildrenMethod)
	rawset(self, "Destroy", DestroyMethod)
	rawset(self, "Await", ObjectAwaitMethod)
	rawset(self, `UID`, playerUID) -- ADDITION

	if type(data) ~= "table" then
		return self
	end

	--print("Adding", data, "into a coffeefolder")
	for k, v in data do
		self[k] = v -- newindex will handle this
	end

	return self
end

-- Folder __newindex is patched to create folders via this .new api with uid too
-- Literally a copy of CoffeeFolder metatable __newindex except all CoffeeFolder.new
-- calls are done with {data} -> {data, UID} (UID argument added)
-- (And types are defined more explicitly because this script is strict, unlike original CoffeeObjects)
-- It is expected children are only made by this module itself - meining this change is pointless. It isn't intended
-- users of this module assign keys to Folders instead of accessing -> getting accelerator -> :Await()'ing.
-- This change is purely for safety and to ensure there's no need to debug this later for countless hours.
-- It is NOT to encourage such usage, but to keep it technically possible AND safe.

-- Handles the assignment of new children to the Folder.
-- Automatically wraps raw tables in CoffeeFolders and supported primitives in CoffeeBaseValues.
-- @param key The key/index for the new child.
-- @param newValue The value to store. If nil, the child is removed and destroyed.
function Folder.__newindex( -- ADDITION (change `:FnName(` -> `.FnName(self` to achieve explicit type definition)
	self: CoffeeFolder, -- ADDITION (explicit type definition)
	key : TableIndex,
	newValue : TableValue
)
	--print("new index inside", self)
	--print("kv:", key, newValue)
	local data = rawget(self, "_data") :: PrimitiveTable -- ADDITION (explicit type definition)

	local oldItem = rawget(data, key)

	if oldItem then
		if newValue == nil then
			rawset(data, key, nil)
			self.ChildRemoved:Fire(key)

			local destroy = oldItem["Destroy"] :: DestroyMethod -- ADDITION (explicit type definition)
			if destroy then
				destroy(
					oldItem -- self
				)
			end

			return -- same as return nil
		else
			local destroy = oldItem["Destroy"] :: DestroyMethod -- ADDITION (explicit type definition)
			if destroy then
				destroy(
					oldItem -- self
				)
			end
		end
	end



	local itemToStore

	if type(newValue) == "table" then
		if CoffeeBaseValue.validateClass(newValue) or CoffeeBaseValue.validateUnlinkedClass(newValue)
			or CoffeeFolder.validateClass(newValue) or CoffeeFolder.validateUnlinkedClass(newValue)	
		then
			--print("A CoffeeBaseValue OR CoffeeFolder")
			itemToStore = newValue -- already a CoffeeObject
		else
			--print("A table, not a CoffeeObject")
			itemToStore = CoffeeFolder.new(
				newValue,
				rawget(self, "UID") -- ADDITION
			)
		end
	else
		--print("Hopefully one of the Supported Types")
		itemToStore = CoffeeBaseValue.new(newValue)
	end

	rawset(itemToStore, "_parent", self)

	rawset(itemToStore, "_key", key)

	-- Listen for child self-destruction
	if itemToStore["_Destroying"] then
		itemToStore["_Destroying"]:Connect(function()
			local destroyedItem = rawget(data, key)

			if data and destroyedItem == itemToStore then
				rawset(data, key, nil)
				self.ChildRemoved:Fire(key)
			end
		end)
	end

	rawset(data, key, itemToStore)
	self.ChildAdded:Fire(key, itemToStore)
end

--- /E Define Accelerator & Patch CoffeeFolder/it's metatable ---














--- processChild implementation (to be used in AwaitMethod) ---
type objectInfo = {
	["k"]: TableIndex?, -- only there for children - the main (root) requested objectInfo do not contain this
	["t"]: number, -- type; >0 means a folder, <=0 means a value
	["a"]: number, -- arrangement index
	["v"]: SupportedTypesList?, -- only for values
	["c"]: {objectInfo}?, -- only for folders
}


function processChild(child : objectInfo, parent : CoffeeFolder, arrangementObjectPairs: ArrangementObjectPairs): CoffeeBaseValue | CoffeeFolder
	local object


	local isFolder = child["t"] > 0
	---[[
	local data = rawget(parent, "_data") :: PrimitiveTable
	local existing = rawget(data, child["k"] :: string)

	local validator: Validator = isFolder and CoffeeFolder or CoffeeBaseValue
	-- reconcile if expected type exists already
	if validator.validateClass(existing) or validator.validateUnlinkedClass(existing) then

		if isFolder then
			---CoffeeFolder
			-- reconcile if a CoffeeFolder exists already

			-- if it exists, evaluate all of it's entries recursively
			-- log all existing children 
			-- replace all children received via the update `for _, objectInfo in ipairs(child["c"]) do`
			-- as doing this, mark those children out of logged
			-- Destroy all children that exist in the log, but aren't present in current children; (everything that remains in the log)

			local existing : CoffeeFolder = existing

			local currentChildren = {}
			
			-- IMPORTANT: CHECK LATER WHETHER SERVER SENDS a placeholder `{}` for key `c`
			-- figure out whether the following check is necessary:
			local children = child["c"]
			
			if children then
			for _, objectInfo in ipairs(children --[=[child["c"]]=]) do
				currentChildren[objectInfo["k"]] = true
				processChild(objectInfo, existing, arrangementObjectPairs)
			end
			end

			for k, v in existing do
				if not currentChildren[k] then
					v:Destroy()
				end
			end

			return existing
		end

		---CoffeeBaseValue
		-- just change the .Value if a CoffeeBaseValue exists already
		
		-- types are here to supress linter, child["v"] is guaranteed
		-- for CoffeeBaseValues by server schema of sending objectInfos
		(existing :: CoffeeBaseValue).Value = child["v"] :: SupportedTypesList

		return existing
	end
	--]]

	if isFolder then -- a folder
		
		object = CoffeeFolder.new(nil, rawget(parent, "UID"))
		
		-- IMPORTANT: CHECK LATER WHETHER SERVER SENDS a placeholder `{}` for key `c`
		-- figure out whether the following check is necessary:
		local children = child["c"]
		
		if children then
		for _, objectInfo in ipairs(children --[=[child["c"]]=]) do
			processChild(objectInfo, object, arrangementObjectPairs)
		end
		end
	else
		object = CoffeeBaseValue.new(
			child["v"] :: SupportedTypesList -- Guaranteed because it's an objectInfo for the CoffeeBaseValue
		)
	end



	local pathIndex = child["a"]
	objectLoaded(object, arrangementObjectPairs, pathIndex)
	-- child["k"] is guaranteed; A: server guarantees it for children; B: AwaitMethod ensures it exists;
	parent[child["k"]] = object

	return object

end
--- /E processChild implementation (to be used in AwaitMethod) ---


--- Accelerator Class and it's AwaitMethod ---
local function AwaitMethod(self: Accelerator): (CoffeeBaseValue | CoffeeFolder)?
	local UID = self.root.UID
	local completePath = self.rootPath
	local subscribeStartIndex = #completePath

	local loadPath = self.path

	for _, key in ipairs(loadPath) do
		table.insert(completePath, key)
	end

	--print("Before Invoke self:", self)
	--print("Sending completePath to Invoke adress:", tostring(completePath))
	local success, objectInfos = Subscribe:InvokeServer(UID, completePath, subscribeStartIndex)
	--print(success, objectInfos)
	if not success then
		repeat
			task.wait()
			success, objectInfos = Subscribe:InvokeServer(UID, completePath, subscribeStartIndex)
			--print("Retrying:", success, objectInfos)
		until success
	end

	--print("success, firstObject:", success, objectInfos)

	if type(objectInfos) ~= "table" then
		return nil
	end

	local latestObject = self.root

	local arrangementObjectPairs = UIDtoArrangementObjectPairs[UID]
	if not arrangementObjectPairs then
		UIDtoArrangementObjectPairs[UID] = {}
		arrangementObjectPairs = UIDtoArrangementObjectPairs[UID]
	end

	--warn("loadPath =", loadPath, "objectInfos =", objectInfos)

	-- LOOP THROUGH THE PATH RETURNED BY SERVER
	for i, key in ipairs(loadPath) do
		local objectInfo = (objectInfos :: {objectInfo})[i]
		if not objectInfo then
			break
		end

		-- Ensure the objectInfo knows its key (since server might not send 'k' for path entries)
		objectInfo["k"] = key 

		-- USE THE SMART processChild FOR EVERY STEP
		-- This handles: 
		-- 1. Reconciling if folder exists
		-- 2. Updating if value exists
		-- 3. Creating only if missing
		latestObject = processChild(objectInfo, latestObject, arrangementObjectPairs)

		-- Move deeper into the tree
		-- local object = processChild(objectInfo, latestObject, arrangementObjectPairs)
		-- latestObject = object

		-- If we just hit a Value, we can't go any deeper
		if objectInfo["t"] <= 0 then
			break
		end
	end

	return latestObject
end

function Accelerator.__index(self: Accelerator, key: any)
	--[[ base idea:
	-- eat and accelerate all keys
	table.insert(self.path, key)
	
	return self
	--]]

	-- do this (table.clone) to avoid mutations
	-- (
	-- mutation example (happens if table.clone() is not used):
	--		local a = root.key1
	--		local b = a.key2:Await()
	-- now a = Accelerator with {key1, key2}
	-- )
	-- table.clone protects against that.

	local clonedKeys = table.clone(self.path)
	table.insert(clonedKeys, key)

	return Accelerator.new(self.UID, self.root, self.rootPath, clonedKeys)
end

function Accelerator.new(
	UID: UID,
	folder: CoffeeFolder,
	path: {
		[number]: TableIndex,
	},
	keys : {
		[number]: TableIndex,
	}
): Accelerator
	--print("New accel:", UID, folder, path, keys, "\n\t", CoffeeFolder.validateUnlinkedClass(folder))
	local self = setmetatable({}, Accelerator) :: Accelerator

	self.UID = UID
	self.root = folder
	self.rootPath = path -- the already loaded path, from root to folder
	self.path = keys -- all of the eaten keys accelerate here
	self.Await = AwaitMethod

	return self
end

--- /E Accelerator Class and it's AwaitMethod ---



return table.freeze(GetDIIPCO)