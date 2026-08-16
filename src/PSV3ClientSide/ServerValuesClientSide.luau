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
local RS = game:GetService(`ReplicatedStorage`)
local Packages = RS:WaitForChild(`Packages`)

local CoffeeRemotes = require(Packages:WaitForChild(`CoffeeRemotesClient`))
local RemoteEvent, RemoteFunction, URemoteEvent = CoffeeRemotes:Unpack()

local REQUIRED_MODULE = require(script.Parent.CoffeeObjects)

local Context = REQUIRED_MODULE:CreateContext()
local Folder = Context._Folder
local CoffeeBaseValue = Context.CoffeeBaseValue
local CoffeeFolder = Context.CoffeeFolder



-- SVCS as a sub-prefix, because it's an extension. PSV3 works fine without this module.
local DataUpdateValueGlobal = RemoteEvent.new(`PSV3~SVCS~DataUpdateValueGlobal`)
local FolderChildAddedGlobal = RemoteEvent.new(`PSV3~SVCS~FolderChildAddedGlobal`)
local FolderChildRemovedGlobal = RemoteEvent.new(`PSV3~SVCS~FolderChildRemovedGlobal`)

local GlobalUnsubscribe = RemoteEvent.new(`PSV3~SVCS~GlobalUnsubscribe`)
local GlobalSubscribe = RemoteFunction.new(`PSV3~SVCS~GlobalSubscribe`)
--- /E Service & Dependency & RemoteInstance Definitons ---























--- Type Definitions ---
--- Misc Types (Just for readability and linter suppression) ---
type DestroyMethod = (self: CoffeeBaseValue | CoffeeFolder) -> ()
type Validator = {
	validateClass: (v: any) -> boolean,
	validateUnlinkedClass: (v: any) -> boolean,
}
type ArrangementIndex = number
type ArrangementObjectPairs = {
	[ArrangementIndex]: 
		CoffeeBaseValueInternals<SupportedTypesList>
	| CoffeeFolderInternals<PrimitiveTable>
	| CoffeeBaseValue
	| CoffeeFolder,
}
--- Re-export types ---
export type SupportedTypesList = REQUIRED_MODULE.SupportedTypesList 
export type TableIndex = REQUIRED_MODULE.TableIndex 
export type TableValue = REQUIRED_MODULE.TableValue 
export type PrimitiveTable = REQUIRED_MODULE.PrimitiveTable 
export type CoffeeFolder = REQUIRED_MODULE.CoffeeFolder
export type CoffeeFolderStrict<T> = REQUIRED_MODULE.CoffeeFolderStrict<T>
export type CoffeeFolderInternals<T> = REQUIRED_MODULE.CoffeeFolderInternals<T>
export type CoffeeBaseValue = REQUIRED_MODULE.CoffeeBaseValue 
export type CoffeeBaseValueStrict<T> = REQUIRED_MODULE.CoffeeBaseValueStrict<T>
export type CoffeeBaseValueInternals<T> = REQUIRED_MODULE.CoffeeBaseValueInternals<T>
--- /E Type Definitions ---













--- Wire Unsubscribe, DUV, FCA and FCR ---
local ArrangementObjectPairs: ArrangementObjectPairs = {}

-- Create a single metatable to miltiplex one function for multiple Objects (Saves Memory)
--local CoffeeObjectReservedDestryoingCallback = {a=-1} -- default fallback for "a", the arrangementIndex, if something goes wrong
--function CoffeeObjectReservedDestryoingCallback:__call()
--	local arrangementIndex = self["a"]
--	GlobalUnsubscribe:FireServer(arrangementIndex)
--	ArrangementObjectPairs[arrangementIndex] = nil
--end

local function objectLoaded(
	object : CoffeeBaseValueInternals<SupportedTypesList> | CoffeeFolderInternals<PrimitiveTable>,
	arrangementIndex : number
)
	-- irrelevant old comment:
	-- path of a CoffeeBaseValue will be "" unless it's inside a CoffeeFolder: --table.concat(object:GetPath(), ".")
	ArrangementObjectPairs[arrangementIndex] = object
	
	object._Destroying:Connect(function()
		GlobalUnsubscribe:FireServer(arrangementIndex)
		ArrangementObjectPairs[arrangementIndex] = nil
	end)

	--rawset(
	--	object,
	--	"___D",
	--	setmetatable(
	--		{
	--			a = arrangementIndex,
	--		},
	--		CoffeeObjectReservedDestryoingCallback
	--	)
	--)
end



local function DUV(pathIndex : number, newValue) -- DataUpdateValue
	--print("[SVCS] DUV", pathIndex, newValue)

	local object = ArrangementObjectPairs[pathIndex] :: CoffeeBaseValue?
	if not object then
		return
	end
	object.Value = newValue
end

DataUpdateValueGlobal.OnClientEvent:Connect(DUV)

