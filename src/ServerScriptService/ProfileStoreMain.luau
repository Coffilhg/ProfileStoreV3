--[[--
    Quick Start and API can be found at
    https://github.com/Coffilhg/ProfileStoreV3/tree/main

    ProfileStoreV3
    Copyright © 2026 Coffilhg (Roblox UserId 517222346)
    
    

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    Full License & Notices: https://github.com/Coffilhg/ProfileStoreV3/tree/main
    Module Version: Theta
--]]--


local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.ProfileStoreV3)
local Counter = require(RS.Counter) -- https://github.com/Coffilhg/Useful-Modules/tree/Counter
local CoffeeRemotes = require(SSS.CoffeeRemotesServer) -- https://github.com/Coffilhg/Useful-Modules/tree/CoffeeRemotes
local Arrangement = require(SSS.Arrangement) -- https://github.com/Coffilhg/Useful-Modules/tree/Arrangement
local CoffeeObjects = require(SSS.CoffeeObjects) -- https://github.com/Coffilhg/Useful-Modules/tree/CoffeeObjects
local CoffeeBaseValue = CoffeeObjects.CoffeeBaseValue
local CoffeeFolder = CoffeeObjects.CoffeeFolder



-- The PROFILE_TEMPLATE table is what new profile "Profile.Data" will default to:
--[=[--
    CDN = "Code Data Name"
    This represents the key name used in scripts and saved in the DataStore.
    Nested data is referenced using dot notation (e.g., "Statistics.TotalHoney").
--]=]--
local PROFILE_TEMPLATE = {
	LogInTimes = 0,
	AllTimeHoney = 0,
	Test1 = {
		Test2 = {
			Tst = 3.14,	
		},
	},
	Test3 = {},
	Test4 = {
		Test5 = "Hello World!",
		Test6 = {},
	},
}
--[=[--
    FOLDER REPLICATION (Physical)
    Configures which data should be mirrored into physical Roblox Folders/Values 
    inside the Player instance (visible to all players via the Leaderboard).
    
    Structure:
    [FolderName] = { {CDN = string, DisplayName = string?}, ... }
--]=]--
local FolderReplicatedCDNs = {
	-- leaderstats are automatically visible to everyone on the Tab menu
	leaderstats = {
		{CDN = "AllTimeHoney", DisplayName = "Honey (All Time)"}
	}
}
--[=[--
    REMOTE REPLICATION (Logic-Only)
    Configures which data is sent via RemoteEvents to clients.
    Whitelist of keys that can be accessed publicly.
    Useful for UI updates, inventory management, or custom HUDs.
    
    Key: The CDN path (string)
    Value: Boolean (true = Public to ALL clients; false = Public to OWNER only)
--]=]--
local ClientReplicatedCDNs = { -- every path 
	["Test1.test2.tst"] = true, -- all players can read this value.
	["LogInTimes"] = false, -- I can read my own LogInTimes value, other players can't access mine, but they can access their own.
	-- If such status is given to a folder, all of it's descendants receive the same.
}

--[=[--
    DYNAMIC SUBSCRIPTIONS (Admin/Special Use)
    Allows specific players to "watch/read" the data of another player.
    Managed at runtime for tasks like Spectating or Admin Monitoring.
    [player] = {[arrangement index] = true}
--]=]--
local CDNChangeSubscriptions = {}




local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)
local Profiles : {[Player] : typeof(PlayerStore:StartSessionAsync())} = {}
local PlayersLoaded : {[Player] : boolean?} = {}
local Classes : {[Player] : typeof(PlayerClassModule.new())} = {}





local ConnectReplication : (CoffeeObjects.CoffeeFolder, string, Player) -> () = nil

