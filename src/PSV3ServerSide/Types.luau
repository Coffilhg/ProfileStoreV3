--[[--
	This is a part of ProfileStoreV3
    ProfileStoreV3 <https://github.com/Coffilhg/ProfileStoreV3>
    Copyright © 2026 Coffilhg (Roblox UserId 517222346)
    
	Licensed under the Apache License, Version 2.0 (the "License");
    see LICENSE & NOTICE or <http://www.apache.org/licenses/LICENSE-2.0>

    ProfileStoreV3 Version: 0.0.0
	Stars are appreciated!
--]]--

local SSS = game:GetService(`ServerScriptService`)
local RS = game:GetService(`ReplicatedStorage`)

local SPackages = SSS.ServerPackages
local Packages = RS.Packages

local ProfileStoreV2 = require(SPackages.ProfileStoreV2)
local CoffeeObjects = require(Packages.CoffeeObjects)
local LemonSignal = require(Packages.LemonSignal)
local Arrangement = require(Packages.Arrangement)



local Types = {}

--- Main Object Types
export type Val = CoffeeObjects.CoffeeBaseValue
export type SVal<T=SupportedTypesList> = CoffeeObjects.CoffeeBaseValueStrict<T>
export type IVal<T=SupportedTypesList> = CoffeeObjects.CoffeeBaseValueInternals<T>
export type Fol = CoffeeObjects.CoffeeFolder
export type SFol<T=PrimitiveTable> = CoffeeObjects.CoffeeFolderStrict<T>
export type IFol<T=PrimitiveTable> = CoffeeObjects.CoffeeFolderInternals<T>
--- Types That work with these objects
export type SupportedTypesList = CoffeeObjects.SupportedTypesList -- SVal<T=SupportedTypesList>
export type TableIndex = CoffeeObjects.TableIndex -- everything that can be used as a key (index) inside a Fol
export type TableValue = CoffeeObjects.TableValue -- everything that can be used as a value inside a Fol
export type PrimitiveTable = CoffeeObjects.PrimitiveTable -- SFol<T=PrimitiveTable>
--- Re-Export ProfileStoreV2 types
export type JSONAcceptable = ProfileStoreV2.JSONAcceptable
export type Profile<T> = ProfileStoreV2.Profile<T>
export type VersionQuery<T> = ProfileStoreV2.VersionQuery<T>
export type ProfileStore<T> = ProfileStoreV2.ProfileStore<T>
export type ProfileStoreModule = ProfileStoreV2.ProfileStoreModule

-- Mirror PROFILE_TEMPLATE defined in DataConfig for perfect autocomplete of profile.Data when used!
export type ProfileData = SFol<{
	LogInTimes: SVal<number>,
	Playtime: SVal<number>,
	Wins: SVal<number>,
	Deaths: SVal<number>,
}>
-- Tuples are not working very well yet, we're waiting for new luau generic type updates.
-- We don't explicitly state `local PROFILE_TEMPLATE : ProfileData`, because PROFILE_TEMPLATE
-- can be a very mixed set of
-- 		keys: string | number
-- and
-- 		values: CoffeeObjects.SupportedTypesList | Val | Fol | SVal | SFol
-- but all of that will be converted to a Fol without a strict structure, except
-- the keys are all string | number, and values : Fol | Val
-- this can't be solved by the type solver, so, to achieve near perfect autocomplete
-- keep the ProfileData type as the mirror of what's expected
-- SVal should only be used to infer, that the value should only be the specified
-- type; Should be a singletone or union of one or multiple types from CoffeeObjects.SupportedTypesList
-- SFol should be used at all times, otherwise type solver sees its a CoffeeFolder, but not it's contents



export type PlayerProfile = Profile<ProfileData>
-- if this produces a broken autocomplete for you, you can try:
-- export type PlayerProfile = Profile<any> & {Data: ProfileData}



export type Profiles = {[Player]: PlayerProfile?} -- PlayerProfile per Player Dictionary
export type PlayersLoaded = {[Player]: boolean?} -- IsLoaded status per Player Dictionary
export type OnPlayerLoadedSignal = LemonSignal.Signal<Player, PlayerProfile>
export type ProfileStoreV3Suffix = {
	read Profiles: Profiles,
	read PlayersLoaded: PlayersLoaded,
	read OnPlayerLoadedSignal: OnPlayerLoadedSignal,
	read Init: (self: ProfileStoreV3Suffix) -> (Profiles, PlayersLoaded, OnPlayerLoadedSignal),
	-- I don't really like calling it a Controller or Handler.
	-- Maybe Launcher? Is that convenient though?
}






