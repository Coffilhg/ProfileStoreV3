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
--------------------------------------------------------------------------------
-- REPLICATION COMPILER
-- No type checks happen here because validation above exists.
-- Processes the configurations above into a high-speed O(1) lookup table.
--------------------------------------------------------------------------------
const RS = game:GetService(`ReplicatedStorage`)
const Arrangement = require(RS.Packages.Arrangement)

const Types = require(script.Parent.Parent.Types)
const DataConfig = require(script.Parent.Parent.DataConfig)

const FolderReplicatedCDNs : Types.FolderReplicatedCDNs = DataConfig.FolderReplicatedCDNs
const ClientReplicatedCDNs : Types.ClientReplicatedCDNs = DataConfig.ClientReplicatedCDNs
const ForbiddenCDNs : Types.ForbiddenCDNs = DataConfig.ForbiddenCDNs

const PathArrangements: Arrangement.ArrangementV2 = Arrangement.new()
const IsPublic: Types.IsPublic = {}
const IsSelfPublic: Types.IsSelfPublic = {}
const IsPrivate: Types.IsPrivate = {}
const IsAPublicFolderValue: Types.IsAPublicFolderValue = {}
const SubscribedPlayers: Types.SubscribedPlayers = {}

-- 1. Process Physical Folder Requirements
for folderName : Types.FolderName, folderReplicatedCDNInfos : {Types.FolderReplicatedCDNInfo} in FolderReplicatedCDNs do
	for i : number, folderReplicatedCDNInfo : Types.FolderReplicatedCDNInfo in ipairs(folderReplicatedCDNInfos) do

		local path: Types.CDNPath = folderReplicatedCDNInfo[`CDN`]
		local pathIndex: Types.PathIndex = PathArrangements[path]

		IsAPublicFolderValue[pathIndex] = {
			FolderName = folderName,
			DisplayName = folderReplicatedCDNInfo.DisplayName or path,
		}

	end
end

-- 2. Process Remote-Only Requirements
for cdn : Types.CDNPath, isPublicToEveryone : boolean in ClientReplicatedCDNs do

	local pathIndex = PathArrangements[cdn]

	if IsAPublicFolderValue[pathIndex] then
		warn(`CDN "{cdn}" is already a part of FolderReplicatedCDNs, consider removing it from ClientReplicatedCDNs`)
		continue
	end

	if isPublicToEveryone == true then
		IsPublic[pathIndex] = true
	else
		IsSelfPublic[pathIndex] = true
	end

	SubscribedPlayers[pathIndex] = {}
end

-- 3. Process Blacklist Requirements
for _, cdn : Types.CDNPath in ForbiddenCDNs do
	local pathIndex = PathArrangements[cdn]

	if IsAPublicFolderValue[pathIndex] then
		warn(`CDN "{cdn}" is already a part of FolderReplicatedCDNs, consider removing it from ForbiddenCDNs; What's the point of making a "leaderstats" (or any folder name) Folder with this Value and then Blacklisting it's replication?`)
		continue
	end

	IsPrivate[pathIndex] = true
end

return table.freeze({
	PathArrangements = PathArrangements,
	IsPublic = IsPublic,
	IsSelfPublic = IsSelfPublic,
	IsPrivate = IsPrivate,
	IsAPublicFolderValue = IsAPublicFolderValue,
	SubscribedPlayers = SubscribedPlayers,
})