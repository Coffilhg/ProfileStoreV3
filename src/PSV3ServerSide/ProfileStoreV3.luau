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

local Players = game:GetService(`Players`)
local SSS = game:GetService(`ServerScriptService`)
local RS = game:GetService(`ReplicatedStorage`)

local SPackages = SSS.ServerPackages
local Packages = RS.Packages

local ProfileStoreV2 = require(SPackages.ProfileStoreV2)
local CoffeeParser = require(Packages.CoffeeParser)
local CoffeeObjects = require(Packages.CoffeeObjects)
local Types = require(script.Parent.Types)

local Prefix: string = `[ProfileStoreV3] `



local ValNew = CoffeeObjects.CoffeeBaseValue.new
local ValidateVal = CoffeeObjects.CoffeeBaseValue.validateClass
local ValidateUVal = CoffeeObjects.CoffeeBaseValue.validateUnlinkedClass
local FolNew = CoffeeObjects.CoffeeFolder.new
local ValidateFol = CoffeeObjects.CoffeeFolder.validateClass
local ValidateUFol = CoffeeObjects.CoffeeFolder.validateUnlinkedClass

-- Decodes StateB (Datastore) -> StateC (Roblox)
local Decode = CoffeeParser.Decode
-- Encodes StateC (Roblox) -> StateB (Datastore)
local Encode = CoffeeParser.Encode

--- Main Object Types
type Val = CoffeeObjects.CoffeeBaseValue
type SVal<T> = CoffeeObjects.CoffeeBaseValueStrict<T>
type Fol = CoffeeObjects.CoffeeFolder
type SFol<T> = CoffeeObjects.CoffeeFolderStrict<T>
--- Types That work with these objects
type SupportedTypesList = CoffeeObjects.SupportedTypesList -- SVal<T=SupportedTypesList>
type TableIndex = CoffeeObjects.TableIndex -- everything that can be used as a key (index) inside a Fol
type TableValue = CoffeeObjects.TableValue -- everything that can be used as a value inside a Fol
type PrimitiveTable = CoffeeObjects.PrimitiveTable -- SFol<T=PrimitiveTable>
type RecursionDetails = {
	Path: {TableIndex},
	Result: {any},
}

local function CopyBuffer(original: buffer)
	local copy: buffer = buffer.create(buffer.len(original))
	
	buffer.copy(copy, 0, original)
	
	return copy
end
--- State{A | B | C} Descriptions as defined in https://github.com/Coffilhg/ProfileStoreV2