local function FCA(
	currentPathArrangement : number, -- same as pathIndex in DUV; Parent path
	key : number | string, -- Child's key as index for Parenting;
	childPathArrangement : number, -- same as pathIndex in DUV; Parent.key path
	typeHeader : number, -- header to indicate CoffeeObjectType; > 0 ~> Folder; Value ~> <= 0
	value : SupportedTypesList? -- only there if it's a CoffeeBaseValue (typeHeader <= 0)
)	-- FolderChildAdded
	--print("FCA", UID, currentPathArrangement, key, childPathArrangement, typeHeader, value)

	local object = ArrangementObjectPairs[currentPathArrangement] :: CoffeeFolder?
	if not object then
		return
	end

	local childObject = typeHeader > 0 and CoffeeFolder.new() or CoffeeBaseValue.new(value :: SupportedTypesList)


	objectLoaded(childObject, childPathArrangement)
	object[key] = childObject
end
FolderChildAddedGlobal.OnClientEvent:Connect(FCA)

local function FCR(childPathArrangement : number)

	local object = ArrangementObjectPairs[childPathArrangement] :: (CoffeeBaseValue | CoffeeFolder)?
	if type(object) ~= `table` then
		return
	end
	local destroy = object["Destroy"]
	if type(destroy) ~= `function` then
		return
	end

	(destroy :: DestroyMethod)(object) -- object:Destroy()
end
FolderChildRemovedGlobal.OnClientEvent:Connect(FCR)

--- /E Wire Unsubscribe, DUV, FCA and FCR ---






























































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
	return Accelerator.new(self, self:GetPath(), {key})
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


function processChild(child : objectInfo, parent : CoffeeFolder): CoffeeBaseValue | CoffeeFolder
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
				processChild(objectInfo, existing)
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

		object = CoffeeFolder.new(nil)

		-- IMPORTANT: CHECK LATER WHETHER SERVER SENDS a placeholder `{}` for key `c`
		-- figure out whether the following check is necessary:
		local children = child["c"]
		
		if children then
		for _, objectInfo in ipairs(children --[=[child["c"]]=]) do
			processChild(objectInfo, object)
		end
		end
	else
		object = CoffeeBaseValue.new(
			child["v"] :: SupportedTypesList -- Guaranteed because it's an objectInfo for the CoffeeBaseValue
		)
	end



	local pathIndex = child["a"]
	objectLoaded(object, pathIndex)
	-- child["k"] is guaranteed; A: server guarantees it for children; B: AwaitMethod ensures it exists;
	parent[child["k"] :: TableIndex] = object

	return object

end
--- /E processChild implementation (to be used in AwaitMethod) ---


--- Accelerator Class and it's AwaitMethod ---
local function AwaitMethod(self: Accelerator): (CoffeeBaseValue | CoffeeFolder)?
	local completePath = self.rootPath
	local subscribeStartIndex = #completePath

	local loadPath = self.path

	for _, key in ipairs(loadPath) do
		table.insert(completePath, key)
	end

	--print("Before Invoke self:", self)
	--print("Sending completePath to Invoke adress:", tostring(completePath))
	local success, objectInfos = GlobalSubscribe:InvokeServer(completePath, subscribeStartIndex)
	--print(success, objectInfos)
	if not success then
		repeat
			task.wait()
			success, objectInfos = GlobalSubscribe:InvokeServer(completePath, subscribeStartIndex)
			--print("Retrying:", success, objectInfos)
		until success
	end

	--print("success, firstObject:", success, objectInfos)

	if type(objectInfos) ~= "table" then
		return nil
	end

	local latestObject = self.root

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
		latestObject = processChild(objectInfo, latestObject)

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

	return Accelerator.new(self.root, self.rootPath, clonedKeys)
end

function Accelerator.new(
	folder: CoffeeFolder,
	path: {
		[number]: TableIndex,
	},
	keys : {
		[number]: TableIndex,
	}
)
	--print("New accel:", folder, path, keys, "\n\t", CoffeeFolder.validateUnlinkedClass(folder))
	local self = setmetatable({}, Accelerator) :: Accelerator
	
	self.root = folder
	self.rootPath = path -- the already loaded path, from root to folder
	self.path = keys -- all of the eaten keys accelerate here
	self.Await = AwaitMethod
	
	return self
end

--- /E Accelerator Class and it's AwaitMethod ---

local Root: CoffeeFolder?
local function WipeRoot()
	Root = nil
end

-- SVCS -> Server Values Client Side
local SVCS = {}

-- Get the root CoffeeFolder for server values. Creates a new one if it was destroyed (or not initialized).
function SVCS.GetRoot(self: SVCS): CoffeeFolder
	if not (
		Root and (CoffeeFolder.validateClass(Root) or CoffeeFolder.validateUnlinkedClass(Root))
		)
	then
		Root = CoffeeFolder.new();
		(Root :: CoffeeFolderInternals<PrimitiveTable>)._Destroying:Connect(WipeRoot)
	end
	
	return Root :: CoffeeFolder
end

table.freeze(SVCS)
export type SVCS = typeof(SVCS)

return SVCS