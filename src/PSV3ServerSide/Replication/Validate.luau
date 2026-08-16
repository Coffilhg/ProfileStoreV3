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
--- (VALIDATION) Validate the types! ---
const Types = require(script.Parent.Parent.Types)
const DataConfig = require(script.Parent.Parent.DataConfig)

const FolderReplicatedCDNs : Types.FolderReplicatedCDNs = DataConfig.FolderReplicatedCDNs
const ClientReplicatedCDNs : Types.ClientReplicatedCDNs = DataConfig.ClientReplicatedCDNs
const ForbiddenCDNs : Types.ForbiddenCDNs = DataConfig.ForbiddenCDNs

const Please: string = ` Please follow the types defined in Types:`

-- Returns whether the DataConfig is set-up correctly
return function(): boolean
	
	for folderName : Types.FolderName, folderReplicatedCDNInfos in FolderReplicatedCDNs do
		if type(folderName) ~= "string" then
			warn(`FolderReplicatedCDNs contains a non-string FolderName: {folderName};{Please}`, Types)
			return false
		end
		if type(folderReplicatedCDNInfos) ~= "table" then
			warn(`FolderReplicatedCDNs["{folderName}"] is not a table value!{Please}`, Types)
			return false
		end

		local ipairsUsed = false
		for i : number, folderReplicatedCDNInfo : Types.FolderReplicatedCDNInfo in ipairs(folderReplicatedCDNInfos) do
			ipairsUsed = true

			if type(folderReplicatedCDNInfo) ~= "table" then
				warn(`FolderReplicatedCDNs["{folderName}"][{i}] is not a table value!{Please}`, Types)
				return false
			end

			if type(folderReplicatedCDNInfo["CDN"]) ~= "string" then
				warn(`FolderReplicatedCDNs["{folderName}"][{i}]["CDN"] is not a string or doesn't exist!{Please}`, Types)
				return false
			end
		end

		if not ipairsUsed then
			warn(`FolderReplicatedCDNs["{folderName}"] is not an array like table!{Please}`, Types)
			return false
		end
	end
	
	
	
	for CDN : string, value : boolean in pairs(ClientReplicatedCDNs) do
		if type(CDN) ~= "string" then
			warn(`ClientReplicatedCDNs contains a non-string CDN: {CDN};{Please}`, Types)
			return false
		end
		if type(value) ~= "boolean" then
			warn(`ClientReplicatedCDNs["{CDN}"] contains a non-boolean Value: {value};{Please}`, Types)
			return false
		end
	end
	
	
	
	local ipairsUsed = false
	for i : number, CDN : string in ipairs(ForbiddenCDNs) do
		ipairsUsed = true
		if type(CDN) ~= "string" then
			warn(`ForbiddenCDNs[{i}] contains a non-string Value: {CDN};{Please}`, Types)
			return false
		end
	end
	if not ipairsUsed then
		warn(`ForbiddenCDNs is not an array like table!{Please}`, Types)
		return false
	end
	
	return true
end