-- State A / Runtime
-- The type of data/data structure that is used at Runtime, the only limit is your implementation.
export type StateA = Types.ProfileData --| CoffeeObjects.CoffeeFolder
-- State B / Datastore
-- The type of data/data structure that lives in the Datastore, limited to JSON Acceptable types
-- (JSONAcceptable in terms of Roblox Studio' Datastores and HttpService)
export type StateB = CoffeeParser.PrimitiveBasicTable | Types.JSONAcceptable -- both types are bascally same
-- State C / Roblox
--[[
	The type of data/data structure that should be returned by Custom DeepCopy callback,
	it is highly recommended, that if your State A uses metatables, you limit it to only
	return clean Roblox tables containing only the actual Data, without metadata or metatables;

	Otherwise the memory used for storing and Decoding might get messy - up to you.

	This is a type of data/data structure, that isn't limited to JSON Acceptable types only,
	but is defined by you.

	Note: DeepCopy callback might receive both State A and State C as input,
	but must always output State C

	Note 2: If your use case is only making sure the data transitions from State B to State A
	on Load and State A to State B on Upload, you really don't have any differences between
	State C and State A; Thus meaning DeepCopy, Reconcile and RuntimeWrapper callbacks are
	useless for you.
--]]
-- This should have been CoffeeParser.RuntimeBasicTable
-- but then the only ones producing StateA would be Reconcile and RuntimeWrapper
-- So instead, we make Encode expect StateA and Decode output StateA
-- That also means LastSavedData is also Coffeified! Oh nah
-- this is a bad idea because we are unable to catch every LastSavedData
-- overwrite and thus can't :Destroy() it's root CoffeeFolder!
-- Ditch Types.ProfileData | CoffeeObjects.CoffeeFolder, and use:
-- CoffeeParser.RuntimeBasicTable
export type StateC = CoffeeParser.RuntimeBasicTable









-- value might be any, although usually will be CoffeeBaseValue (Val)
-- this is built to gracefully handle anything, althought if you're using
-- PSV3 as intended, the value here is a guaranteed CoffeeBaseValue (Val)
-- Types for key and value are defined from (Most expected) -> (Least expected)
local function CopyLeaf(
	copy: StateC,
	key: TableIndex | any,
	value: Val | SupportedTypesList | PrimitiveTable | any,
	deepCopy
)
	local valueType = type(value)
	
	if valueType == `table` then
		if not ValidateVal(value) then
			-- table
			copy[key] = deepCopy(value)
			return
		end
		-- CoffeeBaseValue
		value = rawget(value :: any, `_Value`)
		valueType = type(value)
	end
	
	if valueType == `buffer` then
		copy[key] = CopyBuffer(value)
		return
	end

	copy[key] = value -- SupportedTypesList (likely), but not a buffer
end

-- original - table to copy
-- the table will be copied without metatables and CoffeeObjects
-- recursionDetails - leave blank or nil (it's only for debug purposes)
local function DeepCopy(original: StateA | StateC, recursionDetails: RecursionDetails?): StateC
	local copy: StateC = {}
	local originalType = type(original)
	
	-- single value; Not even a CoffeeObject bruh
	--if originalType ~= `table` then
	--	if originalType == `buffer` then
	--		return CopyBuffer(original :: buffer | any) :: any
	--	end
		
	--	return original :: any
	--end
	
	if ValidateFol(original) then
		for key: TableIndex, value: TableValue in original :: Fol do
			if ValidateFol(value) then
				copy[key] = DeepCopy(value :: Fol)
				continue
			end
			
			CopyLeaf(
				copy,
				key,
				value :: Val | SupportedTypesList | PrimitiveTable,
				DeepCopy
			)
		end
		
		return copy
	end
	
	-- single value CoffeeObject, like, why?? Is this all you've got to be stored?
	-- no, wait, CoffeeParser does NOT handle single values explicitly.
	
	-- not a CoffeeFolder, gotta be a table!
	-- the any type definitions here really mean it, it might be anything!
	-- although (any) only happens if you were bypassing the CoffeeObjects
	for key: TableIndex | any, value: any in original :: StateC | {[any]: any} do
		-- in case it is actually a CoffeeBaseValue or an Unlinked CoffeeFolder (although it is NOT expected!!!)
		-- (PS: If all your Profile.Data is a single CoffeeBaseValue, this will happen; But who even stores a single value???)
		-- ok, fine, added a check on top to copy a SINGLE value; Nevermind...
		if key == "_parent" then
			continue
		end

		if ValidateFol(value) then
			copy[key] = DeepCopy(value :: Fol)
			continue
		end
		
		CopyLeaf(
			copy,
			key,
			value :: Val | SupportedTypesList | PrimitiveTable,
			DeepCopy
		)
	end
	
	return copy
end

local function ReconcileTable(
	target: (StateA), -- the table to mutate (make changes to) into StateA
	template: (StateA | StateB | StateC | any)--, -- truly your input of the [[data template]]
	--profile -- : ProfileStore.Profile<[[data template]]> -- can be commented out
	-- why is it (profile) here? - Used internally to ensure custom DeepCopyTable callback is used
)
	-- mutate target to contain all keys from template, that it doesn't have yet

	-- regardless of template state, it is expected to have generalized interation
	-- available; (It's either a table or a CoffeeFolder; NOT a SINGLE VALUE, cuz 
	-- CoffeeParser doesn't support that; The function is also named Reconcile**TABLE**)
	
	for key, value in template do
		if type(key) ~= "string" then -- Only string keys will be reconciled
			continue
		end
		
		local valueType = type(value)
		local targetValue = target[key]
		
		if targetValue == nil then
			if valueType == `table` then
				-- Creation of a CoffeeFolder is essentially a DeepCopy.
				target[key] = FolNew(value)
				continue
			end
			target[key] = ValNew(value)
			continue
		end
		
		if valueType == `table` -- value to Reconcile is a table
			and ValidateFol(targetValue) -- target is compatible (a CoffeeFolder)
		then
			ReconcileTable(targetValue, value)
		end
		
	end
end






local ProfileStoreV3 = {}
ProfileStoreV3.__index = ProfileStoreV2



function ProfileStoreV3.New(...)
	local ProfileStore = ProfileStoreV2.New(...)
	:SetDeepCopyTableCallback(function(t: StateA | StateC): StateC | any -- any is here to mute a poor type definition of PSV2 that the returned table type must be exactly ``{}``
		return DeepCopy(t)
	end)
	:SetReconcileTableCallback(ReconcileTable :: (...any) -> ())
	:SetDecodeCallback(function(data: StateB): StateA --StateC
		local stateC = Decode(
			data :: CoffeeParser.PrimitiveBasicTable
		) :: StateC
		
		local stateA = FolNew(stateC)
		
		return stateA -- return as State ~~C~~ **A**
	end)
	:SetEncodeCallback(function(data: StateC): StateB
		local stateB = Encode(data)
		return stateB -- return as State B
	end)
	:SetRuntimeWrapperCallback(function(
		dataWrittenToProfile: (StateA | StateB | StateC | any),
		profile: ProfileStoreV2.Profile<StateA>
	): StateA
		warn(`{Prefix} Overwriting Profile.Data is locked, please read the documentation at <https://github.com/Coffilhg/ProfileStoreV3>; Write ignored, attempted to write value:`, dataWrittenToProfile)
		return profile.Data
	end)
	
	return ProfileStore
end

return ProfileStoreV3 :: Types.ProfileStoreModule