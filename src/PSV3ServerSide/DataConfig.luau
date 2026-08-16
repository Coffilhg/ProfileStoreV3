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
local RS = game:GetService(`ReplicatedStorage`)
local Packages = RS.Packages
-- You might want to have template explicitly *Coffeified*
local CoffeeObjects = require(Packages.CoffeeObjects)
local Val = CoffeeObjects.CoffeeBaseValue
local Fol = CoffeeObjects.CoffeeFolder
-- You definitely want some types here!
local Types = require(script.Parent.Types)



-- The PROFILE_TEMPLATE table is what new profile "Profile.Data" will default to:
--[=[--
    CDN means "Code Data Name"
    This represents the key name used in scripts and saved in the DataStore.
    Nested data is referenced using dot notation (e.g., "Statistics.TotalHoney").
--]=]
--

-- ALWAYS MAKE SURE Types.ProfileData is matching this PROFILE_TEMPLATE definition.
local PROFILE_TEMPLATE = {
	LogInTimes = 0,
	Playtime = 0,
	Wins = 0,
	Deaths = 0,
}

local FolderReplicatedCDNs: Types.FolderReplicatedCDNs = {
	-- "leaderstats" are automatically visible to everyone on the Tab menu
	leaderstats = {
		{ CDN = "Wins", DisplayName = "Win" },
		{ CDN = "Deaths", DisplayName = "Lose" },
	},
}

local ClientReplicatedCDNs: Types.ClientReplicatedCDNs = {
	[""] = true,
}

local ForbiddenCDNs: Types.ForbiddenCDNs = {
	"placeholder",
}



export type DataConfig = {
	PROFILE_TEMPLATE: typeof(PROFILE_TEMPLATE),
	FolderReplicatedCDNs: Types.FolderReplicatedCDNs,
	ClientReplicatedCDNs: Types.ClientReplicatedCDNs,
	ForbiddenCDNs: Types.ForbiddenCDNs,
}

local Dataconfig: DataConfig ={
	PROFILE_TEMPLATE = PROFILE_TEMPLATE,
	FolderReplicatedCDNs = FolderReplicatedCDNs,
	ClientReplicatedCDNs = ClientReplicatedCDNs,
	ForbiddenCDNs = ForbiddenCDNs,
}

return Dataconfig