local function PlayerLoaded(player : Player, playerData)
	
	playerData.Data.LogInTimes.Value += 1
	
	print(`Profile loaded for {player.DisplayName}! playerData =`, playerData)



	--- Player-Related Code goes here
	
	
	
	for i = 1, 2 do
		task.spawn(function()
			while task.wait() do 
				--print("Add to", playerData.Data.AllTimeHoney.Value)
				playerData.Data.AllTimeHoney.Value += math.random(1, 3)
				
				--playerData.Data.AllTimeHoney.Value = playerData.Data.AllTimeHoney.Value + math.random(1, 3)
			end
		end)
	end
	-- RandoMValues for testing :Insert (e.g. player activated a boost they didnt have active before!)
	local rmv = {"hi", Color3.fromRGB(255, 60, 60), Vector3.zero, 123, false, 456.789, "pie!"}
	task.spawn(function()
		while task.wait(3) do
			--print("playerData.Data.Test3", playerData.Data.Test3)
			playerData.Data.Test3:Insert(rmv[math.random(1, #rmv)])
		end
	end)
	
end

















local function PlayerAdded(player)

	-- Start a profile session for this player's data:

	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	-- Handling new profile session or failure to start it:

	if profile ~= nil then

		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)

		if player.Parent == Players then
			Profiles[player] = profile
			
			
			
			local loadingStatusValue = Instance.new("IntValue")
			loadingStatusValue.Name = "LoadingStatus"
			loadingStatusValue.Value = 0
			loadingStatusValue.Parent = player
			PlayersLoaded[player] = false

			ConnectReplication(profile.Data, "", player)

			PlayersLoaded[player] = true
			loadingStatusValue.Value = 1
			
			
			
			PlayerLoaded(player, profile)
			
		else
			-- The player has left before the profile session started
			profile:EndSession()
		end

	else
		-- This condition should only happen when the Roblox server is shutting down
		player:Kick(`Profile load fail - Please rejoin`)
	end

end









--------------------------------------------------------------------------------
-- REPLICATION COMPILER
-- Processes the configurations above into a high-speed O(1) lookup table.
--------------------------------------------------------------------------------
local ReplicationLookup = {}

-- 1. Process Physical Folder Requirements
for folderName, items in pairs(FolderReplicatedCDNs) do
	for _, item in ipairs(items) do
		ReplicationLookup[item.CDN] = {
			FolderName = folderName,
			DisplayName = item.DisplayName or item.CDN,
			IsAPublicFolderValue = true, -- Physical folders in Players are always globally public
			--SubscribedPlayers = {},
		}
	end
end
-- 2. Process Remote-Only Requirements
for cdn, isPublicToEveryone in pairs(ClientReplicatedCDNs) do
	if ReplicationLookup[cdn] then
		warn(`[Replication]: {cdn} is already assigned to a Folder. Skipping Remote config.`)
		continue
	end

	ReplicationLookup[cdn] = {
		IsPublic = isPublicToEveryone == true,
		IsSelfPublic = not isPublicToEveryone,
		SubscribedPlayers = {},
	}
end

local PathArrangements = Arrangement.new()

local DataUpdateValue = Instance.new("RemoteEvent", RS)
DataUpdateValue.Name = "DataUpdateValue"
local DataUpdateValueSelf = Instance.new("RemoteEvent", RS)
DataUpdateValueSelf.Name = "DataUpdateValueSelf"
local FolderChildAdded = Instance.new("RemoteEvent", RS)
FolderChildAdded.Name = "FolderChildAdded"
local FolderChildAddedSelf = Instance.new("RemoteEvent", RS)
FolderChildAddedSelf.Name = "FolderChildAddedSelf"
local FolderChildRemoved = Instance.new("RemoteEvent", RS)
FolderChildRemoved.Name = "FolderChildRemoved"
local FolderChildRemovedSelf = Instance.new("RemoteEvent", RS)
FolderChildRemovedSelf.Name = "FolderChildRemovedSelf"

local DataUpdatePublicFolderValueRemote = Instance.new("RemoteEvent", RS)
DataUpdatePublicFolderValueRemote.Name = "DataUpdatePublicFolderValueRemote"
local UnreliableDataUpdatePublicFolderValueRemote = Instance.new("UnreliableRemoteEvent", RS)
UnreliableDataUpdatePublicFolderValueRemote.Name = "UnreliableDataUpdatePublicFolderValueRemote"

local function isSafeNumber(n: any): boolean
	-- must be a number
	if type(n) ~= "number" then
		return false
	end

	-- NaN check (NaN is the only value not equal to itself)
	if n ~= n then
		return false
	end

	-- inf / -inf check
	if n == math.huge or n == -math.huge then
		return false
	end

	return true
end

local function isSafeInteger(n: any): boolean
	return isSafeNumber(n) and n % 1 == 0
end

CoffeeRemotes.RemoteFunction.new("GetPathArrangements"):SetCooldown(0).OnServerInvoke = function(player : Player, index : number)
	if not isSafeInteger(index) then
		return true, false
	end
	return true, PathArrangements:GetKeyByIndex(index)
end




-- Create a single metatable to miltiplex one function for multiple Objects (Saves Memory)
local DataUpdatePublicFolderValueCallback = {}
function DataUpdatePublicFolderValueCallback:__call(v)
	--print("Replicating", UID, PathArrangements[currentPath], v)
	DataUpdatePublicFolderValueRemote:FireAllClients(self.UID, PathArrangements[self.currentPath], v)
	--print("sent", v, frequencyCounter.count)
	--UnreliableDataUpdatePublicFolderValueRemote:FireAllClients(UID, PathArrangements[currentPath], v)
end

local DataUpdateValueCallback = {}
function DataUpdateValueCallback:__call(v)
	for subscribedPlayer in pairs(self.subscribedPlayers) do
		if subscribedPlayer.UserId == self.UID then
			DataUpdateValueSelf:FireClient(self.player, PathArrangements[self.currentPath], v)
			continue
		end
		DataUpdateValue:FireClient(subscribedPlayer, self.UID, PathArrangements[self.currentPath], v)
	end
end



local PublicFolderValues = {}

-- Recursively traverse the ALREADY COFFEIFIED data
ConnectReplication = function(coffeeObject : CoffeeObjects.CoffeeBaseValue | CoffeeObjects.CoffeeFolder, pathPrefix, player : Player, previousPathRule)
	local currentPath = pathPrefix or "" -- pathPrefix and `{pathPrefix}.{key}` or key
	local UID = player.UserId
	
	
	
	local rule = ReplicationLookup[currentPath]

	if not rule then
		ReplicationLookup[currentPath] = {
			SubscribedPlayers = {},
		}
		rule = ReplicationLookup[currentPath]
	end
	
	-- inherit Public statuses from parent objects in the tree
	if previousPathRule then
		if previousPathRule["IsPublic"] == true then
			rule["IsPublic"] = true
		end
		if previousPathRule["IsSelfPublic"] == true then
			rule["IsSelfPublic"] = true
		end
	end
	
	
	
	if CoffeeBaseValue.validateClass(coffeeObject) or CoffeeBaseValue.validateUnlinkedClass(coffeeObject) then
		local frequencyCounter = Counter.new():setInterval(1/8) -- up to 8 updates per second
		local waiting = false
		
		local replicate = {
			UID = UID,
			currentPath = currentPath,
		}
		
		
		
		if rule["IsAPublicFolderValue"] then
			
			replicate = setmetatable(replicate, DataUpdatePublicFolderValueCallback)
			
			-- specific part only for IsAPublicFolderValue;
			-- Required to load leaderstats and other folder values for new players who join this server
			if not PublicFolderValues[UID] then
				PublicFolderValues[UID] = {}
			end
			PublicFolderValues[UID][currentPath] = function()
				return coffeeObject.Value
			end
		else
			replicate["subscribedPlayers"] = rule["SubscribedPlayers"]
			replicate["player"] = player
			replicate = setmetatable(replicate, DataUpdateValueCallback)
		end
		
		--[[
		-- subscribe the player to their own values; SCRAPED
		if not rule["IsAPublicFolderValue"] then
			rule["SubscribedPlayers"][player] = true
		end
		--]]
		
		
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
		
	elseif CoffeeFolder.validateClass(coffeeObject) or CoffeeFolder.validateUnlinkedClass(coffeeObject) then
		
		local subscribedPlayers = rule["SubscribedPlayers"]
		
		local function NewChild(key, value : CoffeeObjects.CoffeeBaseValue | CoffeeObjects.CoffeeFolder)
			
			local childPath = (currentPath ~= nil and currentPath ~= "") and `{currentPath}.{key}` or `{key}`
			
			ConnectReplication(value, childPath, player, rule)

			--print(`Child Added to {currentPath}. Key={key} Value={value}`)
			
			-- do subscriptions for FolderChildAdded(Self); Example:
			-- FolderChildAdded:FireClient(subscribedPlayer, UID, PathArrangements[currentPath], key, PathArrangements[`{currentPath}.{key}`], 0 for Value OR 1 for Folder, Value of the Value if its not a Folder)
			
			local currentPathArrangement = PathArrangements[currentPath]
			local childPathArrangement = PathArrangements[childPath]
			
			for subscribedPlayer in pairs(subscribedPlayers) do
				
				
				
				if subscribedPlayer.UserId == UID then
					
					if CoffeeBaseValue.validateClass(value) or CoffeeBaseValue.validateUnlinkedClass(value) then
						FolderChildAddedSelf:FireClient(
							subscribedPlayer,
							currentPathArrangement,
							key,
							childPathArrangement,
							0,
							value.Value
						)
					else
						FolderChildAddedSelf:FireClient(
							subscribedPlayer,
							currentPathArrangement,
							key,
							childPathArrangement,
							1
						)
					end
					
				else
					
					if CoffeeBaseValue.validateClass(value) or CoffeeBaseValue.validateUnlinkedClass(value) then
						FolderChildAdded:FireClient(
							subscribedPlayer,
							UID,
							currentPathArrangement,
							key,
							childPathArrangement,
							0,
							value.Value
						)
					else
						FolderChildAdded:FireClient(
							subscribedPlayer,
							UID,
							currentPathArrangement,
							key,
							childPathArrangement,
							1
						)
					end
					
				end



			end
		end
		
		-- its a CoffeeFolder
		for key, value in coffeeObject do
			NewChild(key, value)
		end
		coffeeObject.ChildAdded:Connect(NewChild)
		coffeeObject.ChildRemoved:Connect(function(key)
			-- do subscriptions for FolderChildRemoved(Self); Example:
			-- FolderChildRemoved:FireClient(subscribedPlayer, UID, PathArrangements[`{currentPath}.{key}`])
			
			local childPath = (currentPath ~= nil and currentPath ~= "") and `{currentPath}.{key}` or `{key}`
			
			for subscribedPlayer in pairs(subscribedPlayers) do
				
				if subscribedPlayer.UserId == UID then
					FolderChildRemovedSelf:FireClient(subscribedPlayer, PathArrangements[childPath])
				else
					FolderChildRemoved:FireClient(subscribedPlayer, UID, PathArrangements[childPath])
				end
				
			end
		end)
	end
end

local GetFolderReplicatedCDNs = CoffeeRemotes.RemoteFunction.new("GetFolderReplicatedCDNs")
GetFolderReplicatedCDNs.OnServerInvoke = function(player : Player)
	return true, FolderReplicatedCDNs
end
local LoadPublicFolderValues = CoffeeRemotes.RemoteFunction.new("LoadPublicFolderValuePerPath"):SetCooldown(1)
LoadPublicFolderValues.OnServerInvoke = function(player : Player, subjectPlayerUID : number)
	if type(subjectPlayerUID) ~= "number" then
		return true, {}
	end
	
	local valuesPerPath = PublicFolderValues[subjectPlayerUID]
	
	if not valuesPerPath then
		return true, {}
	end
	
	local result = {}
	for path, loadValueCallback in pairs(valuesPerPath) do
		result[path] = loadValueCallback()
	end
	
	return true, result
end



local function checkSecurity(path, canSubscribe, securityPassed, subscribingToSelf)
	local rule = ReplicationLookup[path]

	if not canSubscribe then
		canSubscribe = 
			rule["IsPublic"] == true or
			(rule["IsSelfPublic"] == true and subscribingToSelf)
		-- possibly add ability for devs/admins to bypass security
	end

	if not securityPassed then
		securityPassed = 
			rule["IsAPublicFolderValue"] == true or
			canSubscribe
	end

	return canSubscribe, securityPassed, rule
end
local function scrapeChildrenAndSubscribe(coffeeFolder : CoffeeObjects.CoffeeFolder, player : Player)
	local result = {}
	
	for key, childObject in pairs(coffeeFolder:GetChildren()) do
		
		-- it is expected you did NOT modify the CoffeeObjects, which means all
		-- children of a CoffeeFolder are either CoffeeBaseValue or CoffeeFolder instances
		-- because of this, and to optimise this code, there is NO checks to prevent
		-- errors in case the CoffeeObjects was modified
		
		local currentPath = table.concat(childObject:GetPath(), ".")
		local rule = ReplicationLookup[currentPath]
		-- no checks wheter the rule exists or not yet, because ConnectReplication
		-- works together with PlayerLoaded, to ensure if an object exists, it has an
		-- "empty" rule index in ReplicationLookup by design
		
		rule["SubscribedPlayers"][player] = true
		
		if CoffeeBaseValue.validateClass(childObject) or CoffeeBaseValue.validateUnlinkedClass(childObject) then
			--print("V", subscribeToObject)
			
			--result[key] = 
			table.insert(result, {
				k = childObject._key,
				t = 0, -- objectType,
				v = childObject.Value,
				a = PathArrangements[currentPath],
			})
		else --if CoffeeFolder.validateClass(childObject) or CoffeeFolder.validateUnlinkedClass(childObject) then
			--print("F", subscribeToObject)

			--result[key] = 
			table.insert(result, {
				k = childObject._key,
				t = 1, -- objectType,
				a = PathArrangements[currentPath],
				c = scrapeChildrenAndSubscribe(childObject, player)
			})
		end
	end
	
	return result
end
local function insertObject(objectInfos, subscribeToObject, currentPath, isLast, player)
	if CoffeeBaseValue.validateClass(subscribeToObject) or CoffeeBaseValue.validateUnlinkedClass(subscribeToObject) then
		--print("V", subscribeToObject)
		--[[
		if canSubscribe then -- subscribe
			rule["SubscribedPlayers"][player] = true
		end
		--]]
		
		table.insert(objectInfos, {
			t = 0, -- objectType,
			v = subscribeToObject.Value,
			a = PathArrangements[currentPath],
		})
		
		local rule = ReplicationLookup[currentPath]
		rule["SubscribedPlayers"][player] = true
		--[[
		return {
			k = subscribeToObject._key,
			t = 0, -- objectType,
			v = subscribeToObject.Value,
			a = PathArrangements[currentPath],
		}
		--]]
	elseif CoffeeFolder.validateClass(subscribeToObject) or CoffeeFolder.validateUnlinkedClass(subscribeToObject) then
		--print("F", subscribeToObject)

		local folderInfo = {
			--k = subscribeToObject._key,
			t = 1, -- objectType,
			a = PathArrangements[currentPath],
		}
		
		if isLast then
			folderInfo["c"] = scrapeChildrenAndSubscribe(subscribeToObject, player)
		end

		--[[
		if canSubscribe then -- subscribe
			rule["SubscribedPlayers"][player] = true

			-- get all children and their descnedants
			folderInfo["c"] = scrapeChildrenAndSubscribe(subscribeToObject, player)
		end
		--]]

		table.insert(objectInfos, folderInfo)
		
		local rule = ReplicationLookup[currentPath]
		rule["SubscribedPlayers"][player] = true
		--return true, folderInfo
	else
		return true
	end
end

local Subscribe = CoffeeRemotes.RemoteFunction.new("Subscribe")
Subscribe.OnServerInvoke = function(player : Player, subscribeToPlayerUID : number, path : {[number]: string}, subscribeFromIndex : number?)
	subscribeFromIndex = subscribeFromIndex or 1
	print("RemoteReceived", player, subscribeToPlayerUID, path, subscribeFromIndex)
	if not (
			type(subscribeToPlayerUID) == "number" and 
			type(path) == "table"-- and 
			--(type(requiredKey) == "string" or type(requiredKey) == "number")
		) then
		print("UID not a number OR path not a table")
		return true, false
	end
	
	
	
	-- go thru the path
	-- keep track based on subscribeFromIndex
	-- if its the last element of path - scrape it
	
	--[[
	local pathString = table.concat(path, ".")
	if #pathString < 1 then
		print("Path empty")
		return true, false
	end
	--]]

	
	
	local subscribeToPlayer = Players:GetPlayerByUserId(subscribeToPlayerUID)
	if not subscribeToPlayer then
		print("Player not in server")
		return true, false
	end

	local subscribeToPlayerData = Profiles[subscribeToPlayer]
	if not subscribeToPlayerData then
		return true, false
	end
	--print("subscribeToPlayerData", subscribeToPlayerData)
	--local subscribingToSelf = player.UserId == subscribeToPlayerUID
	
	
	
	if not PlayersLoaded[player] then
		repeat 
			task.wait()
		until PlayersLoaded[player] ~= false
	end
	if PlayersLoaded[player] == nil then
		print("Player left")
		return true, false
	end
	
	
	--[[
	local canSubscribe, securityPassed = false, false
	local rule
	--]]
	local objectInfos = {}
	local subscribeToObject = subscribeToPlayerData.Data
	
	for i, key in ipairs(path) do
		--print("iterating", i, key)
		if not subscribeToObject[key] then
			--print(key, "not found")
			break --return true, objectInfos
		end

		local currentPath = table.concat(path, ".", 1, i)
		local rule = ReplicationLookup[currentPath]

		subscribeToObject = subscribeToObject[key]
		--print("iteration obj:", subscribeToObject)
		--print(CoffeeBaseValue.validateClass(subscribeToObject), CoffeeBaseValue.validateUnlinkedClass(subscribeToObject))

		if i <= subscribeFromIndex then
			--print(i, subscribeFromIndex, "skip")
			continue
		end
		
		if insertObject(objectInfos, subscribeToObject, currentPath, i == #path, player) then
			break -- failed to insert
		end
	end
	
	
	--[[
	-- loop through path, to get the key's parent
	for i, key in ipairs(path) do
		--print("iterating", i, key)
		if not subscribeToObject[key] then
			--print(key, "not found")
			break --return true, objectInfos
		end
		
		canSubscribe, securityPassed, rule = checkSecurity(table.concat(path, ".", 1, i), canSubscribe, securityPassed, subscribingToSelf)

		subscribeToObject = subscribeToObject[key]
		--print("iteration obj:", subscribeToObject)
		--print(CoffeeBaseValue.validateClass(subscribeToObject), CoffeeBaseValue.validateUnlinkedClass(subscribeToObject))
	end
	--]]
	
	--[[
	table.insert(path, requiredKey)
	local currentPath = table.concat(path, ".")
	canSubscribe, securityPassed, rule = checkSecurity(currentPath, canSubscribe, securityPassed, subscribingToSelf)
	
	subscribeToObject = subscribeToObject[requiredKey]
	--
	if not (subscribeToObject and securityPassed) then
		print(subscribeToObject, subscribeToObject:GetPath(), currentPath)
		print("Object", not subscribeToObject and "Doesnt exist" or "didnt pass secutity")
		return true, false
	end]]
	
	
	
	--print("did not validate as an object")
	--print("subscribeToPlayerData before return", subscribeToPlayerData)
	return true, objectInfos
end
local Unsubscribe = CoffeeRemotes.RemoteEvent.new("Unsubscribe")
Unsubscribe:SetCooldown(0):Connect(function(player : Player, unsubscribePathArrangementIndex : number?)
	if not isSafeInteger(unsubscribePathArrangementIndex) then
		return
	end
	
	local path = PathArrangements:GetKeyByIndex(unsubscribePathArrangementIndex)
	if not path then
		return
	end
	
	local rule = ReplicationLookup[path]
	if not rule then
		return
	end
	
	rule["SubscribedPlayers"][player] = nil
end)
local TestRemote = CoffeeRemotes.RemoteEvent.new("Test")
TestRemote:SetCooldown(1):Connect(function(player : Player)
	local profile = Profiles[player]
	if not profile then
		return
	end
	
	profile.Data.Test1.Test2.Tst.Value += 1
end)




-- In case Players have joined the server earlier than this script ran:
for _, player in Players:GetPlayers() do
	task.spawn(PlayerAdded, player)
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	PlayersLoaded[player] = nil
	
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
	
	for _, rule in pairs(ReplicationLookup) do
		if type(rule["SubscribedPlayers"]) ~= "table" then
			return
		end
		rule["SubscribedPlayers"][player] = nil
	end
end)


task.delay(15, function()
	print(ReplicationLookup)
end)

print("Dependency load success")