--- Init Config Types ---
export type PathIndex = number -- those created by Arrangement (e.g. PathArrangements[path] in Replication)
export type CDNPath = string
--- CDN means "Code Data Name"; It also usually refers to the Full String Path of
--- a Value (Data) from the very Root.
--[=[--
    FOLDER REPLICATION (Physical)
    Configures which data should be mirrored into physical Roblox Folders/Values 
    inside the Player instance (e.g. visible to all players via the Leaderboard).
    
    Structure:
    [FolderName] = { {CDN = string, DisplayName = string?}, ... }
--]=]--
export type FolderReplicatedCDNInfo = {
	["CDN"]: CDNPath,
	["DisplayName"]: string?,
}
export type FolderName = string | "leaderstats"
-- types above are just for readability of the type below!
-- Folder Name (e.g. "leaderstats") : array of FolderReplicatedCDNInfo type
export type FolderReplicatedCDNs = {
	[FolderName]: {
		[number]: FolderReplicatedCDNInfo,
	},
}

--[=[--
    REMOTE REPLICATION (Logic-Only)
    Configures which data is sent via RemoteEvents to clients.
    Whitelist of keys that can be accessed publicly.
    Useful for UI updates, inventory management, or custom HUDs.
    
    Want to make all values public without writing all of them?
    - Make the ROOT public! e.g. [""] = true OR [""] = false
    (This is basically a switch from Whitelist to Blacklist)
    
    Key: The CDN path (string)
    Value: Boolean (true = Public to ALL clients; false = Public to OWNER only)
--]=]--
export type ClientReplicatedCDNs = {
	[CDNPath]: boolean -- true -> all players can read the value by this path of any player
	--- false -> all players can read the value by this path of themselves
}

--[=[--
	Blacklisted CDNs
	Configure which data is exclusively Server-Access!
	You'd say:
	"but all data is exclusively Server-Access, besides the CDNs in ClientReplicatedCDNs above"
	Yeah, but if it's a Folder, all it's descendants will inherit the Public status that was set,
	which means you might reveal some data you'd like to keep exclusively Server-Access;
	This table is to solve this by blacklisting access to such values!
	
	This also applies when you "Make the ROOT public! e.g. [""] = true OR [""] = false",
	which is essentially a switch from Whitelist (default design of this system) to a
	Blacklist
	
	NOTE: This overrides everything, except FolderReplicatedCDNs; What's the point of making a
	leaderstats (or any folder name) and then prohibiting the replication of those values?
	
	Entry: The CDN path (string)
--]=]--
export type ForbiddenCDNs = {CDNPath} -- string array



type Set<T=any> = {
	[T]: true,
}
export type PlayerSet = Set<Player>
export type PathIndexSet = Set<PathIndex>

export type PathArrangements = Arrangement.ArrangementV2
-- Lookups for Objects
export type IsPublic = PathIndexSet -- PathIndex = true --overrides selfPublic; All clients can access each others values of these.
export type IsSelfPublic = PathIndexSet -- PathIndex = true --is overriden by the surrounding two; All clients only have access to their own value of these.
export type IsPrivate = PathIndexSet -- PathIndex = true --overrides all IsPublic and IsSelfPublic; Only the server can access these.
export type IsAPublicFolderValue = {
	[PathIndex]: {
		FolderName: string,
		DisplayName: string,
	},
} -- PathIndex = {FolderName: string, DisplayName: string} -- overrides everything else;

export type SubscribedPlayers = {
	[PathIndex]: PlayerSet,
} -- PathIndex = PlayerSet



export type ObjectInfo = {
	["k"]: TableIndex?, -- only there for children - the main (root) requested objectInfo do not contain this
	["t"]: number, -- type; >0 means a folder, <=0 means a value
	["a"]: number, -- arrangement index
	["v"]: SupportedTypesList?, -- only for values
	["c"]: {ObjectInfo}?, -- only for folders
}



return Types