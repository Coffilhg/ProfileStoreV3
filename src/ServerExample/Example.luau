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
-- This script is an example of how PSV3 can be used!

local Players = game:GetService(`Players`)
local SSS = game:GetService(`ServerScriptService`)
local RS = game:GetService(`ReplicatedStorage`)

local PSV3 = SSS.PSV3ServerSide
local SPackages = SSS.ServerPackages
local Packages = RS.Packages

local CoffeeObjects = require(Packages.CoffeeObjects)
local LemonSignal = require(Packages.LemonSignal)

local Types = require(PSV3.Types)
local ProfileStoreV3 = require(PSV3.ProfileStoreV3)
local DataConfig = require(PSV3.DataConfig)
local Replication = require(PSV3.Replication)

local PlayerStore = ProfileStoreV3.New(
	"PlayerStore", -- any name you want
	DataConfig.PROFILE_TEMPLATE :: any, -- actually Types.ProfileData
	nil, -- read more about this: (you can also see how the player key is generated below in this script)
	true -- https://github.com/Coffilhg/ProfileStoreV2#profilestore-object-creation-has-two-new-additional-params
)

local PlayersAdded: {[Player]: true} = {}
local Profiles: Types.Profiles = {}
local PlayersLoaded: Types.PlayersLoaded = {}
local OnPlayerLoadedSignal: Types.OnPlayerLoadedSignal = LemonSignal.new()
local IsNotInitialized: true? = true

Replication:Init(Profiles, PlayersLoaded)

local function ReadOnlyNewIndex(self, key: any, value: any)
	warn(`The table is read-only, ignored write of ["{key}"] =`, value)
end
local ProxyToProfiles = setmetatable(
	{},
	table.freeze({
		__index = function(self, key: Player)
			return Profiles[key]
		end,
		__newindex = ReadOnlyNewIndex,
	})
)
local ProxyToPlayersLoaded = setmetatable(
	{},
	table.freeze({
		__index = function(self, key: Player)
			return PlayersLoaded[key]
		end,
		__newindex = ReadOnlyNewIndex,
	})
)

local ProfileStoreV3 = {
	Profiles = ProxyToProfiles,
	PlayersLoaded = ProxyToPlayersLoaded,
	OnPlayerLoadedSignal = OnPlayerLoadedSignal,
}

local function PlayerAdded(player: Player)
	if PlayersAdded[player] then
		return -- avoid starting the session twice
	end
	PlayersAdded[player] = true

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

			Replication:ConnectReplication(profile.Data, "", player)

			PlayersLoaded[player] = true
			loadingStatusValue.Value = 1
			
			
			
			OnPlayerLoadedSignal:Fire(player, profile)

		else
			-- The player has left before the profile session started
			profile:EndSession()
		end

	else
		-- This condition should only happen when the Roblox server is shutting down
		player:Kick(`Profile load fail - Please rejoin`)
	end

end

local function PlayerRemoving(player: Player)
	local profile = Profiles[player]
	--warn(`On player leave profile exists = {not not profile}`)
	if profile ~= nil then
		--warn(`On player leave profile cleanup using :EndSession()`)
		profile:EndSession()
	end
	-- cleanup
	Profiles[player] = nil
	PlayersLoaded[player] = nil
	PlayersAdded[player] = nil
end



function ProfileStoreV3.Init(
	self: Types.ProfileStoreV3Suffix
): (Types.Profiles, Types.PlayersLoaded, Types.OnPlayerLoadedSignal)
	if IsNotInitialized ~= true then
		return Profiles, PlayersLoaded, OnPlayerLoadedSignal
	end
	IsNotInitialized = nil -- let gc collect it now
	
	Players.PlayerRemoving:Connect(PlayerRemoving)
	Players.PlayerAdded:Connect(PlayerAdded)
	-- In case Players have joined the server earlier than this part of the script ran:
	for _, player : Player in Players:GetPlayers() do
		task.spawn(PlayerAdded, player)
	end
	
	--print("ProfileStoreMainV3 ~ Dependency load success")
	
	return Profiles, PlayersLoaded, OnPlayerLoadedSignal
end

table.freeze(ProfileStoreV3)

return ProfileStoreV3 :: Types.ProfileStoreV3Suffix